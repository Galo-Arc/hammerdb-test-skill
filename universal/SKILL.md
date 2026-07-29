# HammerDB TPC-C 数据库压力测试技能（通用版）

适用于任何 AI Agent 平台（AgentScope、QwenPAW、LangChain、AutoGPT 等）。

## 使用方式

将本文档作为 System Prompt 或知识库内容提供给你的 AI Agent，Agent 即可根据用户需求执行 HammerDB 压力测试。

---

## 触发条件

当用户提到以下关键词时，激活此技能：
- HammerDB、TPC-C、数据库压测、数据库压力测试
- SQL Server 性能测试、SQL Server 稳定性测试
- 数据库基准测试、数据库兼容性验证

---

## 收集信息

激活后，向用户收集以下信息：

```
1. 目标 SQL Server IP 地址和端口（默认 1433）
2. 登录方式：sa 账户密码 或 Windows 认证
3. SQL Server 版本：2008/2012/2014/2016/2019/2022
4. 操作系统版本：Windows Server 2008R2/2012R2/2016/2019/2022
5. 测试目标：兼容性测试 / 稳定性测试 / 性能基准
6. 并发连接数
7. 测试时长
8. 用户操作间隔（毫秒，默认 100ms，轻负载建议 3000ms）
```

---

## 执行流程

### 阶段 1：环境检查

检查以下组件是否已安装：

```powershell
# 检查 HammerDB
where /R "C:\Program Files" hammerdbcli.exe

# 检查 ODBC 驱动
reg query "HKLM\SOFTWARE\ODBC\ODBCINST.INI" | findstr /i "driver"

# 检查 bcp 工具
where /R "C:\Program Files" bcp.exe
```

**ODBC 驱动版本规则：**
- SQL Server 2008/2012/2014 → 必须用 ODBC Driver 17（Driver 18 有 SSL 证书问题）
- SQL Server 2016+ → Driver 17 或 18 均可

**如果缺少组件：**
- HammerDB：从 https://www.hammerdb.com 下载安装
- ODBC Driver 17：从微软官网下载
- bcp：安装 SQL Server Command Line Utilities（MsSqlCmdLnUtils.msi）

**如果 bcp 不在 PATH 中：**
```powershell
setx PATH "%PATH%;C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\180\Tools\Binn" /M
```

### 阶段 2：配置 HammerDB

编辑配置文件 `C:\Program Files\HammerDB-6.0\config\mssqlserver.xml`：

```xml
<connection>
    <mssqls_server>TARGET_IP</mssqls_server>
    <mssqls_tcp>true</mssqls_tcp>
    <mssqls_port>1433</mssqls_port>
    <mssqls_authentication>sql</mssqls_authentication>
    <mssqls_odbc_driver>ODBC Driver 17 for SQL Server</mssqls_odbc_driver>
    <mssqls_uid>sa</mssqls_uid>
    <mssqls_pass>PASSWORD</mssqls_pass>
    <mssqls_encrypt_connection>false</mssqls_encrypt_connection>
    <mssqls_trust_server_cert>true</mssqls_trust_server_cert>
</connection>
```

**关键配置：**
- `mssqls_encrypt_connection` 必须设为 `false`（SQL Server 2014 及以下）
- `mssqls_odbc_driver` 根据 SQL Server 版本选择

### 阶段 3：测试连接

使用 `scripts/test_connection.tcl` 脚本测试连接：

```powershell
set "PATH=%PATH%;C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\180\Tools\Binn"
"C:\Program Files\HammerDB-6.0\hammerdbcli.exe" tcl auto scripts\test_connection.tcl
```

脚本中的占位符需替换为实际值：
- `__TARGET_IP__` → 目标 IP
- `__PORT__` → 端口
- `__SA_USER__` → 用户名
- `__SA_PASSWORD__` → 密码
- `__ODBC_DRIVER__` → ODBC 驱动名称

### 阶段 4：创建测试库

使用 `scripts/build_schema.tcl` 脚本：

```powershell
"C:\Program Files\HammerDB-6.0\hammerdbcli.exe" tcl auto scripts\build_schema.tcl
```

