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
**Fix (tested on Windows Server 2019 build 17763, zh-CN):** run hammerdbcli inside a real UTF-8 console:
```bat
"C:\Windows\System32\conhost.exe" --headless cmd /c "chcp 65001 >nul & "C:\HammerDB-6.0\hammerdbcli.exe" tcl auto "C:\path\script.tcl"" > out.log 2>&1
```
Ready-made wrapper: `scripts/hdb_run.bat`. Log output will contain ANSI escape sequences — strip with `-replace '\x1b\[[0-9;?]*[A-Za-z]', ''` before parsing.

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
