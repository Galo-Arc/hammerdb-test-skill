@echo off
REM ============================================================
REM Restoration script for the HammerDB soak placeholder task.
REM IMPORTANT DESIGN RULE: the placeholder task must point DIRECTLY
REM to this .bat (schtasks /tr "C:\hdb\restore_cleanup.bat"), never
REM route it through hammerdbcli - a taskkill /IM hammerdbcli.exe
REM issued from inside hammerdbcli kills its own interpreter and the
%% restoration dies before doing anything (field-observed failure).
REM Safe to re-run (idempotent).
REM ============================================================
echo RESTORATION RUN %date% %time%
taskkill /F /IM hammerdbcli.exe 2>nul
sc config wuauserv start= delayed-auto
sc start wuauserv
wmic process where "commandline like '%%stability_monitor.ps1%%'" delete 2>nul
schtasks /delete /f /tn hdb_soak 2>nul
schtasks /delete /f /tn hdb_probe 2>nul
schtasks /delete /f /tn hdb_check 2>nul
schtasks /delete /f /tn hdb_prep 2>nul
echo %date% %time% > C:\hdb\logs\restore_done.txt
echo RESTORE-DONE
