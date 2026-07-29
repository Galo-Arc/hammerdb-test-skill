---
name: hammerdb-test
description: Use HammerDB to perform TPC-C database stress testing against SQL Server. Trigger when the user mentions HammerDB, TPC-C, database stress test, SQL Server pressure test, database benchmark, or wants to test SQL Server performance/stability. Covers environment setup, connection verification, schema management, test execution (CLI and GUI), result analysis, and troubleshooting.
---

# HammerDB TPC-C Database Stress Test Skill

This skill enables complete HammerDB TPC-C benchmark testing against SQL Server databases, from environment setup to result analysis. Works with SQL Server 2008/2012/2014/2016/2019/2022.

## Quick Start

When the user invokes this skill, collect the following information upfront:

```
1. Target SQL Server: IP address, port (default 1433)
2. Authentication: sa password or Windows auth
3. SQL Server version: 2008/2012/2014/2016/2019/2022
4. OS version: Windows Server 2008R2/2012R2/2016/2019/2022
5. Test goal: compatibility test, stability test, performance benchmark
6. Concurrent connections: how many Virtual Users
7. Test duration: how long to run
8. User Delay: milliseconds between operations (default 100ms, can be 3000ms for light load)
```

---

## Phase 1: Environment Setup

### 1.1 Verify HammerDB Installation

Check if HammerDB is installed:

```powershell
# Search for HammerDB
where /R "C:\Program Files" hammerdbcli.exe 2>nul
```

If not installed, guide user to download from https://www.hammerdb.com/download.html

### 1.2 Verify ODBC Driver

```powershell
reg query "HKLM\SOFTWARE\ODBC\ODBCINST.INI" 2>nul | findstr /i "driver"
```

**Critical version rules:**
- SQL Server 2008/2012/2014 → Use **ODBC Driver 17** (Driver 18 causes SSL errors with self-signed certs)
- SQL Server 2016+ → Either Driver 17 or 18 works
- If only Driver 18 is installed, download Driver 17 from: https://learn.microsoft.com/zh-cn/sql/connect/odbc/download-odbc-driver-for-sql-server

### 1.3 Verify bcp Tool

```powershell
where /R "C:\Program Files" bcp.exe 2>nul
```

If not found, install SQL Server Command Line Utilities:
- Download: https://www.microsoft.com/zh-cn/download/details.aspx?id=53591
- Install MsSqlCmdLnUtils.msi

If bcp is installed but not in PATH:
```powershell
setx PATH "%PATH%;C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\180\Tools\Binn" /M
```

### 1.4 Configure HammerDB Config File

Edit `C:\Program Files\HammerDB-6.0\config\mssqlserver.xml` directly when GUI settings don't persist:

```xml
<connection>
    <mssqls_server>TARGET_IP</mssqls_server>
    <mssqls_tcp>true</mssqls_tcp>
    <mssqls_port>1433</mssqls_port>
    <mssqls_authentication>sql</mssqls_authentication>
    <mssqls_odbc_driver>ODBC Driver 17 for SQL Server</mssqls_odbc_driver>
    <mssqls_uid>sa</mssqls_uid>
    <mssqls_pass>PASSWORD</mssqls_pass>
    <mssqls_encrypt_connection>false</mssqls_encrypt_connection>
    <mssqls_trust_server_cert>true</mssqls_trust_server_cert>
</connection>
```

**Critical:** `mssqls_encrypt_connection` MUST be `false` for SQL Server 2014 and older.

---

## Phase 2: Connection Testing

### 2.1 Create Connection Test Script

Create a Tcl script to test connectivity:

```tcl
#!/bin/tclsh
puts "=== Testing connection to TARGET_IP ==="
dbset db mssqls
dbset bm TPC-C
diset connection mssqls_server TARGET_IP
diset connection mssqls_linux_server TARGET_IP
diset connection mssqls_port 1433
diset connection mssqls_tcp true
diset connection mssqls_authentication sql
diset connection mssqls_uid sa
diset connection mssqls_pass PASSWORD
diset connection mssqls_odbc_driver {ODBC Driver 17 for SQL Server}
diset connection mssqls_encrypt_connection false
diset connection mssqls_trust_server_cert true
diset tpcc mssqls_dbase tpcc
puts "CHECKING..."
checkschema
puts "=== DONE ==="
```

### 2.2 Run Connection Test

```powershell
set "PATH=%PATH%;C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\180\Tools\Binn"
"C:\Program Files\HammerDB-6.0\hammerdbcli.exe" tcl auto test_connect.tcl
```

### 2.3 Common Connection Errors

| Error | Cause | Fix |
|-------|-------|-----|
| SSL provider certificate error | ODBC Driver 18 + self-signed cert | Switch to Driver 17, set encrypt_connection=false |
| "ODBC Driver 18 not found" | Driver 18 uninstalled but still referenced | Edit mssqlserver.xml, change to Driver 17 |
| "command already exists" | HammerDB internal state conflict | Restart HammerDB |
| TCP connection timeout | SQL Server not reachable | Check firewall, TCP/IP enabled, SQL Browser service |
| Login failed for user 'sa' | Wrong password or sa disabled | Verify sa password, enable sa account |

