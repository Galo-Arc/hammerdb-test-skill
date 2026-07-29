#!/bin/tclsh
# Usage: hammerdbcli tcl auto run_tpcc.tcl
# Edit the variables below before running

puts "=== TPC-C Test: __VU_COUNT__ VUs, __DURATION__ min ==="
dbset db mssqls
dbset bm TPC-C
diset connection mssqls_server __TARGET_IP__
diset connection mssqls_linux_server __TARGET_IP__
diset connection mssqls_port __PORT__
diset connection mssqls_tcp true
diset connection mssqls_authentication sql
diset connection mssqls_uid __SA_USER__
diset connection mssqls_pass __SA_PASSWORD__
diset connection mssqls_odbc_driver {__ODBC_DRIVER__}
diset connection mssqls_encrypt_connection false
diset connection mssqls_trust_server_cert true
diset tpcc mssqls_dbase tpcc
diset tpcc mssqls_driver timed
diset tpcc mssqls_total_iterations 10000000
diset tpcc mssqls_rampup __RAMPUP__
diset tpcc mssqls_duration __DURATION__
diset tpcc mssqls_checkpoint false
diset tpcc mssqls_timeprofile true
diset tpcc mssqls_allwarehouse true
diset tpcc mssqls_keyandthink true
loadscript
puts "TEST STARTED"
puts "START TIME: [clock format [clock seconds]]"
vuset vu __VU_COUNT__
vuset delay __DELAY_MS__
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
