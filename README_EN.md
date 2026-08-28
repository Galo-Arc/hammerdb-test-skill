# HammerDB TPC-C Database Stress & Stability Test Skill v2

An AI Agent skill for performing TPC-C benchmark tests and full-load stability tests against SQL Server databases. Supports SQL Server 2008/2012/2014/2016/2019/2022.

[简体中文版](README.md)

## Overview

This skill enables an AI Agent to either **execute directly** or **guide database administrators through** two types of tests:

| Track | Goal | Typical Use |
|-------|------|-------------|
| **1. Standard Benchmark** | Measure peak transaction throughput (NOPM/TPM), 10–60 minutes per run | Performance baseline, configuration comparison, compatibility verification |
| **2. Soak / Stability Test** | Sustained full load for 6–48 hours with a formal five-criteria verdict (full duration, zero server errors, throughput retention ≥90%, healthy memory, zero data corruption) | Long-duration stability validation, pre-production assessment |
| **3. Sequential** | Run 1 then 2 in one session for a complete evaluation | Acceptance testing |

## Changes in v2

- **Two-track selection**: the skill's first step confirms the test track with the user, including administrator guidance scripts, to prevent mismatch between test type and requirement
- **Complete soak methodology**: saturation calibration (throughput-plateau criterion), iteration budget formula, unattended pre-flight checklist, per-minute resource monitoring, five-criteria verdict standard, and a throughput-degradation diagnosis procedure
- **Remote operation constraints**: WMI remote execution, remote scheduled tasks, and `xp_cmdshell` (including the statement that disables it) can trigger network-isolation policies on some host security systems. This skill restricts all remote operations to two channels: SMB file I/O and plain T-SQL
- **Script set**: `run_stability.tcl` (automatic iteration budget), `stability_monitor.ps1` (per-minute resource monitoring), `check_status.ps1` (read-only patrol), `dbcc_check.ps1` (DBCC InfoMessage capture), `restore_cleanup.tcl` (post-test environment restoration)
- **Troubleshooting coverage**: iteration-cap truncation, think-time throttling, DBCC output capture, PowerShell DataTable handling, 2008 R2 concurrent-connection limits, checkschema false alarms, and more

## Editions

| Edition | Directory | Platform | Notes |
|---------|-----------|----------|-------|
| **ZCode Edition** | `.zcode/skills/hammerdb-test/` | ZCode | Skill auto-trigger and execution, template auto-replacement |
| **Universal Edition** | `universal/` | AgentScope, QwenPAW, LangChain, AutoGPT, etc. | Standalone Chinese documentation, used as knowledge base or system prompt |

Both editions share identical track design, procedures, and security constraints.

## Installation

### ZCode

```bash
xcopy /E /I hammerdb-test-skill\.zcode\skills\hammerdb-test %USERPROFILE%\.zcode\skills\hammerdb-test
```

### Other platforms

Configure `universal/SKILL.md` as knowledge base or system prompt, and place the scripts from `universal/scripts/` where the agent can access them.

## Usage Examples

- "Benchmark these SQL Servers" → Standard Benchmark
- "Run a 24-hour full-load stability test" → Soak / Stability Test
- "Full evaluation: benchmark first, then soak" → Sequential

## Stability Test Requirements

Before planning a soak test, the following failure modes must be addressed in the test design (see Phase 6 of the SKILL document):

1. **Iteration-cap truncation**: in timed mode, `total_iterations` and the duration window both apply, whichever comes first. The default 10,000,000 iterations are exhausted in roughly 5–8 hours under full load, truncating long runs prematurely. Iterations must be pre-computed as `per-VU TPM × duration (minutes) × 1.3`.
2. **Think-time throttling**: with `keyandthink=true`, a single VU issues only 2–3 transactions per minute, which cannot constitute full load. Soak tests must set `keyandthink=false`.
3. **Memory metrics**: buffer-pool residency pushing memory usage to 93–99% is the normal steady state. Memory health is judged by hard page faults (Pages Input/sec) and page life expectancy (PLE).
4. **Timed window start**: the timing window starts at rampup completion; overall wall-clock time must include VU creation and teardown.

## License

MIT
