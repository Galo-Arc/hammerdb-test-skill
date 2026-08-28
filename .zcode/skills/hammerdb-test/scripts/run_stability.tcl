#!/bin/tclsh
# Long-run stability test: sustained full CPU+memory load, 6-48h (SKILL.md Phase 6)
# Usage: hammerdbcli tcl auto run_stability.tcl   (deploy via Phase 1.8 for unattended runs)
#
# CALIBRATION REQUIRED BEFORE USE (Phase 6.2):
#   __VU_COUNT__   = VU count from the probe ladder that saturates server CPU to 85-95%
#   __PER_VU_TPM__ = steady per-VU TPM measured at that VU count (drives the iteration budget)
#   keyandthink is FORCED false: true throttles a VU to ~2-3 tx/min via TPC-C think times
#     (Phase 6.1 trap #2) - a "full-load" run with keyandthink true is not a stress test.
#   The iteration budget is computed in-script: perVU_TPM x duration_min x 1.3 + 1M floor.
#   The usual 10,000,000 default ends "24h" runs at ~5-8h (Phase 6.1 trap #1). An
#   unreplaced __PER_VU_TPM__ placeholder makes expr fail LOUDLY here - that is intentional.

puts "=== STABILITY TEST: __VU_COUNT__ VUs x __DURATION__ min, keyandthink=false ==="
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
set perVUtpm __PER_VU_TPM__
set mins __DURATION__
set budget [expr {int($perVUtpm * $mins * 1.3) + 1000000}]
puts "ITERATION BUDGET: $perVUtpm perVU TPM x $mins min x 1.3 + 1M floor = $budget"
diset tpcc mssqls_total_iterations $budget
diset tpcc mssqls_rampup __RAMPUP__
diset tpcc mssqls_duration __DURATION__
diset tpcc mssqls_checkpoint false
diset tpcc mssqls_timeprofile true
diset tpcc mssqls_allwarehouse true
diset tpcc mssqls_keyandthink false
loadscript
puts "TEST STARTED: [clock format [clock seconds]]"
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
