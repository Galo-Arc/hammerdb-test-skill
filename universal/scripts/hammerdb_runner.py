#!/usr/bin/env python3
"""
HammerDB TPC-C Test Runner
适用于任何 AI Agent 平台的 Python 封装

用法：
    python hammerdb_runner.py --action build --ip youripaddress --password yourpassword
    python hammerdb_runner.py --action test --ip youripaddress --password yourpassword --vu 1000 --duration 120
    python hammerdb_runner.py --action check --ip youripaddress --password yourpassword
    python hammerdb_runner.py --action delete --ip youripaddress --password yourpassword
"""

import argparse
import os
import subprocess
import sys
import re
from pathlib import Path

HAMMERDB_PATH = r"C:\Program Files\HammerDB-6.0\hammerdbcli.exe"
BCP_PATH = r"C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\180\Tools\Binn"

# 默认配置
DEFAULTS = {
    "port": "1433",
    "odbc_driver": "ODBC Driver 17 for SQL Server",
    "warehouses": "10",
    "build_vus": "1",
    "use_bcp": "false",
    "vu_count": "50",
    "delay_ms": "300",
    "rampup": "2",
    "duration": "10",
}

TCL_TEMPLATE = """#!/bin/tclsh
puts "=== {title} ==="
dbset db mssqls
dbset bm TPC-C
diset connection mssqls_server {ip}
diset connection mssqls_linux_server {ip}
diset connection mssqls_port {port}
diset connection mssqls_tcp true
diset connection mssqls_authentication sql
diset connection mssqls_uid {user}
diset connection mssqls_pass {password}
diset connection mssqls_odbc_driver {{{odbc_driver}}}
diset connection mssqls_encrypt_connection false
diset connection mssqls_trust_server_cert true
{extra_config}
puts "CONFIG DONE"
{commands}
"""


def check_environment():
    """检查环境是否就绪"""
    issues = []

    if not os.path.exists(HAMMERDB_PATH):
        issues.append("HammerDB 未安装，请从 https://www.hammerdb.com 下载")

    if not os.path.exists(os.path.join(BCP_PATH, "bcp.exe")):
        issues.append("bcp 工具未安装，请安装 SQL Server Command Line Utilities")
    else:
        # 检查 bcp 是否在 PATH 中
        try:
            subprocess.run(["bcp", "-v"], capture_output=True, check=True)
        except (subprocess.CalledProcessError, FileNotFoundError):
            issues.append(f"bcp 不在 PATH 中，请添加: {BCP_PATH}")

    # 检查 ODBC 驱动
    try:
        result = subprocess.run(
            ["reg", "query", r"HKLM\SOFTWARE\ODBC\ODBCINST.INI"],
            capture_output=True, text=True
        )
        if "ODBC Driver 17" not in result.stdout and "ODBC Driver 18" not in result.stdout:
            issues.append("未找到 ODBC Driver 17 或 18")
    except Exception:
        issues.append("无法检查 ODBC 驱动")

    return issues


def generate_tcl(action, ip, password, user="sa", **kwargs):
    """生成 Tcl 脚本"""
    port = kwargs.get("port", DEFAULTS["port"])
    odbc_driver = kwargs.get("odbc_driver", DEFAULTS["odbc_driver"])

    if action == "test_connection":
        title = f"Testing connection to {ip}"
        extra_config = "diset tpcc mssqls_dbase tpcc"
        commands = "checkschema\nputs \"=== DONE ===\""

    elif action == "build":
        title = f"Building TPC-C Schema on {ip}"
        warehouses = kwargs.get("warehouses", DEFAULTS["warehouses"])
        build_vus = kwargs.get("build_vus", DEFAULTS["build_vus"])
        use_bcp = kwargs.get("use_bcp", DEFAULTS["use_bcp"])
        extra_config = f"""diset tpcc mssqls_count_ware {warehouses}
diset tpcc mssqls_num_vu {build_vus}
diset tpcc mssqls_dbase tpcc
diset tpcc mssqls_imdb false
diset tpcc mssqls_use_bcp {use_bcp}"""
        commands = """puts "START TIME: [clock format [clock seconds]]"
buildschema
puts "END TIME: [clock format [clock seconds]]"
puts "=== Schema Build Complete ===" """

    elif action == "delete":
        title = f"Deleting TPC-C Schema on {ip}"
        extra_config = "diset tpcc mssqls_dbase tpcc"
        commands = """deleteschema
puts "=== Delete Complete ===" """

    elif action == "check":
        title = f"Checking TPC-C Schema on {ip}"
        extra_config = "diset tpcc mssqls_dbase tpcc"
        commands = "checkschema\nputs \"=== DONE ===\""

    elif action == "test":
        title = f"TPC-C Test on {ip}"
        vu_count = kwargs.get("vu_count", DEFAULTS["vu_count"])
        delay_ms = kwargs.get("delay_ms", DEFAULTS["delay_ms"])
        rampup = kwargs.get("rampup", DEFAULTS["rampup"])
        duration = kwargs.get("duration", DEFAULTS["duration"])
        extra_config = """diset tpcc mssqls_dbase tpcc
diset tpcc mssqls_driver timed
diset tpcc mssqls_total_iterations 10000000
diset tpcc mssqls_rampup {rampup}
diset tpcc mssqls_duration {duration}
diset tpcc mssqls_checkpoint false
diset tpcc mssqls_timeprofile true
diset tpcc mssqls_allwarehouse true
diset tpcc mssqls_keyandthink true""".format(rampup=rampup, duration=duration)
        commands = """loadscript
puts "TEST STARTED"
puts "START TIME: [clock format [clock seconds]]"
vuset vu {vu}
vuset delay {delay}
vucreate
tcstart
tcstatus
set jobid [ vurun ]
vudestroy
tcstop
puts "END TIME: [clock format [clock seconds]]"
puts "TEST COMPLETE"
set of [ open $::env(TMP)/mssqls_tprocc_result w ]
puts $of $jobid
close $of""".format(vu=vu_count, delay=delay_ms)

    else:
        raise ValueError(f"Unknown action: {action}")

    return TCL_TEMPLATE.format(
        title=title,
        ip=ip,
        port=port,
        user=user,
        password=password,
        odbc_driver=odbc_driver,
        extra_config=extra_config,
        commands=commands,
    )


