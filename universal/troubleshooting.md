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
