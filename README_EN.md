# HammerDB TPC-C Database Stress & Stability Test Skill v2

An AI Agent skill for performing TPC-C benchmark tests and full-load stability tests against SQL Server databases. Supports SQL Server 2008/2012/2014/2016/2019/2022.

[简体中文版](README.md)

## What It Does

This skill enables an AI Agent to either **execute directly** or **guide administrators through** two types of tests:

| Track | Goal | Typical Use |
|-------|------|-------------|
| **1. Standard Benchmark** | Measure peak transaction throughput (NOPM/TPM) in 10–60 minutes | Performance baseline, config comparison, compatibility verification |
| **2. Soak / Stability Test** | Sustained full load for 6–48 hours with a formal five-criteria verdict (zero errors / retention ≥90% / memory healthy / zero corruption / full duration) | "Can it survive 24 hours?" endurance validation |
| **3. Sequential** | 1 then 2 in one session for a full assessment | Acceptance testing, pre-production evaluation |

## What's New in v2 (driven by real-world runs, Aug 2026)

- **Two-track decision tree**: the skill's first step is confirming the track with the user, including ready-to-use guidance scripts for administrators
- **Full soak methodology (Phase 6)**: saturation calibration (throughput-plateau criterion), iteration budget formula, unattended pre-flight, per-minute monitoring, five-criteria verdict, and a degradation-diagnosis playbook — all field-proven on a 3-server 6-hour run (exact wall-clock 6h13m; caught and root-caused a 5.6x throughput degradation on one server)
- **Security-safe channel hard rules**: field incidents proved that WMI remote execution, remote scheduled tasks, and xp_cmdshell (even the *disabling* statement) trigger host security systems with forced disconnection. Codified as two allowed channels only — SMB file I/O + plain T-SQL — plus derived orchestration patterns (local tasks controlled by SMB script rewriting, the one-shot task re-trigger trap, self-cleaning restoration scripts)
- **New field-proven scripts**: `run_stability.tcl` (auto iteration budget), `stability_monitor.ps1` (per-minute resource monitor), `check_status.ps1` (read-only patrol), `dbcc_check.ps1` (InfoMessage capture), `restore_cleanup.tcl` (self-cleaning restoration)
- **Troubleshooting expanded**: 10+ field entries (monitor tpm column trap, DBCC InfoMessage channel, PowerShell DataTable unwrapping, 2008 R2 VU creation storm, checkschema false alarms, Timed window start point, and more)

## Editions

| Edition | Directory | Platform | Notes |
|---------|-----------|----------|-------|
| **ZCode Edition** | `.zcode/skills/hammerdb-test/` | ZCode | Auto-trigger, auto-execute, template auto-replacement |
| **Universal Edition** | `universal/` | AgentScope, QwenPAW, LangChain, AutoGPT, any platform | Standalone doc (Chinese) + scripts, used as knowledge base / system prompt |

Both editions carry identical track design, procedures, and security rules.

## Quick Install

### ZCode users

```bash
xcopy /E /I hammerdb-test-skill\.zcode\skills\hammerdb-test %USERPROFILE%\.zcode\skills\hammerdb-test
```

### QwenPAW / AgentScope / other platforms

Provide `universal/SKILL.md` as knowledge base or system prompt, place `universal/scripts/` where your agent can reach them, and follow the two-track workflow in the document.

## Usage Examples

- "Benchmark these SQL Servers" → Standard Benchmark
- "Run a 24h full-load stability test" → Soak test (auto calibration → budget → monitoring → five-criteria verdict)
- "Full evaluation: benchmark first, then soak" → Sequential

## The Four Silent Traps of Soak Testing (core value of v2)

1. **`total_iterations` caps each VU even in timed mode** — the default 10M ends a "24-hour test" after 5–8 hours silently (observed: a GUI test targeting 24h actually ran 27%)
2. **Think times throttle load by 4 orders of magnitude** — keyandthink must be OFF for full-load tests
3. **93–99% memory usage is the buffer pool's normal steady state** — health criteria are hard page faults and page life expectancy, not % used
4. **The timed window starts at rampup end** — end-time planning must account for it

Security: all remote operations use only the two field-proven zero-alert channels (SMB file I/O + plain T-SQL), avoiding WMI / remote scheduled tasks / xp_cmdshell patterns that trigger host security systems.

## License

MIT
