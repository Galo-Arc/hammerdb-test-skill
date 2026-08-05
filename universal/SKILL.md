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
8. 用户操作间隔（毫秒，默认 100ms，轻负载建议 300ms）
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

**Windows 中文/日文系统代码页崩溃（重要）：**
`hammerdbcli.exe` 在 GBK/CP936 系统（如简体中文 Windows）上会因打印 `©` 版权横幅而立即崩溃（exit 255）：
```
HammerDB CLI v6.0
error writing "stdout": invalid or incomplete multibyte or wide character
    while executing
"puts "Copyright \u00A9 HammerDB Ltd hosted by tpc.org 2019-2026""
```
即使 `chcp 65001` 也无济于事（stdout 被重定向/管道时 Tcl 使用系统 ANSI 代码页）。**推荐方案（全 Windows 版本通用，含 2008 R2、计划任务、任意重定向场景）**：把 exe 内嵌的 Tcl 库解包到磁盘并注入 UTF-8 配置，通过 `TCL_LIBRARY` 加载（一键脚本 `scripts/prepare_tcl_library.ps1`）：
```powershell
powershell -ExecutionPolicy Bypass -File scripts\prepare_tcl_library.ps1 -HammerDBDir C:\HammerDB-6.0 -OutDir C:\hdb\tcl_lib
```
之后每次运行 hammerdbcli 前设置：`set "TCL_LIBRARY=C:\hdb\tcl_lib"`。
**旧方案（仅 Win10/Server 2016+，conhost 的 --headless 在 2008 R2/2012 R2 无效）**：用 `conhost --headless` 提供 UTF-8 控制台：
```bat
"C:\Windows\System32\conhost.exe" --headless cmd /c "chcp 65001 >nul & "C:\HammerDB-6.0\hammerdbcli.exe" tcl auto scripts\xxx.tcl" > out.log 2>&1
```
注意：
- `.bat` 包装文件必须是 **CRLF 换行**（LF 会导致 cmd 解析错乱，出现 `'EM' 不是内部或外部命令` 之类的怪错）
- conhost 输出含 ANSI 转义码，解析日志前先过滤：`$t -replace '\x1b\[[0-9;?]*[A-Za-z]', ''`
- 日志中 `©` 可能显示为 `?`，无害
- winpty 不是好方案：msvc 构建无 winpty.exe，msys2/cygwin 构建依赖运行时 DLL 且新版不支持 2008 R2

**旧系统（2008 R2）无法启动 hammerdbcli（0xC0000135）：**
退出码 -1073741515 = DLL 缺失。把 VC++ 运行库复制到 exe 旁：
```powershell
$dst = 'C:\HammerDB-6.0'
foreach ($dll in @('vcruntime140.dll','vcruntime140_1.dll','msvcp140.dll','ucrtbase.dll')) {
  Copy-Item "C:\Windows\System32\$dll" (Join-Path $dst $dll) -Force
}
```

**远程多服务器执行（SMB + schtasks）：**
1. 部署：从 `.ps1` 文件里执行 `robocopy <包> "\\<IP>\C$\hdb" /E`（Git Bash 会破坏 UNC 反斜杠参数）
2. 执行：`schtasks /create /S <IP> /U administrator /P <密码> /TN 任务 /TR "C:\hdb\run.bat" /SC ONCE /ST 23:59 /RU SYSTEM /F` + `/run`
3. 监控：读 `\\<IP>\C$\hdb\logs\*.log`
4. 坑：任务旧实例挂起会挡住新实例（`schtasks /end` + taskkill 僵尸 cmd/conhost）；TMP/TEMP 要指向可写目录（hammerdbcli 的 jobs 库写在那里）；PS 5.1 按 ANSI 读 .ps1（脚本保持纯 ASCII 或存 UTF-8 BOM）；2008 R2 服务器通常没有 Native Client 11.0（报"未发现数据源名称"）→ 用内置 `{SQL Server}` 驱动

