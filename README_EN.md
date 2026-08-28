# HammerDB TPC-C Database Stress & Stability Test Skill

A ZCode skill for performing TPC-C benchmark tests and full-load stability tests against SQL Server databases. Supports SQL Server 2008/2012/2014/2016/2019/2022.

[简体中文版](README.md)

## Overview

This skill enables ZCode to either **execute directly** or **guide database administrators through** two types of tests — pick one, or run the benchmark first and then the soak in a single session for a complete evaluation:

| Track | Goal | Typical Use |
|-------|------|-------------|
| **1. Standard Benchmark** | Measure peak transaction throughput (NOPM/TPM), 10–60 minutes per run | Performance baseline, configuration comparison, compatibility verification |
| **2. Soak / Stability Test** | Sustained full load for 6–48 hours with a formal five-criteria verdict (full duration, zero server errors, throughput retention ≥90%, healthy memory, zero data corruption) | Long-duration stability validation, pre-production assessment |
| **3. Sequential** | Run 1 then 2 in one session for a complete evaluation | Acceptance testing |

**1. Standard Benchmark** includes:

- Environment checks (HammerDB, ODBC driver, bcp tool, SQL Server patch level)
- Database connection testing and troubleshooting
- TPC-C test schema creation and management
- Stress tests with configurable concurrency and duration
- Live monitoring with automatic error termination
- Result analysis and reporting (NOPM/TPM)

**2. Soak / Stability Test** includes:

- Saturation calibration: VU ladder probes, throughput plateau as the saturation criterion
- Iteration budget: per-VU throughput-based cap calculation so long runs last the full window
- Per-minute resource monitoring: CPU, memory, disk, transaction log, SQL error log recorded throughout
- Five-criteria verdict: full duration, zero server errors, throughput retention ≥90%, healthy memory, zero data corruption (DBCC CHECKDB)
- Automatic environment restoration after the test

## Editions

This repository provides two editions — pick the one matching your Agent platform:

| Edition | Directory | Platform | Notes |
|---------|-----------|----------|-------|
| **ZCode Edition** | `.zcode/skills/hammerdb-test/` | ZCode | Auto trigger, auto execution, template auto-replacement |
| **Universal Edition** | `universal/` | AgentScope, QwenPAW, LangChain, AutoGPT, etc. | Standalone documentation + standalone scripts |

Both editions share identical test procedures, monitoring, and verdict standards.

---

## Quick Install

### ZCode users

```bash
# Clone the repository
git clone https://github.com/Galo-Arc/hammerdb-test-skill.git

# Copy the ZCode edition into the skill directory
xcopy /E /I hammerdb-test-skill\.zcode\skills\hammerdb-test %USERPROFILE%\.zcode\skills\hammerdb-test
```

Alternatively, copy the `hammerdb-test` folder to either location:

| Location | Scope |
|----------|-------|
| `<project dir>/.zcode/skills/` | Current project only |
| `%USERPROFILE%/.zcode/skills/` | All projects on this machine |

### AgentScope / QwenPAW / other platforms

```bash
# Clone the repository
git clone https://github.com/Galo-Arc/hammerdb-test-skill.git

# The universal edition is under universal/
# Provide universal/SKILL.md to your agent as a knowledge base / system prompt
# Place the scripts from universal/scripts/ where the agent can access them
```

**Universal edition usage:**
1. Use `universal/SKILL.md` content as the system prompt or knowledge base
2. The agent follows the documented procedures and script templates

## Usage

After installation, any of the following triggers the skill:

```
/hammerdb-test run a HammerDB test on youripaddress
TPC-C stress test this SQL Server
benchmark database performance with HammerDB
run a 24-hour full-load stability test
SQL Server stability test
database compatibility verification
```

The skill first confirms the test type and parameters (IP, authentication, SQL Server/OS version, VU count, duration; soak tests additionally confirm whether the database is shared and the acceptable maintenance window), then starts executing. A standard benchmark proceeds as:

```
1. Verify the environment is ready
2. Test the database connection
3. Create the TPC-C test schema
4. Run a trial test
5. Run the production test
6. Analyze results and report
```

## Prerequisites

| Component | Required | Notes |
|-----------|----------|-------|
| HammerDB 6.0+ | Yes | Download: https://www.hammerdb.com |
| ODBC Driver 17 | Required for SQL Server 2014 and older | From Microsoft |
| ODBC Driver 18 | SQL Server 2016 and newer | Ships with SQL Server tools |
| bcp.exe | Yes | SQL Server command line utilities |
| ZCode CLI | Yes | Agent platform |

**Additional requirements for soak tests:**

- The server must not reboot or be patched during the test — reserve a complete maintenance window
- Ideally no other business workload on the target database during the test
- Reserve enough disk space for logs on the client (hours of full-load writing)

## Usage Examples

**Example 1: Standard Benchmark**

Administrator input:
```
Run a HammerDB test on 192.168.1.100 with 1000 concurrent connections,
SQL Server 2019, sa password MyPass123, for 2 hours
```

ZCode executes automatically:
```
1. Check the HammerDB installation
2. Verify ODBC Driver 17 is installed
3. Test the connection to 192.168.1.100
4. Create the TPC-C schema (10 warehouses)
5. Run a trial test (50 VUs, 10 minutes)
6. Run the production test (1000 VUs, 120 minutes)
7. Report results: XXX NOPM / XXX TPM
```

