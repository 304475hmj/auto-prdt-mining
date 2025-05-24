#!/bin/bash
# auto_miner.sh — PRDT 自动化签到+挖矿一键脚本

LOG_FILE="log.txt"
WALLETS_FILE="wallets.txt"
PYCODE="main.py"

show_menu(){
  clear
  echo "====== PRDT 自动化工具 ======"
  echo "1) 批量签到挖矿"
  echo "2) 查看日志"
  echo "3) 添加钱包"
  echo "0) 退出"
  echo "============================"
  read -p "请选择: " cmd
  case $cmd in
    1) run_mining ;;
    2) show_log ;;
    3) add_wallet ;;
    0) exit 0 ;;
    *) echo -e "\n❌ 无效选项"; sleep 1; show_menu ;;
  esac
}

show_log(){
  echo -e "\n📜 日志内容:"
  cat "$LOG_FILE"
  read -p "📘 按回车返回菜单..." _
  show_menu
}

add_wallet(){
  echo -e "\n🔐 请输入你的私钥 (留空回车返回):"
  read -p "> " privkey
  if [ -n "$privkey" ]; then
    echo "$privkey" >> "$WALLETS_FILE"
    echo "✅ 私钥已保存到 $WALLETS_FILE"
  else
    echo "⚠️ 未输入内容，返回菜单"
  fi
  sleep 1
  show_menu
}

run_mining(){
  if [ ! -f "$WALLETS_FILE" ]; then
    echo "❌ 找不到 $WALLETS_FILE ，请先创建，每行一个私钥"
    read -p "按回车返回菜单..." _
    show_menu
    return
  fi
  python3 "$PYCODE"
  show_menu
}

# 启动主菜单
show_menu