---

## Phase 3: Schema Management

### 3.1 Build Schema (Tcl Script)

```tcl
#!/bin/tclsh
puts "=== Building TPC-C Schema ==="
dbset db mssqls
dbset bm TPC-C
diset connection mssqls_server TARGET_IP
diset connection mssqls_linux_server TARGET_IP
diset connection mssqls_port 1433
diset connection mssqls_tcp true
diset connection mssqls_authentication sql
diset connection mssqls_uid sa
diset connection mssqls_pass PASSWORD
diset connection mssqls_odbc_driver {ODBC Driver 17 for SQL Server}
diset connection mssqls_encrypt_connection false
diset connection mssqls_trust_server_cert true
diset tpcc mssqls_count_ware 10
diset tpcc mssqls_num_vu 1
diset tpcc mssqls_dbase tpcc
diset tpcc mssqls_imdb false
diset tpcc mssqls_use_bcp false
puts "CONFIG DONE"
puts "START TIME: [clock format [clock seconds]]"
buildschema
puts "END TIME: [clock format [clock seconds]]"
puts "=== Schema Build Complete ==="
```

**Notes:**
- `mssqls_count_ware`: Number of warehouses (10 = ~1GB data, 100 = ~10GB)
- `mssqls_num_vu`: Virtual Users for building (use 1 for stability, 4+ for speed)
- `mssqls_use_bcp`: true = fast but may crash with multiple VUs; false = slow but stable

### 3.2 Check Schema

```tcl
#!/bin/tclsh
dbset db mssqls
dbset bm TPC-C
diset connection mssqls_server TARGET_IP
diset connection mssqls_linux_server TARGET_IP
diset connection mssqls_port 1433
diset connection mssqls_tcp true
diset connection mssqls_authentication sql
diset connection mssqls_uid sa
diset connection mssqls_pass PASSWORD
diset connection mssqls_odbc_driver {ODBC Driver 17 for SQL Server}
diset connection mssqls_encrypt_connection false
diset connection mssqls_trust_server_cert true
diset tpcc mssqls_dbase tpcc
checkschema
```

### 3.3 Delete Schema

```tcl
#!/bin/tclsh
dbset db mssqls
dbset bm TPC-C
diset connection mssqls_server TARGET_IP
diset connection mssqls_linux_server TARGET_IP
diset connection mssqls_port 1433
diset connection mssqls_tcp true
diset connection mssqls_authentication sql
diset connection mssqls_uid sa
diset connection mssqls_pass PASSWORD
diset connection mssqls_odbc_driver {ODBC Driver 17 for SQL Server}
diset connection mssqls_encrypt_connection false
diset connection mssqls_trust_server_cert true
diset tpcc mssqls_dbase tpcc
deleteschema
```

---

## Phase 4: Test Execution

### 4.1 CLI Execution with Auto-Monitoring

Create the test script:

```tcl
#!/bin/tclsh
puts "=== TPC-C Test: VU_COUNT VUs, DURATION min ==="
dbset db mssqls
dbset bm TPC-C
diset connection mssqls_server TARGET_IP
diset connection mssqls_linux_server TARGET_IP
diset connection mssqls_port 1433
diset connection mssqls_tcp true
diset connection mssqls_authentication sql
diset connection mssqls_uid sa
diset connection mssqls_pass PASSWORD
diset connection mssqls_odbc_driver {ODBC Driver 17 for SQL Server}
diset connection mssqls_encrypt_connection false
diset connection mssqls_trust_server_cert true
diset tpcc mssqls_dbase tpcc
diset tpcc mssqls_driver timed
diset tpcc mssqls_total_iterations 10000000
diset tpcc mssqls_rampup RAMPUP_MIN
diset tpcc mssqls_duration DURATION_MIN
diset tpcc mssqls_checkpoint false
diset tpcc mssqls_timeprofile true
diset tpcc mssqls_allwarehouse true
diset tpcc mssqls_keyandthink true
loadscript
puts "TEST STARTED"
puts "START TIME: [clock format [clock seconds]]"
vuset vu VU_COUNT
vuset delay DELAY_MS
vucreate
tcstart
tcstatus
set jobid [ vurun ]
vudestroy
tcstop
puts "END TIME: [clock format [clock seconds]]"
puts "TEST COMPLETE"
set of [ open $::env(TMP)/mssqls_tprocc_result w ]
puts $of $jobid
close $of
```

### 4.2 PowerShell Auto-Monitor Script

