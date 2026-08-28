# HammerDB TPC-C 数据库压力/稳定性测试技能 v2

一个用于对 SQL Server 数据库执行 TPC-C 基准测试与满负荷稳定性测试的 AI Agent 技能。支持 SQL Server 2008/2012/2014/2016/2019/2022。

[English Version](README_EN.md)

## 功能简介

本技能使 AI Agent 能够**直接执行**或**引导数据库管理员完成**两类测试：

| 测试方向 | 目标 | 典型场景 |
|------|------|----------|
| **① 标准基准测试** | 测量峰值事务处理能力（NOPM/TPM），单轮 10–60 分钟 | 性能基线采集、配置对比、兼容性验证 |
| **② 稳定性压力测试** | 满负荷连续运行 6–48 小时，按五项判据输出正式验收结论（跑满时长、服务端零错误、吞吐保持率 ≥90%、内存健康、数据零损坏）| 长时间运行稳定性验证、上线前评估 |
| **③ 顺序执行** | 先执行 ① 再执行 ②，一次会话完成全面评估 | 验收测试 |

## v2 版本变更

- **双测试方向**：技能启动后第一步确认测试方向（含管理员引导话术），避免测试类型与需求错配
- **稳定性测试完整流程**：饱和标定（以吞吐平台为判据）、迭代预算计算公式、无人值守预检清单、分钟级资源监控、五判据验收标准、吞吐退化诊断流程
- **远程操作安全约束**：WMI 远程执行、远程计划任务、`xp_cmdshell`（包括关闭该功能的语句）会触发部分主机安全系统的网络隔离策略；本技能限定使用 SMB 文件读写与纯 T-SQL 两条通道完成全部远程操作
- **脚本集**：`run_stability.tcl`（迭代预算自动计算）、`stability_monitor.ps1`（分钟级资源监控）、`check_status.ps1`（只读巡检）、`dbcc_check.ps1`（DBCC InfoMessage 捕获）、`restore_cleanup.tcl`（测试后环境自恢复）
- **故障排查手册**：覆盖迭代上限截断、思考时间限速、DBCC 输出捕获、PowerShell DataTable 传递、2008 R2 并发建连限制、checkschema 误报等常见问题

## 版本选择

| 版本 | 目录 | 适用平台 | 说明 |
|------|------|----------|------|
| **ZCode 版** | `.zcode/skills/hammerdb-test/` | ZCode | 技能自动触发与执行，脚本模板自动替换 |
| **通用版** | `universal/` | AgentScope、QwenPAW、LangChain、AutoGPT 等 | 独立中文文档，作为知识库或 System Prompt 使用 |

两个版本的测试方向设计、执行流程与安全约束保持一致。

## 安装

### ZCode

```bash
xcopy /E /I hammerdb-test-skill\.zcode\skills\hammerdb-test %USERPROFILE%\.zcode\skills\hammerdb-test
```

### 其他平台

将 `universal/SKILL.md` 配置为知识库或 System Prompt，`universal/scripts/` 下的脚本放置到 Agent 可访问目录。

## 使用示例

- "帮我测一下这三台 SQL Server 的性能" → 标准基准测试
- "跑一个 24 小时满负荷稳定性测试" → 稳定性压力测试
- "全面评估，先基准再稳定性" → 顺序执行

## 稳定性测试注意事项

规划与执行稳定性测试前，以下失效模式必须在方案中规避（详见 SKILL 文档第 6 章）：

1. **迭代上限截断**：Timed 模式下 `total_iterations` 与时长窗口同时生效，先到先停。默认 1000 万次迭代在满速负载下约 5–8 小时耗尽，导致长时测试提前终止。迭代数必须按 `每 VU TPM × 时长(分钟) × 1.3` 预先计算。
2. **思考时间限速**：`keyandthink=true` 时单 VU 约 2–3 事务/分钟，无法构成满负荷。稳定性测试必须设置 `keyandthink=false`。
3. **内存指标口径**：缓冲池驻留数据使内存占用达 93–99% 属正常稳态。内存健康以硬页错误（Pages Input/sec）与页预期寿命（PLE）为准。
4. **计时窗口起点**：Timed 模式计时从预热（rampup）结束后开始，整体墙钟需计入 VU 创建与收尾时间。

## License

MIT