### 阶段 1.5：版本与连接能力预检（重要）

**任何测试前必须先确认 SQL Server 版本和补丁级别**，否则版本问题会伪装成网络/配置问题，浪费大量时间。

**检查版本：**
```powershell
# 用 SqlClient（PowerShell 内置；sqlcmd 可能因缺少 ODBC Driver 18 而报错）
$conn = New-Object System.Data.SqlClient.SqlConnection("Server=目标IP;User Id=sa;Password=密码;Timeout=15")
$conn.Open(); $cmd = $conn.CreateCommand()
$cmd.CommandText = "SELECT @@VERSION, SERVERPROPERTY('ProductLevel')"
$r = $cmd.ExecuteReader(); $r.Read(); Write-Host $r[0]; Write-Host "补丁级别: $($r[1])"; $conn.Close()
```

**关键：SQL Server 2008 R2 必须安装 SP3（10.50.6000+）**
- 2008 R2 **RTM（10.50.1600.1）** 存在已知的多核并发 bug：高负载下每次登录耗时 20-35 秒、吞吐极低，表现为 HammerDB 建 VU/启动 VU 极其缓慢、TPM 远低于硬件应有水平、800 并发数小时都起不来
- 安装 **SP3（10.50.6000）** 后登录耗时降到约 0.005 秒/个（实测提升 3000 倍）；SP3 + CU1 = 10.50.6220
- 若服务器是 RTM，**先让用户安装 SP3 再测试**，不要在 RTM 上跑基准测试

**测连接能力（决定并发数）：**
```powershell
# 计时 30 个 ODBC Driver 17 顺序连接（与 HammerDB 相同的连接路径）
$sw = [System.Diagnostics.Stopwatch]::StartNew()
for ($i = 0; $i -lt 30; $i++) {
    $c = New-Object System.Data.Odbc.OdbcConnection("Driver={ODBC Driver 17 for SQL Server};Server=目标IP;Uid=sa;Pwd=密码;Encrypt=no;TrustServerCertificate=yes;")
    $c.Open(); $c.Close()
}
$sw.Stop()
Write-Host "30 个连接: $([math]::Round($sw.Elapsed.TotalSeconds,2)) 秒, 平均 $([math]::Round($sw.Elapsed.TotalSeconds/30,3)) 秒/个"
```
- 平均 < 0.1 秒 → 健康，可以支持大并发
- 平均 > 1 秒 → 存在连接瓶颈（先查补丁级别，再查网络/防火墙/服务器负载），并发数宜取 100-200 而非 800
- 经验：**服务器在 30-60 分钟内能接受的连接数 ≈ 实际可行的并发上限**

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

**已知局限：** `checkschema` 可能在缺少存储过程时仍然通过（实测缺 1 个 SP 也能通过）。若构建日志中出现过存储过程报错，必须用以下命令单独核验 6 个存储过程（delivery、neword、ostat、payment、slev、cust_last）：
```sql
SELECT name FROM sys.procedures ORDER BY name
```

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

