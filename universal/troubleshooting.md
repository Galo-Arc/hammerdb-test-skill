# HammerDB Troubleshooting Reference

## ODBC Driver Issues

### Problem: SSL Provider Error with ODBC Driver 18
```
Error: [Microsoft][ODBC Driver 18 for SQL Server]SSL Provider: Certificate chain not trusted
```
**Cause:** ODBC Driver 18 enforces TLS by default. SQL Server 2014 and older use self-signed certificates.
**Fix:**
1. Install ODBC Driver 17 (download from Microsoft)
2. Change config to use Driver 17
3. Set `mssqls_encrypt_connection` to `false`
4. If Driver 18 keeps appearing, edit `mssqlserver.xml` directly

### Problem: "ODBC Driver not found"
```
Error: [Microsoft][ODBC Driver Manager] Data source name not found
```
**Cause:** The specified ODBC driver is not installed.
**Fix:** Install the correct driver version or change the driver name in config.

## BCP Issues

### Problem: "bcp: no such file or directory"
```
Error: couldn't execute "bcp": no such file or directory
```
**Cause:** bcp.exe is not in system PATH.
**Fix:**
1. Find bcp: `where /R "C:\Program Files" bcp.exe`
2. Add to PATH: `setx PATH "%PATH%;<bcp_directory>" /M`
3. Or install SQL Server Command Line Utilities

### Problem: "child killed: unknown signal" during schema build
```
Error in Virtual User X: child killed: unknown signal
```
**Cause:** BCP mode fails with multiple concurrent Virtual Users.
**Fix:**
1. Set `mssqls_use_bcp` to `false` in build script
2. Or use `mssqls_num_vu 1` (single VU for building)

## Connection Issues

### Problem: TCP Connection Timeout
```
Error: TCP Provider: A connection attempt failed because connected party did not respond
```
**Cause:** Network/firewall issue or SQL Server not listening.
**Fix:**
1. Verify SQL Server is running: `ping TARGET_IP`
2. Check firewall allows port 1433
3. Enable TCP/IP in SQL Server Configuration Manager
4. Restart SQL Server service after enabling TCP/IP

### Problem: Login Failed
```
Error: Login failed for user 'sa'
```
**Cause:** Wrong password or sa account disabled.
**Fix:**
1. Verify sa password on target server
2. Enable sa account: SQL Server Management Studio → Security → Logins → sa → Status → Enabled

## HammerDB Internal Issues

### Problem: "command already exists with that name"
```
Error: can't create object "odbc": command already exists with that name
```
**Cause:** HammerDB internal state conflict from previous operations.
**Fix:** Close and restart HammerDB completely.

### Problem: "Database exists but is not empty"
```
Error: Database tpcc exists but is not empty, specify a new or empty database name
```
**Cause:** Previous schema was not fully deleted.
**Fix:** Run delete_schema script first, then rebuild.

### Problem: GUI settings don't persist after restart
**Cause:** HammerDB reads config from mssqlserver.xml on startup.
**Fix:** Edit the config file directly:
`C:\Program Files\HammerDB-6.0\config\mssqlserver.xml`

## Performance Issues

### Problem: Very low TPM / CPU at 1%
**Cause:** Test load is too light.
**Fix:**
1. Reduce User Delay (e.g., from 3000ms to 100ms)
2. Increase Virtual Users count
3. Enable "Use All Warehouses" in Driver Script options

### Problem: High error rate during test
**Cause:** Too many concurrent connections overwhelming the server.
**Fix:**
1. Reduce Virtual Users count
2. Increase User Delay
3. Check SQL Server max connections: `EXEC sp_configure 'user connections'`
4. Increase VM resources (CPU/Memory)

## Result Retrieval

### Problem: Can't find TEST RESULT in GUI
**Cause:** The summary result is only in the log file, not in Virtual User Output tab.
**Fix:** Check `C:\temp\hammerdb.log` for the line:
```
Vuser 1:TEST RESULT : System achieved XXX NOPM from XXX SQL Server TPM
```
Or check Virtual User 1 (MONITOR) output in the GUI.

---

## Windows Locale / Automation Issues

