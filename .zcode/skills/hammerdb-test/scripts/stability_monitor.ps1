# Long-run stability monitor for HammerDB TPC-C soaks (SKILL.md Phase 6.5)
# Runs ON the target server alongside the benchmark; appends one CSV row per sample.
# PS 2.0 / 2008 R2 compatible: Get-WmiObject + SqlClient only (no CIM, no localized
# counter paths, no sqlcmd dependency). Pure ASCII: PowerShell 5.1 reads .ps1 as ANSI.
#
# Usage (typically from the schtasks wrapper .bat):
#   powershell -ExecutionPolicy Bypass -File C:\hdb\stability_monitor.ps1 -DatabaseName tpcc
# Optional:
#   -OutCsv C:\hdb\logs\stability_metrics.csv -IntervalSec 60 -ErrorLogScanMin 10
#   -HammerDbLog C:\hdb\logs\hammerdb_output.log   (harvest latest tpm from HammerDB output)
#   -SqlInstance "localhost\INST" -SqlUser sa -SqlPass xxx   (default: integrated security)
# Stop: schtasks /end the wrapping task, or kill the powershell PID.
# PERFORMANCE NOTE: on a loaded 2008 R2 host one loop (sleep + SQL queries + the
# periodic xp_readerrorlog scan) can take 2-5 minutes instead of 60s. CSV rows become
# sparse - this is expected and harmless; the soak itself is unaffected.
#
# Outputs next to the CSV:
#   sql_errors_found.txt        full text of new SQL error-log hits per scan
#   sql_error_scan_state.txt    last scan timestamp (survives monitor restarts)
# Verdict rules live in SKILL.md Phase 6.6.

param(
    [string]$DatabaseName = "tpcc",
    [string]$SqlInstance = "localhost",
    [string]$SqlUser = "",
    [string]$SqlPass = "",
    [int]$IntervalSec = 60,
    [int]$ErrorLogScanMin = 10,
    [string]$OutCsv = "C:\hdb\logs\stability_metrics.csv",
    [string]$HammerDbLog = ""
)

$ErrorActionPreference = "SilentlyContinue"

$logDir = Split-Path -Parent $OutCsv
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$errStateFile = Join-Path $logDir "sql_error_scan_state.txt"
$errFoundFile = Join-Path $logDir "sql_errors_found.txt"

if (-not (Test-Path $OutCsv)) {
    "timestamp,cpu_pct,mem_used_pct,mem_avail_mb,pages_input_sec,disk_sec_trans_ms,tpcc_log_mb,ple,tpm,sql_err_new" |
        Out-File -FilePath $OutCsv -Encoding ASCII
}

$lastErrScan = Get-Date
if (Test-Path $errStateFile) {
    $prev = Get-Content $errStateFile -TotalCount 1
    $prevDate = [datetime]::MinValue
    if ([datetime]::TryParse($prev, [ref]$prevDate)) { $lastErrScan = $prevDate }
}
$lastCkpt = Get-Date

function New-SqlConn {
    $cs = "Server=$SqlInstance;Connection Timeout=10;"
    if ($SqlUser -ne "") { $cs += "User Id=$SqlUser;Password=$SqlPass;" } else { $cs += "Integrated Security=SSPI;" }
    return New-Object System.Data.SqlClient.SqlConnection($cs)
}

function Get-SqlScalar([string]$sql) {
    try {
        $c = New-SqlConn
        $c.Open()
        $cmd = $c.CreateCommand()
        $cmd.CommandText = $sql
        $cmd.CommandTimeout = 30
        $v = $cmd.ExecuteScalar()
        $c.Close()
        return $v
    } catch { return $null }
}

function Get-LastTpm {
    if ($HammerDbLog -eq "" -or -not (Test-Path $HammerDbLog)) { return "" }
    $hits = Select-String -Path $HammerDbLog -Pattern "tpm" -ErrorAction SilentlyContinue
    if ($hits -eq $null -or $hits.Count -eq 0) { return "" }
    $m = [regex]::Matches($hits[$hits.Count - 1].Line, "\d{3,}")
    if ($m.Count -eq 0) { return "" }
    return $m[$m.Count - 1].Value
}

Write-Host "Stability monitor started: sampling every $IntervalSec sec -> $OutCsv"