**已知问题（SQL Server 2008 R2 / 2014）：** 建库最后一步"创建存储过程"可能失败（实测 2014 SP1 12.0.4237.0 + SQL Server Native Client 11.0 同样中招）：
```
Error in Virtual User 1: [Microsoft][SQL Server Native Client 11.0][SQL Server]Incorrect syntax near the keyword 'OR'.
[Microsoft][SQL Server Native Client 11.0][SQL Server]'CREATE/ALTER PROCEDURE' must be the first statement in a query batch.
```
结果：6 个存储过程中 `cust_last` 缺失（数据不受影响）。**不要删除重建 schema（会浪费 30+ 分钟）**，手工补建即可（现成脚本：`scripts/create_cust_last.sql`）。修复要点：
- 参数签名必须与 HammerDB 调用一致：`@w_id INT, @d_id INT, @c_id INT OUTPUT, @c_last VARCHAR(16) OUTPUT`
- 用 2008 R2 兼容的 T-SQL 实现"按姓氏查中间客户"（游标 + `@@FETCH_STATUS`），完整脚本见 `scripts/create_cust_last.sql`，或按以下逻辑编写：
```sql
CREATE PROCEDURE dbo.CUST_LAST
@w_id INT, @d_id INT, @c_id INT OUTPUT, @c_last VARCHAR(16) OUTPUT
AS
BEGIN
    -- 用游标按 c_first 排序扫描 customer 表（WHERE c_w_id=@w_id AND c_d_id=@d_id AND c_last=@c_last）
    -- 第一遍统计行数 N，第二遍取第 (N+1)/2 行（TPC-C 中间客户规则），将 c_id 和 c_last 写入输出参数
END
```
- 通过 SqlClient 执行（单个 CREATE PROCEDURE 批不需要 GO），建好后用真实姓氏（如 'ABLEABLEABLE'）测试一次
- 备注：HammerDB 6.0（GitHub master）的 payment 过程已改为内联按姓氏查询，不调用 cust_last；补建纯属保险（checkschema 可能期望 6 个 SP）。核验是否被引用：`SELECT OBJECT_NAME(object_id) FROM sys.sql_modules WHERE definition LIKE '%cust_last%'`

### 阶段 5：试跑验证

先用少量 VU 试跑，确认流程正常：

修改 `scripts/run_tpcc.tcl` 中的参数：
- `__VU_COUNT__` = 50
- `__DELAY_MS__` = 300
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

**重要：timed 模式的实际耗时（每 VU 各自计时）**

HammerDB 的 timed 模式是**每个虚拟用户从自己启动起单独计时 duration 分钟**，不是全局计时。测试在最后一个 VU 完成自己的计时窗口后才结束。

总墙钟时间 ≈ **VU 创建时间 + VU 启动时间 + duration**：
- VU 创建：约 4 秒/个，串行，**受客户端限制**（800 个约 55 分钟）
- VU 启动：约 20-35 秒/个（分批启动时）
- 例：200 VU / 60 分钟的实际耗时约 2-2.5 小时；800 VU 可能超过 4 小时

**注意事项：**
- 测试运行时间远超 duration **不代表卡死**——检查日志中是否仍在出现 `Vuser N:RUNNING`，出现即说明还在启动 VU
- 分批启动导致最终 NOPM/TPM 是"爬坡+满载"的混合平均值，**会低估满载性能**；可参考全部 VU 活跃期间的实时 TPM 采样值作为稳态参考
- 提前终止时：先 `Stop-Process hammerdbcli` 停客户端，再存档日志（HammerDB 会跨轮追加写入 hammerdb.log，旧 TEST RESULT 会干扰结果提取）

**服务器中途重启（数据安全，运行作废）：**
1. 已建好的 schema 数据（表、行、存储过程含手工修复的 cust_last）**全部持久化在数据库中，不需要重建**，丢失的只是当前这轮运行
2. 先干净停掉客户端（杀 hammerdbcli + 停监控脚本），存档日志
3. 服务器恢复后：确认 1433 端口 → 确认版本 → 跑 checkschema（约 1 分钟）→ 直接重跑原测试脚本
4. 恢复总耗时约 5 分钟，**切勿删除/重建 schema**

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

**压测后完整性校验（建议）：**
```sql
DBCC CHECKDB ('tpcc') WITH ALL_ERRORMSGS;
```
成功标志：`CHECKDB found 0 allocation errors and 0 consistency errors in database 'tpcc'.`
注意（2012 版 sqlcmd 的坑）：语句前**不要**加 `SET NOCOUNT ON`，也**不要**用 `NO_INFOMSGS`——两者组合会让 sqlcmd 完全无输出（连完成消息都不打印，退出码仍为 0）。建议用 `sqlcmd -b -o 输出文件` 捕获（现成脚本：`scripts/dbcc_check.bat`）。

