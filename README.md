# HammerDB TPC-C 数据库压力/稳定性测试技能

一个 ZCode 技能，用于对 SQL Server 数据库执行 TPC-C 基准压力测试与满负荷稳定性测试。支持 SQL Server 2008/2012/2014/2016/2019/2022。

[English Version](README_EN.md)

## 功能简介

此技能使 ZCode 能够**直接执行**或**指导管理员完成**两类测试，可单选其一，也可先基准后稳定性一次完成全面评估：

| 测试类型 | 目标 | 典型场景 |
|------|------|----------|
| **① 标准基准测试** | 测量峰值事务处理能力（NOPM/TPM），单轮 10–60 分钟 | 性能基线采集、配置对比、兼容性验证 |
| **② 稳定性压力测试** | 满负荷连续运行 6–48 小时，按五项判据输出正式验收结论（跑满时长、服务端零错误、吞吐保持率 ≥90%、内存健康、数据零损坏） | 长时间运行稳定性验证、上线前评估 |
| **③ 顺序执行** | 先执行 ① 再执行 ②，一次会话完成全面评估 | 验收测试 |

**① 标准基准测试**包含：

- 环境检查（HammerDB、ODBC 驱动、bcp 工具、SQL Server 补丁级别）
- 数据库连接测试与故障排查
- TPC-C 测试库的创建与管理
- 可配置并发数和时长的压力测试
- 实时监控 + 自动错误终止
- 测试结果分析与报告（NOPM/TPM）

**② 稳定性压力测试**包含：

- 满负荷标定：按并发阶梯探测，以吞吐平台确定饱和并发数
- 迭代预算：按单 VU 吞吐自动计算迭代上限，保障长时测试跑满全程
- 分钟级资源监控：CPU、内存、磁盘、事务日志、SQL 错误日志全程记录
- 五项判据验收：跑满时长、服务端零错误、吞吐保持率 ≥90%、内存健康、数据零损坏（DBCC CHECKDB）
- 测试后环境自动恢复

## 版本选择

本仓库提供两个版本，根据你使用的 Agent 平台选择：

| 版本 | 目录 | 适用平台 | 特点 |
|------|------|----------|------|
| **ZCode 专用版** | `.zcode/skills/hammerdb-test/` | ZCode | 自动触发、自动执行、脚本模板自动替换 |
| **通用版** | `universal/` | AgentScope、QwenPAW、LangChain、AutoGPT 等任何平台 | 独立文档 + 独立脚本 |

两个版本的测试流程、监控项与验收标准保持一致。

---

## 快速安装

### ZCode 用户

```bash
# 克隆仓库
git clone https://github.com/Galo-Arc/hammerdb-test-skill.git

# 复制 ZCode 专用版到技能目录
xcopy /E /I hammerdb-test-skill\.zcode\skills\hammerdb-test %USERPROFILE%\.zcode\skills\hammerdb-test
```

或将 `hammerdb-test` 文件夹复制到以下任意位置：

| 位置 | 作用域 |
|------|--------|
| `<项目目录>/.zcode/skills/` | 仅当前项目 |
| `%USERPROFILE%/.zcode/skills/` | 本机所有项目 |

### AgentScope / QwenPAW / 其他平台用户

```bash
# 克隆仓库
git clone https://github.com/Galo-Arc/hammerdb-test-skill.git

# 通用版在 universal/ 目录下
# 将 universal/SKILL.md 作为知识库/System Prompt 提供给你的 Agent
# 将 universal/scripts/ 下的脚本放到 Agent 可访问的目录
```

**通用版使用方式：**
1. 将 `universal/SKILL.md` 内容作为 System Prompt 或知识库
2. Agent 按文档中的流程和脚本模板执行测试

## 使用方式

安装后，输入以下任意内容即可触发技能：

