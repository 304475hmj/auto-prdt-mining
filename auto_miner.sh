#!/bin/bash

INSTALL_DIR="/root/PRDT"
MAIN_SCRIPT_URL="https://raw.githubusercontent.com/304475hmj/prdt-auto-script/main/main.py"
LOG_FILE="$INSTALL_DIR/run.log"

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit 1

# 下载主程序 main.py
wget -q -O main.py "$MAIN_SCRIPT_URL"
chmod +x main.py

function add_wallets() {
    echo "请输入钱包私钥，每行一个。输入完后按 Ctrl+D 保存："
    cat > wallets.txt
    echo "✅ 私钥已保存到 wallets.txt"
    sleep 1
}

function add_proxies() {
    echo "请输入代理地址，每行一个，例如 http://127.0.0.1:7890，输入完后按 Ctrl+D 保存："
    cat > proxies.txt
    echo "✅ 代理已保存到 proxies.txt"
    sleep 1
}

function run_main() {
    if [ ! -f wallets.txt ]; then
        echo "❌ 找不到 wallets.txt，请先添加钱包"
        read -rp "按回车返回菜单..." temp
        return
    fi
    echo "✅ 开始执行自动签到挖矿..."
    python3 main.py | tee -a "$LOG_FILE"
    read -rp "按回车返回菜单..." temp
}

function show_log() {
    echo "📜 日志内容如下："
    echo "==============================="
    tail -n 50 "$LOG_FILE"
    echo "==============================="
    read -rp "按回车返回菜单..." temp
}

while true; do
    clear
    echo "====== PRDT 自动化工具 ======"
    echo "1) 批量签到挖矿"
    echo "2) 查看日志"
    echo "3) 添加钱包"
    echo "4) 添加代理"
    echo "0) 退出"
    echo "============================"
    read -rp "请选择: " choice
    case $choice in
        1) run_main ;;
        2) show_log ;;
        3) add_wallets ;;
        4) add_proxies ;;
        0) exit ;;
        *) echo "❌ 无效选项" && sleep 1 ;;
    esac
done