**建库参数：**
- `__WAREHOUSES__`：Warehouse 数量（10 = 约 1GB 数据）
- `__BUILD_VUS__`：建库并发数（建议用 1，更稳定）
- `__USE_BCP__`：是否用 BCP 模式（多 VU 时建议设为 false）

**建库过程需 10-30 分钟，期间不要中断。**

建议使用 `scripts/auto_monitor.ps1` 监控建库过程，自动检测错误并终止。

### 阶段 5：试跑验证

先用少量 VU 试跑，确认流程正常：

修改 `scripts/run_tpcc.tcl` 中的参数：
- `__VU_COUNT__` = 50
- `__DELAY_MS__` = 3000
- `__RAMPUP__` = 2
- `__DURATION__` = 10

执行：
```powershell
powershell -ExecutionPolicy Bypass -File scripts\auto_monitor.ps1
```

确认无报错后进入正式测试。

### 阶段 6：正式压测

修改参数为用户需求的值：
- `__VU_COUNT__` = 用户指定的并发数
- `__DELAY_MS__` = 用户指定的间隔
- `__RAMPUP__` = 预热时间
- `__DURATION__` = 测试时长

执行正式压测，建议使用 auto_monitor.ps1 监控。

### 阶段 7：结果分析

测试完成后，结果保存在 `C:\temp\hammerdb.log`。

查找结果：
```powershell
findstr "TEST RESULT" C:\temp\hammerdb.log
```

结果格式：
```
TEST RESULT : System achieved XXX NOPM from XXX SQL Server TPM
```

**指标解释：**
- NOPM = New Orders Per Minute（每分钟新订单数，TPC-C 核心指标）
- TPM = Transactions Per Minute（每分钟总事务数）

**TPC-C 事务组成：**
- New Order: 45%
- Payment: 43%
- Order Status: 4%
- Delivery: 4%
- Stock Level: 4%

---

## 常见错误与解决方案

| 错误 | 原因 | 解决方案 |
|------|------|----------|
| SSL Provider 证书错误 | ODBC Driver 18 + 自签名证书 | 改用 Driver 17，设置 encrypt_connection=false |
| bcp: no such file | bcp 不在 PATH 中 | 安装 SQL 命令行工具，添加到 PATH |
| child killed: unknown signal | BCP 模式多 VU 崩溃 | 关闭 BCP 模式（use_bcp false），用单 VU 建库 |
| command already exists | HammerDB 内部状态冲突 | 重启 HammerDB |
| Database exists but not empty | 残留数据 | 先执行 delete_schema，再重建 |
| TCP 连接超时 | 网络/防火墙问题 | 检查防火墙 1433 端口，确认 TCP/IP 协议已启用 |
| TPM 极低 / CPU 1% | 负载太轻 | 减小 User Delay 或增加 VU 数量 |

---

## 脚本文件说明

| 文件 | 用途 |
|------|------|
| `scripts/test_connection.tcl` | 测试到 SQL Server 的连接 |
| `scripts/build_schema.tcl` | 创建 TPC-C 测试库 |
| `scripts/delete_schema.tcl` | 删除测试库 |
| `scripts/run_tpcc.tcl` | 执行 TPC-C 压力测试 |
| `scripts/auto_monitor.ps1` | 自动监控 + 错误自动终止 |

---

## 占位符说明

所有 `.tcl` 脚本中的占位符在使用前需替换：

| 占位符 | 说明 | 示例 |
|--------|------|------|
| `__TARGET_IP__` | SQL Server IP | `youripaddress` |
| `__PORT__` | 端口 | `1433` |
| `__SA_USER__` | 用户名 | `sa` |
| `__SA_PASSWORD__` | 密码 | `yourpassword` |
| `__ODBC_DRIVER__` | ODBC 驱动名 | `ODBC Driver 17 for SQL Server` |
| `__WAREHOUSES__` | Warehouse 数 | `10` |
| `__BUILD_VUS__` | 建库 VU 数 | `1` |
| `__USE_BCP__` | BCP 模式 | `false` |
| `__VU_COUNT__` | 并发连接数 | `1000` |
| `__DELAY_MS__` | 操作间隔(ms) | `3000` |
| `__RAMPUP__` | 预热时间(分钟) | `2` |
| `__DURATION__` | 测试时长(分钟) | `120` |
