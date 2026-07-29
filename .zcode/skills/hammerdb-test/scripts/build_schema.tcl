#!/bin/tclsh
# Usage: hammerdbcli tcl auto build_schema.tcl
# Edit the variables below before running

puts "=== Building TPC-C Schema ==="
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
diset tpcc mssqls_count_ware __WAREHOUSES__
diset tpcc mssqls_num_vu __BUILD_VUS__
diset tpcc mssqls_dbase tpcc
diset tpcc mssqls_imdb false
diset tpcc mssqls_use_bcp __USE_BCP__
puts "CONFIG DONE"
puts "START TIME: [clock format [clock seconds]]"
buildschema
puts "END TIME: [clock format [clock seconds]]"
puts "=== Schema Build Complete ==="