def run_hammerdb(tcl_script_path):
    """执行 HammerDB CLI"""
    env = os.environ.copy()
    env["PATH"] = env["PATH"] + ";" + BCP_PATH

    print(f"执行: {HAMMERDB_PATH} tcl auto {tcl_script_path}")

    process = subprocess.Popen(
        [HAMMERDB_PATH, "tcl", "auto", tcl_script_path],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
        text=True,
    )

    output_lines = []
    for line in process.stdout:
        line = line.strip()
        if line:
            print(f"  {line}")
            output_lines.append(line)

    process.wait()

    # 提取结果
    for line in output_lines:
        if "TEST RESULT" in line:
            match = re.search(r"achieved (\d+) NOPM from (\d+)", line)
            if match:
                print(f"\n{'='*50}")
                print(f"  NOPM: {match.group(1)}")
                print(f"  TPM:  {match.group(2)}")
                print(f"{'='*50}")

    return process.returncode, output_lines


def main():
    parser = argparse.ArgumentParser(description="HammerDB TPC-C Test Runner")
    parser.add_argument("--action", required=True,
                        choices=["check_env", "test_connection", "build", "check", "delete", "test"],
                        help="执行的操作")
    parser.add_argument("--ip", help="SQL Server IP 地址")
    parser.add_argument("--port", default=DEFAULTS["port"], help="SQL Server 端口")
    parser.add_argument("--user", default="sa", help="登录用户名")
    parser.add_argument("--password", help="登录密码")
    parser.add_argument("--odbc-driver", default=DEFAULTS["odbc_driver"], help="ODBC 驱动名称")
    parser.add_argument("--warehouses", default=DEFAULTS["warehouses"], help="Warehouse 数量")
    parser.add_argument("--build-vus", default=DEFAULTS["build_vus"], help="建库 VU 数")
    parser.add_argument("--use-bcp", default=DEFAULTS["use_bcp"], help="是否用 BCP 模式")
    parser.add_argument("--vu", default=DEFAULTS["vu_count"], help="并发连接数")
    parser.add_argument("--delay", default=DEFAULTS["delay_ms"], help="用户操作间隔(ms)")
    parser.add_argument("--rampup", default=DEFAULTS["rampup"], help="预热时间(分钟)")
    parser.add_argument("--duration", default=DEFAULTS["duration"], help="测试时长(分钟)")
    parser.add_argument("--dry-run", action="store_true", help="只生成脚本，不执行")

    args = parser.parse_args()

    # 检查环境
    if args.action == "check_env":
        issues = check_environment()
        if issues:
            print("环境检查发现问题：")
            for issue in issues:
                print(f"  ❌ {issue}")
            sys.exit(1)
        else:
            print("✅ 环境检查通过")
            sys.exit(0)

    # 其他操作需要 IP 和密码
    if not args.ip or not args.password:
        print("错误：--ip 和 --password 是必须的")
        sys.exit(1)

    # 生成 Tcl 脚本
    tcl_content = generate_tcl(
        action=args.action,
        ip=args.ip,
        password=args.password,
        user=args.user,
        port=args.port,
        odbc_driver=args.odbc_driver,
        warehouses=args.warehouses,
        build_vus=args.build_vus,
        use_bcp=args.use_bcp,
        vu_count=args.vu,
        delay_ms=args.delay,
        rampup=args.rampup,
        duration=args.duration,
    )

    # 写入临时文件
    tcl_path = os.path.join(os.environ.get("TEMP", "/tmp"), f"hammerdb_{args.action}.tcl")
    with open(tcl_path, "w") as f:
        f.write(tcl_content)

    print(f"脚本已生成: {tcl_path}")

    if args.dry_run:
        print("\n--- 脚本内容 ---")
        print(tcl_content)
        print("--- 脚本结束 ---")
        sys.exit(0)

    # 执行
    print(f"\n开始执行 {args.action}...")
    returncode, output = run_hammerdb(tcl_path)

    if returncode != 0:
        print(f"\n❌ 执行失败 (exit code: {returncode})")
        sys.exit(1)
    else:
        print(f"\n✅ {args.action} 执行完成")


if __name__ == "__main__":
    main()
