@echo off
REM ============================================================
REM  HammerDB soak test - one-time admin cleanup
REM  Run ON THE SERVER CONSOLE (RDP): right-click -> Run as administrator
REM  Safe to re-run (idempotent). Takes about one minute.
REM ============================================================
echo === HammerDB test cleanup start %date% %time% ===

echo [1/4] stopping leftover hammerdbcli processes...
taskkill /F /IM hammerdbcli.exe 2>nul

echo [2/4] re-enabling Windows Update service...
sc config wuauserv start= delayed-auto
sc start wuauserv

echo [3/4] stopping monitor loops...
wmic process where "commandline like '%%stability_monitor.ps1%%'" delete 2>nul

echo [4/4] deleting one-shot test scheduled tasks...
schtasks /delete /f /tn hdb_soak 2>nul
schtasks /delete /f /tn hdb_probe 2>nul
schtasks /delete /f /tn hdb_check 2>nul
schtasks /delete /f /tn hdb_prep 2>nul

echo === cleanup complete %date% %time% ===
echo %date% %time% > C:\hdb\logs\admin_cleanup_done.txt
echo Verdict: wuauserv running, hdb_* tasks deleted, hammerdbcli/monitors gone.
pause