```
/hammerdb-test 帮我在 youripaddress 上跑 HammerDB 测试
帮我用 TPC-C 压测一下这台 SQL Server
用 HammerDB 测一下数据库性能
跑一个 24 小时满负荷稳定性测试
SQL Server 稳定性测试
数据库兼容性验证
```

技能会先确认测试类型与参数（IP、认证方式、SQL Server/OS 版本、并发数、时长；稳定性测试还需确认数据库是否共用、可接受的维护窗口），再开始执行。以标准基准测试为例：

```
1. 检查环境是否就绪
2. 测试数据库连接
3. 创建 TPC-C 测试库
4. 执行试跑验证
5. 执行正式压力测试
6. 分析结果并生成报告
```

## 前置条件

| 组件 | 是否必须 | 说明 |
|------|----------|------|
| HammerDB 6.0+ | 是 | 下载地址：https://www.hammerdb.com |
| ODBC Driver 17 | SQL Server 2014 及以下必须 | 从微软官网下载 |
| ODBC Driver 18 | SQL Server 2016 及以上 | 随 SQL Server 工具安装 |
| bcp.exe | 是 | 安装 SQL Server 命令行工具 |
| ZCode CLI | 是 | Agent 运行平台 |

**稳定性测试额外要求：**

- 测试期间服务器不能重启或打补丁，需要预留完整的维护窗口
- 被测数据库在测试期间最好无其他业务负载
- 客户端磁盘需预留足够的日志空间（多小时满负荷写入）

## 使用示例

**例 1：标准基准测试**

管理员输入：
```
帮我在 192.168.1.100 上用 1000 个并发连接跑 HammerDB 测试，
SQL Server 2019，sa 密码是 MyPass123，跑 2 小时
```

ZCode 自动执行：
```
1. 检查 HammerDB 安装情况
2. 验证 ODBC Driver 17 已安装
3. 测试到 192.168.1.100 的连接
4. 创建 TPC-C 测试库（10 个 warehouse）
5. 执行试跑测试（50 并发，10 分钟）
6. 执行正式测试（1000 并发，120 分钟）
7. 输出结果：XXX NOPM / XXX TPM
```

**例 2：满负荷稳定性测试**

管理员输入：
```
对 192.168.1.100 跑一个 24 小时满负荷稳定性测试，
SQL Server 2014，sa 密码是 MyPass123
```

ZCode 自动执行：
```
1. 确认时长、维护窗口与数据库共用情况
2. 探测并发阶梯，标定满负荷并发数
3. 计算迭代预算，部署监控脚本
4. 启动压测，全程记录资源与吞吐数据
5. 只读巡检，异常时按诊断流程定位
6. 按 24 小时实际表现给出验收结论
7. 执行 DBCC CHECKDB，恢复环境改动
```

## 文件结构

```
hammerdb-test-skill/
├── README.md                           # 中文说明（默认）
├── README_EN.md                        # 英文说明
├── CHANGELOG.md                        # 更新记录
├── .gitignore
│
├── .zcode/skills/hammerdb-test/        # 【ZCode 专用版】
│   ├── SKILL.md                        # 技能主文档（测试方向、工作流程、故障处理）
│   ├── scripts/
│   │   ├── test_connection.tcl         # 连接测试脚本模板
│   │   ├── build_schema.tcl            # 建库脚本模板
│   │   ├── delete_schema.tcl           # 删库脚本模板
│   │   ├── run_tpcc.tcl                # 基准压测脚本模板
│   │   ├── run_stability.tcl           # 稳定性测试脚本模板（含迭代预算计算）
│   │   ├── auto_monitor.ps1            # PowerShell 自动监控脚本
│   │   ├── stability_monitor.ps1       # 稳定性测试分钟级资源监控
│   │   ├── check_status.ps1            # 只读巡检脚本
│   │   ├── dbcc_check.ps1              # DBCC CHECKDB 执行脚本
│   │   ├── dbcc_check.bat              # DBCC CHECKDB 输出捕获包装
│   │   ├── hdb_run.bat                 # UTF-8 控制台包装脚本
│   │   ├── prepare_tcl_library.ps1     # Tcl 库 UTF-8 补丁准备脚本
│   │   ├── create_cust_last.sql        # cust_last 存储过程手工修复脚本
│   │   └── restore_cleanup.tcl         # 测试后环境恢复脚本
│   └── references/
│       └── troubleshooting.md          # 故障诊断手册
│
└── universal/                          # 【通用版】AgentScope / QwenPAW / 其他平台
    ├── SKILL.md                        # 完整技能文档（可作为 System Prompt）
    ├── troubleshooting.md              # 故障诊断手册
    └── scripts/                        # 与 ZCode 版相同的脚本集
```

