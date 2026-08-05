# HammerDB TPC-C 数据库压力测试技能

一个 ZCode 技能，用于对 SQL Server 数据库执行 TPC-C 基准压力测试。支持 SQL Server 2008/2012/2014/2016/2019/2022。

[English Version](README_EN.md)

## 功能简介

此技能使 ZCode 能够**直接执行**或**指导管理员完成**完整的 HammerDB TPC-C 基准测试：

- 环境检查（HammerDB、ODBC 驱动、bcp 工具）
- 数据库连接测试与故障排查
- TPC-C 测试库的创建与管理
- 可配置并发数和时长的压力测试
- 实时监控 + 自动错误终止
- 测试结果分析与报告

## 版本选择

本仓库提供两个版本，根据你使用的 Agent 平台选择：

| 版本 | 目录 | 适用平台 | 特点 |
|------|------|----------|------|
| **ZCode 专用版** | `.zcode/skills/hammerdb-test/` | ZCode | 自动触发、自动执行、脚本模板自动替换 |
| **通用版** | `universal/` | AgentScope、QwenPAW、LangChain、AutoGPT 等任何平台 | 独立文档 + Python 封装 + 独立脚本 |

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
2. Agent 根据文档中的流程和脚本模板执行测试
3. 也可直接使用 `universal/scripts/hammerdb_runner.py` 命令行工具：

```bash
# 检查环境
python hammerdb_runner.py --action check_env

# 测试连接
python hammerdb_runner.py --action test_connection --ip youripaddress --password yourpassword

# 建库
python hammerdb_runner.py --action build --ip youripaddress --password yourpassword

# 执行压测
python hammerdb_runner.py --action test --ip youripaddress --password yourpassword --vu 1000 --duration 120
```

## 使用方式

安装后，输入以下任意内容即可触发技能：

```
/hammerdb-test 帮我在 youripaddress 上跑 HammerDB 测试
帮我用 TPC-C 压测一下这台 SQL Server
用 HammerDB 测一下数据库性能
SQL Server 稳定性测试
数据库兼容性验证
```

ZCode 会自动完成以下流程：

```
1. 询问测试参数（IP、密码、并发数、时长等）
2. 检查环境是否就绪
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

## 使用示例

**管理员输入：**
```
帮我在 192.168.1.100 上用 1000 个并发连接跑 HammerDB 测试，
SQL Server 2019，sa 密码是 MyPass123，跑 2 小时
```

**ZCode 自动执行：**
```
1. 检查 HammerDB 安装情况
2. 验证 ODBC Driver 17 已安装
3. 测试到 192.168.1.100 的连接
4. 创建 TPC-C 测试库（10 个 warehouse）
5. 执行试跑测试（50 并发，10 分钟）
6. 执行正式测试（1000 并发，120 分钟）
7. 输出结果：XXX NOPM / XXX TPM
```

## 文件结构

```
hammerdb-test-skill/
├── README.md                           # 中文说明（默认）
├── README_EN.md                        # 英文说明
├── .gitignore
│
├── .zcode/skills/hammerdb-test/        # 【ZCode 专用版】
│   ├── SKILL.md                        # 技能主文档（触发规则与工作流程）
│   ├── scripts/
│   │   ├── test_connection.tcl         # 连接测试脚本模板
│   │   ├── build_schema.tcl            # 建库脚本模板
│   │   ├── delete_schema.tcl           # 删库脚本模板
│   │   ├── run_tpcc.tcl                # 压测执行脚本模板
│   │   └── auto_monitor.ps1            # PowerShell 自动监控脚本
│   └── references/
│       └── troubleshooting.md          # 故障诊断手册
│
└── universal/                          # 【通用版】AgentScope / QwenPAW / 其他平台
    ├── SKILL.md                        # 完整技能文档（可作为 System Prompt）
    ├── troubleshooting.md              # 故障诊断手册
    └── scripts/
        ├── test_connection.tcl         # 连接测试脚本
        ├── build_schema.tcl            # 建库脚本
        ├── delete_schema.tcl           # 删库脚本
        ├── run_tpcc.tcl                # 压测脚本
        ├── auto_monitor.ps1            # 自动监控脚本
        └── hammerdb_runner.py          # Python 命令行封装（任何 Agent 可调用）
```

## 核心特性

### 自动监控 + 错误自动终止

`auto_monitor.ps1` 脚本实时监控 HammerDB 输出。一旦检测到错误模式，自动终止进程并报告问题。不再出现"跑了几个小时结果第5分钟就崩了"的情况。

### 版本自适应配置

根据 SQL Server 版本自动选择正确的 ODBC 驱动：
- SQL Server 2008/2012/2014 → ODBC Driver 17（避免 SSL 证书问题）
- SQL Server 2016+ → ODBC Driver 17 或 18 均可

### 完整的故障排查手册

实际测试中遇到的每一个错误都有记录，包含原因和解决方案：
- SSL 证书错误
- bcp 工具找不到
- 连接超时
- Schema 冲突
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
