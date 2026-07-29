# PowerShell Auto-Monitor Script for HammerDB
# Usage: powershell -ExecutionPolicy Bypass -File auto_monitor.ps1
# Edit $tclScript variable to point to your test script

param(
    [string]$TclScript = "C:\temp\run_tpcc.tcl",
    [string]$HammerDb = "C:\Program Files\HammerDB-6.0\hammerdbcli.exe",
    [string]$LogFile = "C:\temp\hammerdb_output.log"
)

$ErrorActionPreference = "SilentlyContinue"
$env:PATH += ";C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\180\Tools\Binn"

if (Test-Path $LogFile) { Remove-Item $LogFile }

Write-Host "=== Starting HammerDB Test ===" -ForegroundColor Cyan
Write-Host "Script: $TclScript" -ForegroundColor Yellow

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $HammerDb
$psi.Arguments = "tcl auto $TclScript"
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true

$process = [System.Diagnostics.Process]::Start($psi)
$pid = $process.Id
Write-Host "PID: $pid" -ForegroundColor Yellow

$errorPatterns = @(
    "Error in Virtual User",
    "FINISHED FAILED",
    "could not be established",
    "child killed",
    "SSL",
    "timeout"
)

$startTime = Get-Date
$killed = $false
$reader = $process.StandardOutput

while (-not $process.HasExited) {
    Start-Sleep -Seconds 2
    try {
        if (-not $reader.EndOfStream) {
            $line = $reader.ReadLine()
            if ($line) {
                Add-Content -Path $LogFile -Value $line
                $elapsed = (Get-Date) - $startTime
                $ts = "{0:D2}:{1:D2}" -f [math]::Floor($elapsed.TotalMinutes), $elapsed.Seconds
                Write-Host "[$ts] $line" -ForegroundColor DarkGray
            }
        }
    } catch {}

    if (Test-Path $LogFile) {
        $content = Get-Content $LogFile -Raw
        foreach ($pattern in $errorPatterns) {
            if ($content -match [regex]::Escape($pattern)) {
                Write-Host ""
                Write-Host "!!! ERROR: $pattern !!!" -ForegroundColor Red
                Write-Host "Killing process $pid ..." -ForegroundColor Red
                Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
                $killed = $true
                break
            }
        }
        if ($killed) { break }
    }
}

Start-Sleep -Seconds 2
Write-Host ""
Write-Host "=== RESULT ===" -ForegroundColor Cyan
if ($killed) {
    Write-Host "KILLED due to error" -ForegroundColor Red
    if (Test-Path $LogFile) { Get-Content $LogFile -Tail 20 }
} else {
    Write-Host "Test completed" -ForegroundColor Green
    if (Test-Path $LogFile) {
        $content = Get-Content $LogFile -Raw
        if ($content -match "TEST RESULT") {
            Select-String -Path $LogFile -Pattern "TEST RESULT" | ForEach-Object {
                Write-Host $_.Line -ForegroundColor Green
            }
        }
    }
}
