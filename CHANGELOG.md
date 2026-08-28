# 更新记录

本文件记录技能的版本变更历史。功能与用法见 [README.md](README.md)，英文版见 [CHANGELOG_EN.md](CHANGELOG_EN.md)。

## v2（2026-08-28）

### 测试方向

- 新增双测试方向：标准基准测试（10–60 分钟，测 NOPM/TPM 峰值）与满负荷稳定性测试（6–48 小时满负荷，五项判据验收），以及先基准后稳定性的顺序执行模式
- 技能启动后第一步确认测试方向与参数（引导管理员选择），避免测试类型与需求错配

### 稳定性测试方法

- 满负荷标定：VU 并发阶梯探测，以吞吐平台（而非 CPU 占用）为饱和判据
- 迭代预算：迭代上限 = 单 VU TPM × 时长(分钟) × 1.3，防止默认 1000 万迭代在满负荷下 5–8 小时内耗尽导致长时测试提前终止
- 无人值守预检清单：简单恢复模式 + 日志收缩、旧日志归档、关闭 Windows Update 自动重启、监控与压测同批启动
- 分钟级资源监控：CPU、内存、磁盘、事务日志、页预期寿命、SQL 错误日志，每 60 秒采样落盘
- 五项判据验收：跑满时长、服务端零错误、吞吐保持率 ≥90%（截尾均值法）、内存健康、DBCC CHECKDB 数据零损坏
- 吞吐退化诊断流程：Batch Requests/sec 实测 → 服务端排除 → 存活连接统计 → 归因

### 远程多服务器执行

- 安全通道约束：仅使用 SMB 文件读写与纯 T-SQL 两条通道；WMI 远程执行、远程 schtasks、xp_cmdshell 相关语句（含关闭语句）会触发部分主机安全系统的网络隔离
- 控制模式：本地计划任务 + 通过 SMB 重写 .bat/.tcl 控制下一次触发行为；/SC ONCE 定时器二次触发陷阱的规避；测试后环境自恢复（restore_cleanup.tcl）

### 脚本

- 新增：run_stability.tcl（迭代预算自动计算）、stability_monitor.ps1（分钟级资源监控）、check_status.ps1（只读巡检）、dbcc_check.ps1（DBCC InfoMessage 捕获）、restore_cleanup.tcl（环境自恢复）
- 移除：hammerdb_runner.py（Python 命令行封装，通用版改为直接使用脚本与文档流程）

### 文档

- README 重构为面向管理员与自动化工具的功能与操作说明
- 版本变更记录独立至本文件（CHANGELOG.md / CHANGELOG_EN.md），README 不再包含版本更新内容

## v1（2026-07-29 首次发布，2026-08-05 最后更新）

- 首次发布：TPC-C 基准测试完整流程——环境检查（HammerDB、ODBC 驱动、bcp）、连接测试与故障排查、TPC-C 测试库创建与管理、可配置并发与时长的压力测试、实时监控 + 自动错误终止、结果分析与报告（NOPM/TPM）
- 双版本发布：ZCode 专用版 + 通用版（含 Python 命令行封装 hammerdb_runner.py）
- 脚本：test_connection.tcl、build_schema.tcl、delete_schema.tcl、run_tpcc.tcl、auto_monitor.ps1
- 2026-08-01：SQL Server 2008 R2 兼容性——SP3 预检（RTM 版本多核登录风暴）、cust_last 存储过程手工修复、连接容量预检、Timed 模式按 VU 计时规划、checkschema 局限说明、服务器重启恢复；用户延迟默认值降为 300ms
- 2026-08-05：Windows GBK/CP936 码页崩溃修复（prepare_tcl_library.ps1 + hdb_run.bat）、2008 R2 缺失 VC++ 运行库的 0xC0000135 修复、远程多服务器执行指引（SMB + schtasks）、cust_last 修复扩展到 SQL Server 2014、DBCC CHECKDB sqlcmd 无输出问题的 dbcc_check.bat 包装