---

## 常见错误与解决方案

| 错误 | 原因 | 解决方案 |
|------|------|----------|
| SSL Provider 证书错误 | ODBC Driver 18 + 自签名证书 | 改用 Driver 17，设置 encrypt_connection=false |
| bcp: no such file | bcp 不在 PATH 中 | 安装 SQL 命令行工具，添加到 PATH |
| child killed: unknown signal | BCP 模式多 VU 崩溃 | 关闭 BCP 模式（use_bcp false），用单 VU 建库 |
| command already exists | HammerDB 内部状态冲突 | 重启 HammerDB |
| Database exists but not empty | 残留数据 | 先执行 delete_schema，再重建 |
| 建库最后一步存储过程报错（"OR"语法错误，2008 R2 / 2014 都会） | HammerDB 6.0 兼容问题 | 手工补建 cust_last（scripts/create_cust_last.sql），数据未丢失，不要重建 schema |
| hammerdbcli 启动即崩（Copyright © 横幅，exit 255，GBK/中文系统） | 系统 ANSI 代码页无法编码 © | 推荐：TCL_LIBRARY 补丁（scripts/prepare_tcl_library.ps1）；Win10+ 可用 conhost --headless + chcp 65001 |
| hammerdbcli 在 2008 R2 上启动即退（0xC0000135 / -1073741515） | 缺 VC++ 运行库 DLL | 复制 vcruntime140/vcruntime140_1/msvcp140/ucrtbase.dll 到 exe 旁 |
| DBCC CHECKDB 经 sqlcmd 无任何输出 | SET NOCOUNT ON + NO_INFOMSGS 组合（2012 版 sqlcmd） | 去掉两者，用 `DBCC CHECKDB ('tpcc') WITH ALL_ERRORMSGS;` + `-o` 输出（scripts/dbcc_check.bat） |
| 后台启动带引号参数的程序 exit 0 但无输出 | 参数被吞（如 sqlcmd 退化为交互模式） | 把命令包进 CRLF 换行的 .bat 再启动 |
| 计划任务启动但新实例不运行/日志不写 | 旧实例挂起占坑（IgnoreNew 策略） | schtasks /end + taskkill 僵尸 cmd/conhost，再重跑 |
| 远程连接测试报"未发现数据源名称"（2008 R2 服务器） | 服务器未装 Native Client 11.0 | 改用内置 {SQL Server} 驱动 |
| 建 VU/启动 VU 极慢（每个连接 20-35 秒，2008 R2） | RTM 多核 bug | 安装 SP3（10.50.6000+），见阶段 1.5 |
| 测试运行时间远超设定时长 | timed 模式每 VU 各自计时 | 属正常现象，检查 VU 启动进度（见阶段 6） |
| checkschema 通过但按姓氏查客户失败 | cust_last 缺失 | 用 sys.procedures 核验 6 个 SP（见阶段 3） |
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
| `scripts/hdb_run.bat` | Windows GBK 代码页崩溃修复（Win10+）：在 UTF-8 控制台下运行 hammerdbcli |
| `scripts/dbcc_check.bat` | DBCC CHECKDB 包装（sqlcmd -o 捕获，避免输出被吞） |
| `scripts/create_cust_last.sql` | 补建 cust_last 存储过程（2008 R2 / 2014 建库已知问题修复） |
| `scripts/prepare_tcl_library.ps1` | 推荐：解包内嵌 Tcl 库 + 注入 UTF-8（TCL_LIBRARY 方案，全 Windows 版本通用） |

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
| `__DELAY_MS__` | 操作间隔(ms) | `300` |
| `__RAMPUP__` | 预热时间(分钟) | `2` |
| `__DURATION__` | 测试时长(分钟) | `120` |
