# Read-only soak patrol - safe to run repeatedly. SMB reads ONLY (no WMI, no remote
# schtasks, no xp_cmdshell - see SKILL.md Phase 1.8 security rules).
# Usage: powershell -ExecutionPolicy Bypass -File check_status.ps1
# Edit $servers / $pass below before use.
param(
    [string[]]$Servers = @("10.6.110.215", "10.6.110.227", "10.6.110.198"),
    [string]$SmbUser = "administrator",
    [string]$SmbPass = "",
    [string]$LogDir = "C$\hdb\logs"
)
$ErrorActionPreference = "SilentlyContinue"

foreach ($ip in $Servers) {
    Write-Host ""
    Write-Host "======== $ip ========"
    if ($SmbPass -ne "") { cmd /c "net use \\$ip\C$ $SmbPass /user:$SmbUser /persistent:no" > $null 2>&1 }

    $soak = "\\$ip\$LogDir\soak_out.txt"
    if (-not (Test-Path $soak)) { Write-Host "no soak_out.txt yet"; continue }

    # shared-read (hammerdbcli holds the file open with exclusive write)
    $fs = [IO.File]::Open($soak, 'Open', 'Read', 'ReadWrite')
    $sr = New-Object IO.StreamReader($fs)
    $content = $sr.ReadToEnd()
    $sr.Close(); $fs.Close()
    $txt = $content -replace '\x1b\[[0-9;?]*[A-Za-z]', ''
    $lines = $txt -split "`r?`n" | Where-Object { $_.Trim() -ne "" }
    Write-Host ("log lines: {0}, last write: {1}" -f $lines.Count, (Get-Item $soak).LastWriteTime)

    $res = $lines | Where-Object { $_ -match "TEST RESULT|SOAK END|SOAK EXIT|Error in Virtual|FINISHED FAILED" } | Select-Object -First 6
    $lastTpm = $lines | Where-Object { $_ -match "MSSQLServer tpm" } | Select-Object -Last 1
    if ($lastTpm) { Write-Host ("last tpm: " + $lastTpm.Trim()) }
    if ($res) { Write-Host "KEY LINES:"; $res | ForEach-Object { Write-Host ("   " + $_.Trim()) } }

    $csv = "\\$ip\$LogDir\stability_metrics.csv"
    if (Test-Path $csv) {
        $rows = Get-Content $csv | Select-Object -Last 3
        Write-Host "monitor (last 3):"
        $rows | ForEach-Object { Write-Host ("   " + $_) }
        $errF = "\\$ip\$LogDir\sql_errors_found.txt"
        if (Test-Path $errF) {
            $n = (Get-Content $errF | Measure-Object -Line).Lines
            Write-Host "SQL ERROR ENTRIES FOUND: $n  <-- CHECK sql_errors_found.txt"
        } else { Write-Host "sql errors found: 0" }
    }
}
