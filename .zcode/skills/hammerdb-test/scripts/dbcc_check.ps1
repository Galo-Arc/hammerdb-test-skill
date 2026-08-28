# DBCC CHECKDB with InfoMessage capture - DBCC output rides TDS messages, NOT result sets.
# A plain ExecuteReader sees ZERO rows (looks like a hang). Attach the handler first.
# Works on PS 2.0 / 2008 R2. Pure ASCII. GBK output on zh-CN servers is expected.
# Usage:
#   powershell -ExecutionPolicy Bypass -File dbcc_check.ps1 -Server 10.6.110.215 -Database tpcc -OutFile dbcc_out.txt
param(
    [string]$Server = "localhost",
    [string]$Database = "tpcc",
    [string]$SqlUser = "sa",
    [string]$SqlPass = "",
    [string]$OutFile = ""
)
$ErrorActionPreference = "Continue"
if ($OutFile -eq "") { $OutFile = "dbcc_$($Server.Replace('.','_'))_$Database.txt" }

# Integrated Security when no password given (avoids a guaranteed login failure)
if ($SqlPass -eq "") {
    $c = New-Object System.Data.SqlClient.SqlConnection("Server=$Server;Integrated Security=SSPI;Connection Timeout=15")
} else {
    $c = New-Object System.Data.SqlClient.SqlConnection("Server=$Server;User Id=$SqlUser;Password=$SqlPass;Connection Timeout=15")
}
$msgs = New-Object System.Collections.ArrayList
$handler = [System.Data.SqlClient.SqlInfoMessageEventHandler]{
    param($sender, $e)
    foreach ($er in $e.Errors) { $null = $msgs.Add($er.Message) }
}
$c.add_InfoMessage($handler)
try {
    $c.Open()
    $cmd = $c.CreateCommand()
    $cmd.CommandText = "DBCC CHECKDB ('$Database') WITH ALL_ERRORMSGS"
    $cmd.CommandTimeout = 7200
    $null = $cmd.ExecuteNonQuery()
    $c.Close()
    $msgs | Out-File $OutFile -Encoding ASCII
    $ok = @($msgs | Where-Object { $_ -match "found 0 allocation errors and 0 consistency errors" })
    $bad = @($msgs | Where-Object { $_ -match "error" -and $_ -notmatch "0 allocation errors" -and $_ -notmatch "0 errors" })
    Write-Host ("messages captured: " + $msgs.Count)
    if ($ok.Count -gt 0) { Write-Host "DBCC: CLEAN" }
    elseif ($bad.Count -gt 0) { Write-Host ("DBCC: PROBLEMS - " + $bad.Count + " lines, see " + $OutFile); $bad | Select-Object -First 5 | ForEach-Object { Write-Host ("   " + $_) } }
    else { Write-Host ("DBCC: inspect " + $OutFile) }
} catch {
    Write-Host ("DBCC failed: " + $_.Exception.GetBaseException().Message)
    if ($c.State -eq "Open") { $c.Close() }
}