**Example 2: Full-Load Stability Test**

Administrator input:
```
Run a 24-hour full-load stability test against 192.168.1.100,
SQL Server 2014, sa password MyPass123
```

ZCode executes automatically:
```
1. Confirm duration, maintenance window, and database sharing
2. Probe the VU ladder to calibrate the full-load concurrency
3. Compute the iteration budget, deploy the monitoring scripts
4. Start the test, recording resources and throughput throughout
5. Read-only patrols; localize anomalies per the diagnosis procedure
6. Deliver the verdict based on the actual 24-hour behavior
7. Run DBCC CHECKDB and restore environment changes
```

## File Structure

```
hammerdb-test-skill/
├── README.md                           # Chinese readme (default)
├── README_EN.md                        # English readme
├── CHANGELOG.md                        # Version history
├── .gitignore
│
├── .zcode/skills/hammerdb-test/        # [ZCode Edition]
│   ├── SKILL.md                        # Main skill doc (tracks, procedures, troubleshooting)
│   ├── scripts/
│   │   ├── test_connection.tcl         # Connection test template
│   │   ├── build_schema.tcl            # Schema build template
│   │   ├── delete_schema.tcl           # Schema delete template
│   │   ├── run_tpcc.tcl                # Benchmark run template
│   │   ├── run_stability.tcl           # Soak run template (with iteration budget)
│   │   ├── auto_monitor.ps1            # PowerShell auto-monitor script
│   │   ├── stability_monitor.ps1       # Per-minute resource monitoring
│   │   ├── check_status.ps1            # Read-only patrol script
│   │   ├── dbcc_check.ps1              # DBCC CHECKDB runner
│   │   ├── dbcc_check.bat              # DBCC output-capture wrapper
│   │   ├── hdb_run.bat                 # UTF-8 console wrapper
│   │   ├── prepare_tcl_library.ps1     # Tcl library UTF-8 patch
│   │   ├── create_cust_last.sql        # Manual cust_last procedure fix
│   │   └── restore_cleanup.tcl         # Post-test environment restoration
│   └── references/
│       └── troubleshooting.md          # Troubleshooting manual
│
└── universal/                          # [Universal Edition] AgentScope / QwenPAW / others
    ├── SKILL.md                        # Full skill doc (usable as system prompt)
    ├── troubleshooting.md              # Troubleshooting manual
    └── scripts/                        # Same script set as the ZCode edition
```

## Key Features

### Two Test Types, One Workflow

The standard benchmark quickly delivers a NOPM/TPM baseline; the soak test delivers a formal acceptance verdict against five criteria; the two can run back-to-back for a complete evaluation.

### Auto Monitoring + Automatic Error Termination

`auto_monitor.ps1` watches HammerDB output in real time and kills the process as soon as an error pattern appears. No more "ran for hours but crashed in minute 5" surprises.

### Version-Adaptive Configuration

Automatically selects the correct ODBC driver for the SQL Server version:
- SQL Server 2008/2012/2014 → ODBC Driver 17 (avoids SSL certificate errors)
- SQL Server 2016+ → Driver 17 or 18 both work

### Unattended Long Runs

The soak scripts embed iteration-budget calculation and per-minute resource monitoring, with an environment-restoration script — long runs need no human supervision and automatically produce everything the verdict requires.

### Complete Troubleshooting Manual

Every error encountered in real testing is documented with cause and fix:
- SSL certificate errors
- bcp tool not found
- Connection timeouts
- Schema conflicts
- Legacy Windows / SQL Server (2008 R2 etc.) compatibility
- Performance issues

## Script Template Variables

ZCode automatically replaces the following placeholders in scripts:

| Variable | Description | Example |
|----------|-------------|---------|
| `__TARGET_IP__` | SQL Server IP address | `youripaddress` |
| `__PORT__` | SQL Server port | `1433` |
| `__SA_USER__` | Login user | `sa` |
| `__SA_PASSWORD__` | Login password | `yourpassword` |
| `__ODBC_DRIVER__` | ODBC driver name | `ODBC Driver 17 for SQL Server` |
| `__WAREHOUSES__` | Warehouse count | `10` |
| `__BUILD_VUS__` | Virtual users for schema build | `1` |
| `__USE_BCP__` | Use BCP mode | `false` |
| `__VU_COUNT__` | Concurrent connections | `1000` |
| `__DELAY_MS__` | User delay (milliseconds) | `300` |
| `__RAMPUP__` | Rampup time (minutes) | `2` |
| `__DURATION__` | Test duration (minutes) | `120` |
| `__PER_VU_TPM__` | Per-VU transactions per minute (iteration budget) | `6000` |

## Non-ZCode Users

The repository is equally usable without ZCode:

1. **Scripts**: run the `.tcl` and `.ps1` scripts directly with the HammerDB CLI
2. **Troubleshooting**: consult `references/troubleshooting.md`
3. **Procedures**: follow the steps in `SKILL.md` manually

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

Issues and improvement suggestions are welcome!

## License

MIT License

## Acknowledgments

Built on real-world testing in the following environments:
- Inspur virtualization platform
- Hygon C86 4th-generation processors
- Windows Server 2019 + SQL Server 2014

---

Version history: [CHANGELOG.md](CHANGELOG.md).
