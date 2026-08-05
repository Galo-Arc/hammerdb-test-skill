# prepare_tcl_library.ps1 - build a patched disk Tcl library for HammerDB CLI
#
# PURPOSE:
#   hammerdbcli.exe crashes on GBK/CP936 Windows (zh-CN) printing the
#   "Copyright (c)" banner because Tcl uses the ANSI codepage for
#   piped/redirected stdout. This script extracts the embedded Tcl
#   library from the exe's zipfs to disk and prepends a UTF-8 channel
#   configuration to init.tcl. Point TCL_LIBRARY at the result and
#   hammerdbcli runs on ANY Windows version (incl. 2008 R2) with no
#   console / conhost / winpty tricks.
#
# USAGE:
#   powershell -ExecutionPolicy Bypass -File prepare_tcl_library.ps1
#     -HammerDBDir C:\HammerDB-6.0 -OutDir C:\hdb\tcl_lib
#
# THEN, for every hammerdbcli invocation (bat or task):
#   set "TCL_LIBRARY=C:\hdb\tcl_lib"
#   hammerdbcli.exe tcl auto script.tcl
#
param(
  [string]$HammerDBDir = 'C:\HammerDB-6.0',
  [string]$OutDir = 'C:\hdb\tcl_lib'
)
$ErrorActionPreference = 'Stop'
$cli = Join-Path $HammerDBDir 'hammerdbcli.exe'
if (-not (Test-Path $cli)) { Write-Host "hammerdbcli.exe not found at $cli"; exit 1 }

# 1. bootstrap override init.tcl: configure UTF-8, then copy zipfs tcl_library to OutDir
$workDir = Join-Path $env:TEMP 'tcl_override_bootstrap'
if (Test-Path $workDir) { Remove-Item $workDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $workDir | Out-Null
$outFwd = $OutDir -replace '\\', '/'
$bootstrapInit = @"
catch { chan configure stdout -encoding utf-8 }
catch { chan configure stderr -encoding utf-8 }
set dest "$outFwd"
file mkdir `$dest
proc copyTree {src dst} {
    file mkdir `$dst
    foreach item [glob -nocomplain -dir `$src *] {
        set base [file tail `$item]
        if {[file isdirectory `$item]} { copyTree `$item [file join `$dst `$base] } else { file copy -force `$item [file join `$dst `$base] }
    }
}
copyTree //zipfs:/app/tcl_library `$dest
"@
[IO.File]::WriteAllText((Join-Path $workDir 'init.tcl'), $bootstrapInit, [Text.Encoding]::ASCII)
Write-Host "bootstrap init written to $workDir"

# 2. run hammerdbcli once to trigger the copy (it will fail after copying - expected)
if (Test-Path $OutDir) { Remove-Item $OutDir -Recurse -Force }
$env:TCL_LIBRARY = $workDir
$ErrorActionPreference = 'Continue'
& $cli tcl auto (Join-Path $workDir 'noop.tcl') 2>$null | Out-Null
$ErrorActionPreference = 'Stop'
$env:TCL_LIBRARY = $null
if (-not (Test-Path (Join-Path $OutDir 'init.tcl'))) { Write-Host 'copy failed - init.tcl missing in OutDir'; exit 1 }

# 3. prepend UTF-8 channel configuration to the disk init.tcl
$initPath = Join-Path $OutDir 'init.tcl'
$prefix = "# HammerDB GBK/CP936 fix: force UTF-8 on standard channels`r`n" +
          "catch { chan configure stdout -encoding utf-8 }`r`n" +
          "catch { chan configure stderr -encoding utf-8 }`r`n"
$content = [IO.File]::ReadAllText($initPath)
[IO.File]::WriteAllText($initPath, $prefix + $content, [Text.Encoding]::UTF8)
Write-Host "patched init.tcl: $initPath"

# 4. verify: run hammerdbcli --help with TCL_LIBRARY set (piped stdout = crash scenario)
$env:TCL_LIBRARY = $OutDir
$output = & $cli --help 2>&1 | Out-String
$env:TCL_LIBRARY = $null
if ($output -match 'Usage: hammerdbcli') {
  Write-Host "VERIFY OK - hammerdbcli runs with UTF-8 stdout (banner printed: $($output -match 'HammerDB CLI') )"
  Write-Host "DONE. Set TCL_LIBRARY=$OutDir before every hammerdbcli invocation."
  exit 0
} else {
  Write-Host "VERIFY FAILED - unexpected output:"
  Write-Host $output
  exit 1
}
