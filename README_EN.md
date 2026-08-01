# HammerDB TPC-C Database Stress Test Skill for ZCode

A ZCode skill for performing TPC-C database stress testing against SQL Server databases. Supports SQL Server 2008/2012/2014/2016/2019/2022.

[Simplified Chinese Version](README.md)

## What It Does

This skill enables ZCode to either **execute directly** or **guide administrators through** complete HammerDB TPC-C benchmark tests:

- Environment verification (HammerDB, ODBC drivers, bcp tools)
- Connection testing and troubleshooting
- TPC-C schema creation and management
- Pressure testing with configurable concurrency and duration
- Real-time monitoring with auto-error-kill
- Result analysis and reporting

## Version Selection

This repository provides two versions:

| Version | Directory | Platform | Features |
|---------|-----------|----------|----------|
| **ZCode Edition** | `.zcode/skills/hammerdb-test/` | ZCode | Auto-trigger, auto-execute, template auto-replacement |
| **Universal Edition** | `universal/` | AgentScope, QwenPAW, LangChain, AutoGPT, etc. | Standalone docs + Python wrapper + scripts |

---

## Quick Install

### ZCode Users

```bash
# Clone repository
git clone https://github.com/Galo-Arc/hammerdb-test-skill.git

# Copy ZCode edition to skills directory
xcopy /E /I hammerdb-test-skill\.zcode\skills\hammerdb-test %USERPROFILE%\.zcode\skills\hammerdb-test
```

### AgentScope / QwenPAW / Other Platforms

```bash
# Clone repository
git clone https://github.com/Galo-Arc/hammerdb-test-skill.git

# Universal edition is in the universal/ directory
# Provide universal/SKILL.md as System Prompt or knowledge base to your Agent
# Place universal/scripts/ in your Agent's accessible directory
```

**Universal Edition Usage:**
1. Use `universal/SKILL.md` as System Prompt or knowledge base
2. Agent follows the workflow and script templates in the document
3. Or use `universal/scripts/hammerdb_runner.py` directly:

```bash
python hammerdb_runner.py --action check_env
python hammerdb_runner.py --action test_connection --ip youripaddress --password yourpassword
python hammerdb_runner.py --action build --ip youripaddress --password yourpassword
python hammerdb_runner.py --action test --ip youripaddress --password yourpassword --vu 1000 --duration 120
```

## Usage

After installing, trigger the skill by saying any of these:

```
/hammerdb-test run a HammerDB test on youripaddress
Help me run HammerDB test on this SQL Server
Run TPC-C benchmark on 192.168.1.100
Database stress test with 1000 concurrent connections
```

ZCode will automatically:
1. Ask for your test parameters (IP, credentials, concurrency, duration)
2. Verify the environment
3. Build the test database
4. Run a trial test
5. Execute the full stress test
6. Analyze and report results

## Prerequisites

| Component | Required | Notes |
|-----------|----------|-------|
| HammerDB 6.0+ | Yes | Download from https://www.hammerdb.com |
| ODBC Driver 17 | Yes (for SQL 2014-) | Download from Microsoft |
| ODBC Driver 18 | Yes (for SQL 2016+) | Comes with SQL Server tools |
| bcp.exe | Yes | Install SQL Server Command Line Utilities |
| ZCode CLI | Yes | The agent platform |

## Example

**User input:**
```
Run HammerDB test on 192.168.1.100 with 1000 concurrent connections,
SQL Server 2019, sa password is MyPass123, run for 2 hours
```

**ZCode will:**
```
1. Check HammerDB installation
2. Verify ODBC Driver 17 is installed
3. Test connection to 192.168.1.100
4. Build TPC-C schema (10 warehouses)
5. Run trial test (50 VU, 10 min)
6. Run production test (1000 VU, 120 min)
7. Report: XXX NOPM / XXX TPM
```

## File Structure

```
hammerdb-test-skill/
├── README.md                       # Chinese docs (default)
├── README_EN.md                    # English docs
├── .gitignore
│
├── .zcode/skills/hammerdb-test/    # 【ZCode Edition】
│   ├── SKILL.md                    # Main skill document
│   ├── scripts/
│   │   ├── test_connection.tcl     # Connection test template
│   │   ├── build_schema.tcl        # Schema build template
│   │   ├── delete_schema.tcl       # Schema delete template
│   │   ├── run_tpcc.tcl            # TPC-C test run template
│   │   └── auto_monitor.ps1        # PowerShell auto-monitor
│   └── references/
│       └── troubleshooting.md      # Troubleshooting guide
│
└── universal/                      # 【Universal Edition】Any Agent platform
    ├── SKILL.md                    # Complete skill doc (for System Prompt)
    ├── troubleshooting.md          # Troubleshooting guide
    └── scripts/
        ├── test_connection.tcl     # Connection test script
        ├── build_schema.tcl        # Schema build script
        ├── delete_schema.tcl       # Schema delete script
        ├── run_tpcc.tcl            # Test run script
        ├── auto_monitor.ps1        # Auto-monitor script
        └── hammerdb_runner.py      # Python CLI wrapper
```

## Key Features

### Auto-Monitor with Error Kill
The `auto_monitor.ps1` script watches HammerDB output in real-time. If any error pattern is detected, it automatically kills the process and reports the issue. No more waiting hours only to find it crashed at minute 5.

### Version-Aware Configuration
The skill automatically selects the correct ODBC driver based on SQL Server version:
- SQL Server 2008/2012/2014 → ODBC Driver 17 (avoids SSL issues)
- SQL Server 2016+ → ODBC Driver 17 or 18

### Comprehensive Troubleshooting
Every error encountered during real-world testing is documented with cause and fix:
- SSL certificate errors
- BCP tool not found
- Connection timeouts
- Schema conflicts
- Performance issues

## Tested Environments

| Server | OS | SQL Server | Result |
|--------|-----|------------|--------|
| Inspur + Hygon C86 4G | Windows Server 2019 | SQL Server 2014 | ✅ Passed |

## Scripts Template Variables

When ZCode uses the scripts, it replaces these placeholders:

| Variable | Description | Example |
|----------|-------------|---------|
| `__TARGET_IP__` | SQL Server IP | `youripaddress` |
| `__PORT__` | SQL Server port | `1433` |
| `__SA_USER__` | Login username | `sa` |
| `__SA_PASSWORD__` | Login password | `yourpassword` |
| `__ODBC_DRIVER__` | ODBC driver name | `ODBC Driver 17 for SQL Server` |
| `__WAREHOUSES__` | Number of warehouses | `10` |
| `__BUILD_VUS__` | VUs for schema build | `1` |
| `__USE_BCP__` | Use BCP mode | `false` |
| `__VU_COUNT__` | Concurrent connections | `1000` |
| `__DELAY_MS__` | User delay in ms | `300` |
| `__RAMPUP__` | Warmup minutes | `2` |
| `__DURATION__` | Test duration minutes | `120` |

## For Non-ZCode Users

Even if you don't use ZCode, you can still benefit from this repository:

1. **Scripts**: Use the `.tcl` and `.ps1` scripts directly with HammerDB CLI
2. **Troubleshooting**: Reference `references/troubleshooting.md` for error solutions
3. **Workflow**: Follow the steps in `SKILL.md` as a manual guide

## Contributing

1. Fork this repository
2. Create a feature branch
3. Submit a pull request

Issues and improvements welcome!

## License

MIT License

## Acknowledgments

Built through real-world testing on:
- Inspur virtualization platform
- Hygon C86 4th gen processor
- Windows Server 2019 + SQL Server 2014
