@echo off
REM ============================================================
REM  dbcc_check.bat - DBCC CHECKDB wrapper (sqlcmd -o capture)
REM
REM  usage: dbcc_check.bat <server> <user> <password> <db> <outfile>
REM  example: dbcc_check.bat localhost sa mypass tpcc logs\dbcc.log
REM
REM  IMPORTANT: keep CRLF line endings!
REM  NOTE: do NOT prefix with "SET NOCOUNT ON" and do NOT use
REM  WITH NO_INFOMSGS - the 2012-era sqlcmd (Client SDK ODBC 110)
REM  suppresses ALL output (even the completion message) with that
REM  combination, exiting 0 silently.
REM ============================================================
set "SQLCMD=C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\110\Tools\Binn\SQLCMD.EXE"
if not exist "%SQLCMD%" set "SQLCMD=sqlcmd"
echo [dbcc] starting at %date% %time%
"%SQLCMD%" -S %~1 -U %~2 -P %~3 -d %~4 -l 30 -b -o %~5 -Q "DBCC CHECKDB ('%~4') WITH ALL_ERRORMSGS;"
echo [dbcc] finished at %date% %time% exit=%errorlevel%
exit /b %errorlevel%
