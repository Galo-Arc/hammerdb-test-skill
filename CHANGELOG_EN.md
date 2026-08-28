# Changelog

This file records the version history of the skill. For features and usage, see [README_EN.md](README_EN.md); Chinese version: [CHANGELOG.md](CHANGELOG.md).

## v2 (2026-08-28)

### Test Tracks

- Added two test tracks: Standard Benchmark (10–60 min, peak NOPM/TPM) and Full-Load Soak/Stability Test (6–48h sustained load, five-criteria verdict), plus a sequential mode running the benchmark first and then the soak in one session
- The skill's first step now confirms the track and parameters with the user (guiding the administrator through the choice) to prevent mismatch between test type and requirement

### Soak Methodology

- Saturation calibration: VU ladder probes, with the throughput plateau (not CPU usage) as the saturation criterion
- Iteration budget: total_iterations >= per-VU TPM × duration (min) × 1.3 — the default 10M iterations are exhausted within 5–8h under full load and would truncate long runs prematurely
- Unattended pre-flight checklist: SIMPLE recovery + log shrink, old log archival, Windows Update auto-restart disabled, monitor and test started together
- Per-minute resource monitoring: CPU, memory, disk, transaction log, page life expectancy, SQL error log — one CSV sample per 60s
- Five-criteria verdict: full duration, zero server errors, throughput retention ≥90% (trimmed-mean method), healthy memory, zero data corruption via DBCC CHECKDB
- Throughput-degradation diagnosis procedure: measured Batch Requests/sec → server exoneration → surviving-session count → attribution

### Remote Multi-Server Execution

- Channel constraints: only SMB file I/O and plain T-SQL; WMI remote execution, remote schtasks, and any xp_cmdshell statement (including the one disabling it) can trigger network isolation on host security systems
- Control pattern: local scheduled task + rewriting the .bat/.tcl over SMB to change what the next trigger does; mitigation for the /SC ONCE scheduled-time re-trigger trap; post-test environment restoration (restore_cleanup.tcl)

### Scripts

- Added: run_stability.tcl (automatic iteration budget), stability_monitor.ps1 (per-minute resource monitoring), check_status.ps1 (read-only patrol), dbcc_check.ps1 (DBCC InfoMessage capture), restore_cleanup.tcl (environment restoration)
- Removed: hammerdb_runner.py (Python CLI wrapper; the universal edition now uses the scripts and documented procedures directly)

### Documentation

- README restructured as a feature-and-usage document for administrators and automation tools
- Version history moved into this file (CHANGELOG.md / CHANGELOG_EN.md); the README no longer contains version-update content

## v1 (first released 2026-07-29, last updated 2026-08-05)

- Initial release: complete TPC-C benchmark workflow — environment checks (HammerDB, ODBC driver, bcp), connection testing and troubleshooting, TPC-C schema build/verify/delete, stress runs with configurable concurrency and duration, live monitoring with automatic error termination, result analysis (NOPM/TPM)
- Two editions: ZCode edition + universal edition (with Python CLI wrapper hammerdb_runner.py)
- Scripts: test_connection.tcl, build_schema.tcl, delete_schema.tcl, run_tpcc.tcl, auto_monitor.ps1
- 2026-08-01: SQL Server 2008 R2 compatibility — SP3 pre-check (RTM multi-core login storm), manual cust_last procedure fix, connection capacity pre-check, per-VU timed-mode planning, checkschema limitation note, restart recovery; user delay default lowered to 300ms
- 2026-08-05: Windows GBK/CP936 codepage crash fix (prepare_tcl_library.ps1 + hdb_run.bat), VC++ runtime DLL deployment for 0xC0000135 on 2008 R2, remote multi-server execution guide (SMB + schtasks), cust_last fix extended to SQL Server 2014, DBCC CHECKDB sqlcmd no-output workaround (dbcc_check.bat wrapper)