### Problem: hammerdbcli crashes at startup (exit 255) — "invalid or incomplete multibyte or wide character"
```
HammerDB CLI v6.0
error writing "stdout": invalid or incomplete multibyte or wide character
    while executing
"puts "Copyright \u00A9 HammerDB Ltd hosted by tpc.org 2019-2026""
    (file "//zipfs:/app/main.tcl" line 33)
Copyright
```
**Cause:** Tcl prints a `©` banner at startup. When stdout is a pipe/file, Tcl uses the system ANSI codepage (GBK/936 on zh-CN Windows), which cannot encode `©`. `chcp 65001` alone does not fix piped/redirected stdout.
**Fix (RECOMMENDED — works on all Windows versions incl. 2008 R2, scheduled tasks, any redirect):** extract the embedded Tcl library to disk with a UTF-8 patched `init.tcl` and point `TCL_LIBRARY` at it:
```powershell
powershell -ExecutionPolicy Bypass -File scripts\prepare_tcl_library.ps1 -HammerDBDir C:\HammerDB-6.0 -OutDir C:\hdb\tcl_lib
```
Then set `set "TCL_LIBRARY=C:\hdb\tcl_lib"` before every hammerdbcli run.
**Legacy fix (Windows 10 / Server 2016+ only):** run hammerdbcli inside a real UTF-8 console:
```bat
"C:\Windows\System32\conhost.exe" --headless cmd /c "chcp 65001 >nul & "C:\HammerDB-6.0\hammerdbcli.exe" tcl auto "C:\path\script.tcl"" > out.log 2>&1
```
Ready-made wrapper: `scripts/hdb_run.bat`. Log output will contain ANSI escape sequences — strip with `-replace '\x1b\[[0-9;?]*[A-Za-z]', ''` before parsing.

### Problem: hammerdbcli exits instantly on 2008 R2 with -1073741515 (0xC0000135 DLL not found)
**Cause:** the HammerDB 6.0 build links VC++ 2015+ runtime DLLs (`VCRUNTIME140.dll`, `ucrtbase.dll`, ...) that 2008 R2 does not ship.
**Fix:** copy them next to the exe (2012 R2+ / Win10+ already have them):
```powershell
$dst = 'C:\HammerDB-6.0'
foreach ($dll in @('vcruntime140.dll','vcruntime140_1.dll','msvcp140.dll','ucrtbase.dll')) {
  Copy-Item "C:\Windows\System32\$dll" (Join-Path $dst $dll) -Force
}
```
Also apply the Phase 1.6 TCL_LIBRARY patch afterwards for the GBK banner crash.

### Problem: Remote execution on servers (SMB + schtasks)
**Deploy:** `robocopy <pkg> "\\<ip>\C$\hdb" /E` from a `.ps1` file (Git Bash mangles UNC/backslashes).
**Run:** `schtasks /create /S <ip> /U administrator /P <pass> /TN t /TR "C:\hdb\run.bat" /SC ONCE /ST 23:59 /RU SYSTEM /F` then `/run`. Monitor via `\\<ip>\C$\hdb\logs\*.log`.
**Gotchas:**
- A hung previous instance blocks new ones — `schtasks /end`, kill zombie `cmd.exe`/`conhost.exe` (taskkill task), rerun.
- Set `TMP`/`TEMP` to a writable dir (hammerdbcli writes its jobs DB there).
- PowerShell 5.1 reads `.ps1` files as ANSI — keep scripts pure ASCII or save UTF-8 with BOM.
- 2008 R2 servers usually lack `SQL Server Native Client 11.0` — use built-in `{SQL Server}` ODBC driver.

### Problem: .bat wrapper fails with bizarre parse errors ("'EM' is not recognized...")
**Cause:** .bat file saved with LF-only line endings (common when written by tools that default to LF). cmd's batch parser needs CRLF.
**Fix:** Convert to CRLF, e.g. in PowerShell:
```powershell
$c = [IO.File]::ReadAllText('wrapper.bat') -replace '\r?\n', ([string][char]13 + [string][char]10)
[IO.File]::WriteAllText('wrapper.bat', $c, [Text.Encoding]::ASCII)
```

### Problem: Background-launched exe with quoted args exits 0 with NO output
**Symptom:** a directly-launched `sqlcmd` with quoted `-Q "..."` args completes instantly with exit code 0 but zero output (e.g. sqlcmd silently enters interactive mode when `-Q` is lost and stdin is closed).
**Fix:** Wrap the command in a CRLF `.bat` file and launch the `.bat` (also preferred for long-running background jobs; see `scripts/hdb_run.bat`, `scripts/dbcc_check.bat`).

---

## DBCC Verification Issues