while ($true) {
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    # CPU % averaged across sockets (LoadPercentage avoids localized counter paths)
    $cpu = ""
    $cpuAvg = (Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
    if ($cpuAvg -ne $null) { $cpu = [math]::Round($cpuAvg, 1) }

    # Memory: buffer pool filling to 90%+ used is EXPECTED (Phase 6.1); the health
    # signal is pages_input_sec (hard faults/sec) staying ~0, not the used %.
    $memUsedPct = ""; $memAvailMb = ""; $pagesIn = ""
    $os = Get-WmiObject Win32_OperatingSystem
    if ($os -ne $null -and $os.TotalVisibleMemorySize -gt 0) {
        $memUsedPct = [math]::Round(100 * ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize, 1)
        $memAvailMb = [math]::Round($os.FreePhysicalMemory / 1024, 0)
    }
    $pmem = Get-WmiObject Win32_PerfFormattedData_PerfOS_Memory
    if ($pmem -ne $null) { $pagesIn = $pmem.PagesInputPerSec }

    # Worst disk latency in ms across physical disks
    $diskMs = ""
    $d = Get-WmiObject Win32_PerfFormattedData_PerfDisk_PhysicalDisk |
        Where-Object { $_.Name -ne "_Total" } |
        Sort-Object -Property AvgDisksecPerTransfer -Descending |
        Select-Object -First 1
    if ($d -ne $null) { $diskMs = [math]::Round($d.AvgDisksecPerTransfer * 1000, 2) }

    # SQL-side: tpcc log size (MB) + page life expectancy; CHECKPOINT keepalive every
    # 5 min truncates the log under SIMPLE recovery (no-op under FULL - see Phase 6.4)
    $logMb = Get-SqlScalar "SELECT CAST(SUM(v.size_on_disk_bytes)/1048576 AS INT) FROM sys.dm_io_virtual_file_stats(DB_ID(N'$DatabaseName'), NULL) v JOIN sys.master_files m ON m.database_id = v.database_id AND m.file_id = v.file_id WHERE m.type_desc = 'LOG'"
    $ple = Get-SqlScalar "SELECT cntr_value FROM sys.dm_os_performance_counters WHERE counter_name = 'Page life expectancy' AND object_name LIKE '%Buffer Manager%'"
    if (((Get-Date) - $lastCkpt).TotalMinutes -ge 5) {
        Get-SqlScalar "USE [$DatabaseName]; CHECKPOINT" | Out-Null
        $lastCkpt = Get-Date
    }

    # Periodic SQL error-log scan; state file lets a restarted monitor resume coverage
    $newErr = 0
    if (((Get-Date) - $lastErrScan).TotalMinutes -ge $ErrorLogScanMin) {
        $scanFrom = $lastErrScan
        $found = @()
        foreach ($kw in @("Error", "Warning", "Fail")) {
            try {
                $c = New-SqlConn
                $c.Open()
                $cmd = $c.CreateCommand()
                $cmd.CommandText = "EXEC xp_readerrorlog 0, 1, N'$kw'"
                $cmd.CommandTimeout = 60
                $r = $cmd.ExecuteReader()
                while ($r.Read()) {
                    $ld = $r.GetDateTime(0)
                    if ($ld -gt $scanFrom) {
                        $found += ("{0} [{1}] {2}" -f $ld.ToString("yyyy-MM-dd HH:mm:ss"), $r.GetValue(1), $r.GetValue(2))
                    }
                }
                $c.Close()
            } catch {}
        }
        $found = @($found | Select-Object -Unique)
        $newErr = $found.Count
        if ($newErr -gt 0) { Add-Content -Path $errFoundFile -Value $found }
        $lastErrScan = Get-Date
        Set-Content -Path $errStateFile -Value $lastErrScan.ToString("yyyy-MM-dd HH:mm:ss")
    }

    $row = "{0},{1},{2},{3},{4},{5},{6},{7},{8},{9}" -f $ts, $cpu, $memUsedPct, $memAvailMb, $pagesIn, $diskMs, $logMb, $ple, (Get-LastTpm), $newErr
    Add-Content -Path $OutCsv -Value $row

    Start-Sleep -Seconds $IntervalSec
}
