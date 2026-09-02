#!/bin/bash
# ===== LearningSticky 学习便签：重新编译 + 重启 LaunchAgent =====
# 用法：改完 templates/main.swift 后运行本脚本，即改即生效
set -e
SRCDIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="/Users/didi/Library/Application Support/LearningSticky"
BIN_NAME="LearningSticky"
PLIST="$HOME/Library/LaunchAgents/com.ari.learning-sticky.plist"

echo "== 1/3 编译 =="
mkdir -p "$APP_DIR"
swiftc -O -o "$APP_DIR/$BIN_NAME" "$SRCDIR/templates/main.swift" -framework Cocoa
echo "✅ 编译完成: $APP_DIR/$BIN_NAME"

echo "== 2/3 重启 LaunchAgent =="
UID_NUM=$(id -u)
launchctl bootout "gui/$UID_NUM" "$PLIST" 2>/dev/null || true
sleep 1
launchctl bootstrap "gui/$UID_NUM" "$PLIST"
echo "✅ 已加载"

echo "== 3/3 真验证 =="
sleep 2
if pgrep -lf "$BIN_NAME" >/dev/null; then echo "✅ 进程存活"; else echo "❌ 进程未运行"; fi
if [ -f /tmp/learning-sticky.err.log ]; then
  ERR=$(head -5 /tmp/learning-sticky.err.log)
  [ -n "$ERR" ] && echo "⚠️ 错误日志: $ERR" || echo "✅ 无错误日志"
fi
