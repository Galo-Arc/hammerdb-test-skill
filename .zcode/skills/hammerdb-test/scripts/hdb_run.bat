@echo off
REM ============================================================
REM  hdb_run.bat - run hammerdbcli under a UTF-8 headless console
REM  Fixes: hammerdbcli crashes on GBK/CP936 codepage Windows
REM  (exit 255, "invalid or incomplete multibyte or wide character"
REM   while printing the Copyright banner)
REM
REM  usage: hdb_run.bat <absolute path to .tcl script>
REM
REM  IMPORTANT: keep CRLF line endings! LF-only batches break cmd
REM  parsing with bizarre errors ('EM' is not recognized...).
REM  Output contains ANSI escape codes; strip before parsing:
REM    $t -replace '\x1b\[[0-9;?]*[A-Za-z]', ''
REM ============================================================
set "HDB_DIR=C:\HammerDB-6.0"
chcp 65001 >nul
if not exist "%TEMP%" set "TEMP=C:\Windows\Temp"
set "TMP=%TEMP%"
echo [hdb_run] starting: %~1 at %date% %time%
"C:\Windows\System32\conhost.exe" --headless cmd /c "chcp 65001 >nul & "%HDB_DIR%\hammerdbcli.exe" tcl auto "%~1""
echo [hdb_run] finished: %~1 at %date% %time%
exit /b %errorlevel%