```powershell
$ErrorActionPreference = "SilentlyContinue"
$hammerdb = "C:\Program Files\HammerDB-6.0\hammerdbcli.exe"
$env:PATH += ";C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\180\Tools\Binn"
$logFile = "C:\temp\build_output.log"
$tclScript = "C:\temp\run_test.tcl"

if (Test-Path $logFile) { Remove-Item $logFile }

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $hammerdb
$psi.Arguments = "tcl auto $tclScript"
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true

$process = [System.Diagnostics.Process]::Start($psi)
$pid = $process.Id

$errorPatterns = @("Error in Virtual User", "FINISHED FAILED", "could not be established", "child killed", "SSL", "timeout")
$startTime = Get-Date
$killed = $false
$reader = $process.StandardOutput

while (-not $process.HasExited) {
    Start-Sleep -Seconds 2
    try {
        if (-not $reader.EndOfStream) {
            $line = $reader.ReadLine()
            if ($line) {
                Add-Content -Path $logFile -Value $line
                $elapsed = (Get-Date) - $startTime
                $ts = "{0:D2}:{1:D2}" -f [math]::Floor($elapsed.TotalMinutes), $elapsed.Seconds
                Write-Host "[$ts] $line" -ForegroundColor DarkGray
            }
        }
    } catch {}

    if (Test-Path $logFile) {
        $content = Get-Content $logFile -Raw
        foreach ($pattern in $errorPatterns) {
            if ($content -match [regex]::Escape($pattern)) {
                Write-Host "!!! ERROR: $pattern !!!" -ForegroundColor Red
                Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
                $killed = $true
                break
            }
        }
        if ($killed) { break }
    }
}

Start-Sleep -Seconds 2
if ($killed) {
    Write-Host "KILLED due to error" -ForegroundColor Red
    if (Test-Path $logFile) { Get-Content $logFile -Tail 20 }
} else {
    Write-Host "Test completed" -ForegroundColor Green
    if (Test-Path $logFile) {
        $content = Get-Content $logFile -Raw
        if ($content -match "TEST RESULT") {
            Select-String -Path $logFile -Pattern "TEST RESULT" | ForEach-Object { Write-Host $_.Line -ForegroundColor Green }
        }
    }
}
```

### 4.3 GUI Guidance (Step-by-Step)

When user prefers GUI, guide them through:

1. **Open HammerDB** → Double-click desktop icon
2. **Configure Driver Script**: TPROC-C → Driver Script → Options
   - Set server IP, port, authentication, ODBC Driver 17
   - Encrypt Connection: OFF
   - Trust Server Certificate: ON
   - Rampup, Duration, Use All Warehouses, Key and Think Time
3. **Configure Virtual Users**: TPROC-C → Virtual User
   - Virtual Users count, User Delay (ms)
4. **Run**: Click green ▶ Run button
5. **Monitor**: Click "Transaction Counter" tab for live TPM graph
6. **Results**: Check Virtual User 1 (MONITOR) output for final TEST RESULT line

---

## Phase 5: Result Analysis

### 5.1 Finding Results

Results are in `C:\temp\hammerdb.log`. Look for:
```
Vuser 1:TEST RESULT : System achieved XXX NOPM from XXX SQL Server TPM
```

### 5.2 Interpreting Metrics

| Metric | Meaning |
|--------|---------|
| **NOPM** | New Orders Per Minute (TPC-C primary metric) |
| **TPM** | Total Transactions Per Minute |

TPC-C transaction mix:
- New Order: 45% (measured as NOPM)
- Payment: 43%
- Order Status: 4%
- Delivery: 4%
- Stock Level: 4%

### 5.3 Reference Benchmarks

For a VM with N cores and M GB RAM, SQL Server:

| Config | Expected NOPM (1000 VU, 3s delay) |
|--------|-----------------------------------|
| 4 cores / 8GB | 1000-3000 |
| 8 cores / 16GB | 3000-6000 |
| 8 cores / 32GB | 5000-10000 |

### 5.4 Post-Test Verification

After test completes, run DBCC CHECKDB on the target SQL Server:
```sql
DBCC CHECKDB ('tpcc') WITH NO_INFOMSGS, ALL_ERRORMSGS;
```

---

## Troubleshooting Quick Reference

| Issue | Solution |
|-------|----------|
| "bcp: no such file" | Install SQL Server Command Line Utilities, add to PATH |
| SSL certificate error | Use ODBC Driver 17, set encrypt_connection=false |
| "child killed: unknown signal" | Disable BCP mode (mssqls_use_bcp false), use 1 VU for build |
| "command already exists" | Restart HammerDB |
| "Database exists but not empty" | Delete schema first, then rebuild |
| TPM very low / CPU 1% | Load too light, reduce User Delay or increase VU count |
| Connection timeout | Check firewall port 1433, TCP/IP protocol enabled |
| GUI settings don't persist | Edit mssqlserver.xml config file directly |

---

## Example: Full Test Workflow

User says: "I need to test SQL Server 2014 on youripaddress with 1000 concurrent connections for 48 hours"

Agent workflow:
1. Verify environment (HammerDB, ODBC 17, bcp)
2. Configure connection (edit mssqlserver.xml if needed)
3. Test connectivity
4. Build schema (1 VU, no BCP for stability)
5. Run trial test (50 VU, 10min) to verify
6. Run production test (1000 VU, configured duration)
7. Monitor with auto-kill script
8. Analyze results and report NOPM/TPM