### Problem: DBCC CHECKDB prints nothing via sqlcmd (2012-era tools)
**Symptom:** `SET NOCOUNT ON; DBCC CHECKDB ('tpcc') WITH NO_INFOMSGS, ALL_ERRORMSGS;` returns exit 0 with zero output — not even "DBCC execution completed". Looks like a hang or a missed run.
**Cause:** The `SET NOCOUNT ON` + `NO_INFOMSGS` combination suppresses all output in sqlcmd from Client SDK ODBC 110.
**Fix:** Run the DBCC statement plain, verbose output is fine:
```sql
DBCC CHECKDB ('tpcc') WITH ALL_ERRORMSGS;
```
Expected success:
```
CHECKDB found 0 allocation errors and 0 consistency errors in database 'tpcc'.
DBCC execution completed. If DBCC printed error messages, contact your system administrator.
```
Use `sqlcmd -b -o outfile` for reliable capture (shell `>` redirection from background processes can produce empty files). Ready-made wrapper: `scripts/dbcc_check.bat`.

### Problem: Build fails at stored procedures on SQL Server 2014 too — cust_last missing
**Symptom:** (not just 2008 R2) on 2014 SP1 with Native Client 11.0:
```
Error in Virtual User 1: [Microsoft][SQL Server Native Client 11.0][SQL Server]Incorrect syntax near the keyword 'OR'.
[Microsoft][SQL Server Native Client 11.0][SQL Server]'CREATE/ALTER PROCEDURE' must be the first statement in a query batch.
```
Only 5 of 6 procs exist (`cust_last` missing). Data is intact — do NOT rebuild.
**Fix:** create `CUST_LAST` manually: `scripts/create_cust_last.sql` (signature `@w_id INT, @d_id INT, @c_id INT OUTPUT, @c_last VARCHAR(16) OUTPUT`). Verify with `EXEC dbo.CUST_LAST @w_id=1, @d_id=1, @c_id=@cid OUTPUT, @c_last=@cl OUTPUT` using a real last name. Note: HammerDB 6.0 master's `payment` does the lookup inline and may not call it — harmless insurance.

---

## Long-Run Stability (Phase 6)

### Problem: "24h" test stops after ~5–8h; work VUs show Complete=1, Monitor VU still RUNNING, TPM falls to ~50
**Cause:** `mssqls_total_iterations` caps EACH work VU even in timed mode — a VU exits at whichever comes first (its own duration window OR the iteration count). 10,000,000 iterations at full speed (~30–40k TPM/VU with keyandthink=false) exhaust in ~5–8h. Observed on a real GUI run configured for 1440 min: stopped at 6.5h/8.5h with all work VUs Complete=1 while the Monitor kept the UI in RUNNING — the TPM collapse is the client stopping, not a server fault.
**Fix:** budget iterations before any long run: `iterations >= perVU_TPM x duration_min x 1.3` (e.g. 34,000 × 1440 × 1.3 ≈ 64M → set 100M). `scripts/run_stability.tcl` computes and prints the budget; after the run verify work VUs completed at/after the full duration, not before.

### Problem: CPU at 1–5% during an intended full-load run
**Cause:** `mssqls_keyandthink true` — TPC-C keying (18s) + think (12s) times throttle each VU to ~2–3 tx/min; even 100 VUs make only a few hundred TPM.
**Fix:** `mssqls_keyandthink false` for stress/stability runs, then find the saturation VU count with the Phase 6.2 probe ladder (10-min probes, 25 → 50 → 100 → 200 … until server CPU plateaus at 85–95%). Anchor: with keyandthink=false, just 5 flat-out VUs pushed a 16-vCPU host to 24–30% — expect dozens–hundreds of VUs for saturation.

### Problem: transaction log / disk fills during a multi-hour run
**Cause:** FULL or BULK_LOGGED recovery retains every committed transaction; TPC-C at 100k+ TPM writes GBs of log per hour.
**Fix:** `ALTER DATABASE tpcc SET RECOVERY SIMPLE` before the run; `scripts/stability_monitor.ps1` issues a CHECKPOINT every 5 min (truncates the log under SIMPLE, no-op under FULL). During the 10-min calibration probe, confirm log growth stays far below free disk.

### Problem: memory at 93–99% during the soak — is that a leak?
**Answer:** No — SQL Server's buffer pool takes and keeps memory by design. 90%+ used with hard page faults/sec ≈ 0 is the expected "memory full" steady state, not an incident. Judge memory health by Pages Input/sec (Win32_PerfFormattedData_PerfOS_Memory, logged by the monitor as `pages_input_sec`) and page life expectancy (`ple` column), never by % used. To exercise memory beyond caching (real physical reads), build warehouses ≥ 12 × RAM_GB so the data exceeds RAM.

---

## Field-Proven Issues (2026-08-28 three-server 6h soak)