## 核心特性

### 双测试类型，统一流程

标准基准测试快速给出 NOPM/TPM 基线；稳定性测试按五项判据给出正式验收结论；两者可顺序连跑完成全面评估。

### 自动监控 + 错误自动终止

`auto_monitor.ps1` 实时监控 HammerDB 输出，检测到错误模式即自动终止进程并报告问题。不再出现"跑了几个小时结果第 5 分钟就崩了"的情况。

### 版本自适应配置

根据 SQL Server 版本自动选择正确的 ODBC 驱动：
- SQL Server 2008/2012/2014 → ODBC Driver 17（避免 SSL 证书问题）
- SQL Server 2016+ → ODBC Driver 17 或 18 均可

### 无人值守长时运行

稳定性测试脚本内置迭代预算计算与分钟级资源监控，配合环境自恢复脚本，长时测试无需人工值守，结束后自动具备验收所需的全部数据。

### 完整的故障排查手册

实际测试中遇到的每一个错误都有记录，包含原因和解决方案：
- SSL 证书错误
- bcp 工具找不到
- 连接超时
- Schema 冲突
- 老版本 Windows / SQL Server（2008 R2 等）兼容问题
- 性能问题

## 脚本模板变量

ZCode 使用脚本时会自动替换以下占位符：

| 变量 | 说明 | 示例 |
|------|------|------|
| `__TARGET_IP__` | SQL Server IP 地址 | `youripaddress` |
| `__PORT__` | SQL Server 端口 | `1433` |
| `__SA_USER__` | 登录用户名 | `sa` |
| `__SA_PASSWORD__` | 登录密码 | `yourpassword` |
| `__ODBC_DRIVER__` | ODBC 驱动名称 | `ODBC Driver 17 for SQL Server` |
| `__WAREHOUSES__` | Warehouse 数量 | `10` |
| `__BUILD_VUS__` | 建库用的虚拟用户数 | `1` |
| `__USE_BCP__` | 是否使用 BCP 模式 | `false` |
| `__VU_COUNT__` | 并发连接数 | `1000` |
| `__DELAY_MS__` | 用户操作间隔（毫秒） | `300` |
| `__RAMPUP__` | 预热时间（分钟） | `2` |
| `__DURATION__` | 测试时长（分钟） | `120` |
| `__PER_VU_TPM__` | 单 VU 每分钟事务数（用于迭代预算） | `6000` |

## 非 ZCode 用户

即使不使用 ZCode，本仓库同样可以使用：

1. **脚本**：直接用 HammerDB CLI 执行 `.tcl` 和 `.ps1` 脚本
2. **故障排查**：参考 `references/troubleshooting.md` 解决问题
3. **操作流程**：按照 `SKILL.md` 中的步骤手动操作

## 参与贡献

1. Fork 本仓库
2. 创建功能分支
3. 提交 Pull Request

欢迎提交 Issue 和改进建议！

## 开源协议

MIT License

## 致谢

基于以下真实环境测试构建：
- 浪潮虚拟化平台
- 海光 Hygon C86 4代处理器
- Windows Server 2019 + SQL Server 2014

---

更新记录见 [CHANGELOG.md](CHANGELOG.md)。
