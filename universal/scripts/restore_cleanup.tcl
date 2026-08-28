# Self-cleaning restoration script, executed LOCALLY by the hdb_soak scheduled task.
# This is the Phase 1.8 "self-cleaning restoration pattern": rewrite the task's target
# .tcl via SMB, then let the task's own re-trigger run it natively on the server.
# Zero remote execution at cleanup time. Tcl (hammerdbcli) syntax.

puts "RESTORATION RUN [clock format [clock seconds]]"
# 1. kill leftover/hung hammerdbcli from the soak (degraded clients can hang in teardown)
if {[catch {
    exec taskkill.exe /F /IM hammerdbcli.exe
    puts "leftover hammerdbcli killed"
} err0]} { puts "hammerdbcli cleanup note: $err0" }
# 2. re-enable Windows Update (was disabled for the test window)
if {[catch {
    exec sc.exe config wuauserv start= delayed-auto
    exec sc.exe start wuauserv
    puts "wuauserv re-enabled"
} err1]} { puts "wuauserv restore err: $err1" }
# 3. stop monitor loops (matched by command line - never a blanket powershell kill)
if {[catch {
    exec wmic.exe process where "commandline like '%stability_monitor.ps1%'" delete
    puts "monitor loops killed"
} err2]} { puts "monitor kill err: $err2" }
# 4. delete all test scheduled tasks, including the one running this script.
#    CAVEAT: on legacy Windows (2008 R2) deleting a RUNNING task can fail even with /f.
#    That is caught and logged below; if tasks survive, remove them manually in Task
#    Scheduler the next day - re-runs of this script are harmless (idempotent).
#    NOTE: wmic.exe is absent on the newest Windows builds; on such hosts replace the
#    wmic line with: powershell -Command "Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object CommandLine -like '*stability_monitor*' | Remove-CimInstance"
foreach t {hdb_soak hdb_probe hdb_check hdb_prep} {
    if {[catch { exec schtasks.exe /delete /f /tn $t } err3]} {
        puts "task $t delete err: $err3"
    } else { puts "task $t deleted" }
}
# 5. receipt
set f [open C:/hdb/logs/restore_done.txt w]
puts $f "RESTORE DONE [clock format [clock seconds]]"
close $f
puts "RESTORE-DONE"