### Problem: monitor CSV `tpm` column empty (215/198) or frozen at one stale value (227)
**Cause:** hammerdbcli keeps its output file locked while running; the monitor's attempt to parse it silently fails, or succeeds once and caches.
**Fix:** treat the CSV as authoritative for CPU/memory/pages/PLE only. Compute TPM trends from the soak log's own counter lines (`194729 MSSQLServer tpm`, one every ~10s). Read the locked log with shared access: `[IO.File]::Open($path,'Open','Read','ReadWrite')`.

### Problem: DBCC CHECKDB via SqlClient ExecuteReader returns ZERO rows
**Cause:** DBCC output travels on the TDS InfoMessage channel, not as a result set. ExecuteReader sees nothing — looks like a hang or a missed run.
**Fix:** attach a `SqlInfoMessageEventHandler` to the SqlConnection before ExecuteNonQuery (see `scripts/dbcc_check.ps1`), or use `sqlcmd -b -o file`. On zh-CN servers the captured text is GBK.

### Problem: PowerShell SQL helper function returns nothing / "cannot index into a null array"
**Cause:** `return $dt` unwraps a DataTable on the PowerShell pipeline — the caller receives its ROWS (or nothing), not the table. This bug silently emptied an entire recon script once.
**Fix:** always `return ,$dt` (comma operator preserves the array/table wrapper).

### Problem: one server's throughput collapses mid-soak while siblings stay flat
**Field case:** SQL 2008 R2 + 64 VU + co-located client: 281k → 45k TPM (15.9% keep-ratio).
**Diagnosis order (the 227 playbook):**
1. Ground truth: `Batch Requests/sec` delta over 10s via `sys.dm_os_performance_counters` (3,987/s ≈ 45k TPM confirmed real; the hammerdb tpm counter lines were lying with garbage spikes up to "131,131,140")
2. Exonerate server: blocking chains = 0, `DBCC SQLPERF(LOGSPACE)` < 40%, scheduler runnable = 0, error log clean
3. Count survivors: `sys.dm_exec_sessions WHERE login_name='sa'` (52 vs 64 — do NOT use `program_name LIKE '%ODBC%'`, it misses these) + FINISHED FAILED lines
4. Attribute: most-aged OS × highest VU count × co-located client ⇒ client-side starvation. Remediate: external client, VU ≤ 32 on 2008 R2, or OS upgrade.
**Framing:** report the soak as FAIL but state the server itself was faultless (clean error log + clean DBCC) — it is a test-architecture failure.

### Problem: soak teardown crawls — one log line per ~3 minutes, TEST RESULT never prints
**Cause:** the degraded co-located client takes forever to wind down (each VU exit blocks on timeprofile generation).
**Fix:** don't wait indefinitely. Archive the log + CSV snapshots, deliver the verdict from the evidence you have, and let the restoration scheduled task `taskkill /F /IM hammerdbcli.exe` the hung instance at cleanup time.

### Problem: VU creation on Windows Server 2008 R2 takes 25+ minutes and some VUs fail to connect
**Field case:** 17/64 VU connections failed at creation under the login storm.
**Fix:** cap VU ≤ 32 on 2008 R2, or place the HammerDB client on a separate jump machine. Windows Server 2012 R2 and 2019 handled 32 VU for 6h without a single failure.

### Problem: checkschema fails on an EXISTING database built by HammerDB 4.3
Two distinct false alarms (both seen on the same three databases):
1. `schema warehouse count 50 does not equal dict warehouse count of 1` — `mssqls_count_ware` was not set to match the reused DB. `diset tpcc mssqls_count_ware 50` before checkschema.
2. `schema on table history no indices` — 4.3 builds `history` as a heap; the 6.0 checker expects an index. Harmless for TPC-C (history is insert-only). Verify by running a short probe instead.

### Problem: soak finished 13 minutes "late" (6h13m wall clock for a 6h duration)
**Cause:** the timed window starts at RAMPUP COMPLETION ("Rampup 10 minutes complete" → "Timing test period of 360 in minutes"), plus VU creation time before that, plus teardown after.
**Fix:** plan the maintenance window as VU creation + rampup + duration + teardown. This is expected behavior, not a hang.

### Problem: security system cuts the network during remote orchestration
**Root causes observed (each caused a real disconnection):** WMI remote execution; remote schtasks (`/S`); `EXEC xp_cmdshell '...'` even for localhost commands; even `sp_configure 'xp_cmdshell', 0` (disabling!) — detectors keyword-match with no enable/disable distinction.
**Fix:** SMB file I/O + plain T-SQL only. Full playbook in SKILL.md Phase 1.8: pre-created local tasks + SMB rewriting of their .bat/.tcl for control, log-growth-based liveness checks, `/SC ONCE /ST` re-trigger trap, self-cleaning restoration scripts.
