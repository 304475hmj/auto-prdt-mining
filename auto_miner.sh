#!/bin/bash
#
# auto_miner.sh — PRDT 自动挖矿签到一键脚本
#
# 使用前请在同目录下创建 wallets.txt，每行一个钱包私钥。

LOG_FILE="log.txt"
WALLETS_FILE="wallets.txt"
API_BASE="https://api.prdt.finance"
LOGIN_EP="/auth/login_with_key"
SIGN_EP="/mining/checkin"
POLL_INTERVAL=60  # 每 60 秒 检查一次是否可签到

install_deps(){
  echo "🚀 安装依赖..."
  apt update -y >/dev/null 2>&1
  apt install -y python3 python3-pip >/dev/null 2>&1
  pip3 install requests >/dev/null 2>&1
}

show_menu(){
  clear
  echo "====== PRDT 自动化工具 ======"
  echo "1) 批量签到挖矿"
  echo "2) 查看日志"
  echo "0) 退出"
  echo "============================"
  read -p "请选择: " cmd
  case $cmd in
    1) run_mining ;;
    2) show_log    ;;
    0) exit 0      ;;
    *) echo "❌ 无效选项"; sleep 1 ;;
  esac
}

show_log(){
  echo "📜 日志内容："
  cat "$LOG_FILE"
  read -p "按回车返回菜单..."
}

run_mining(){
  if [ ! -f "$WALLETS_FILE" ]; then
    echo "❌ 找不到 $WALLETS_FILE ，请先创建，每行一个私钥"
    read -p "按回车返回菜单..."
    return
  fi

  python3 - << 'PYCODE'
import time, requests, logging

API_BASE = "https://api.prdt.finance"
LOGIN_EP = "/auth/login_with_key"
SIGN_EP  = "/mining/checkin"

logging.basicConfig(
    filename="log.txt",
    level=logging.INFO,
    format="%(asctime)s %(message)s",
    datefmt="%F %T"
)

with open("wallets.txt") as f:
    keys = [l.strip() for l in f if l.strip()]

print(f"🔑 共 {len(keys)} 个私钥，开始批量签到…")
logging.info(f"开始新一轮签到，共 {len(keys)} 个私钥")

for idx, key in enumerate(keys, 1):
    r = requests.post(API_BASE + LOGIN_EP, json={"privateKey": key})
    if r.status_code == 200 and r.json().get("code") == 200:
        token = r.json()["data"]["token"]
        s = requests.post(API_BASE + SIGN_EP, headers={"Authorization": token})
        if s.status_code == 200 and s.json().get("code") == 200:
            msg = f"[{idx}/{len(keys)}] ✅ 签到成功"
        else:
            msg = f"[{idx}/{len(keys)}] ❌ 签到失败"
    else:
        msg = f"[{idx}/{len(keys)}] ❌ 登录失败"
    print(msg)
    logging.info(msg)

print("⏳ 本轮完成，进入监控模式…")
while True:
    time.sleep(60)
    # 这里示例不断重试签到，可根据实际情况改为先检查接口能否签到
    for idx, key in enumerate(keys, 1):
        r = requests.post(API_BASE + LOGIN_EP, json={"privateKey": key})
        if r.status_code == 200 and r.json().get("code") == 200:
            token = r.json()["data"]["token"]
            s = requests.post(API_BASE + SIGN_EP, headers={"Authorization": token})
            if s.status_code == 200 and s.json().get("code") == 200:
                msg = f"[{idx}/{len(keys)}] ⏰ 新一轮签到成功"
                print(msg); logging.info(msg)
PYCODE

  read -p "一轮签到完毕，按回车返回菜单..."
}

# 主流程
install_deps
touch "$LOG_FILE"
while true; do show_menu; done
