#!/bin/bash
# ===== TickTock 倒计时：首次安装（编译 + 拷贝 LaunchAgent + 启动）=====
set -e
SRCDIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$HOME/Library/Application Support/TickTock"
PLIST_SRC="$SRCDIR/LaunchAgent/com.ari.ticktock.plist"
PLIST="$HOME/Library/LaunchAgents/com.ari.ticktock.plist"

echo "== 1/3 编译 =="
mkdir -p "$APP_DIR"
swiftc -O -o "$APP_DIR/TickTock" "$SRCDIR/templates/main.swift" -framework Cocoa
echo "✅ $APP_DIR/TickTock"

echo "== 2/3 安装 LaunchAgent =="
mkdir -p "$HOME/Library/LaunchAgents"
cp "$PLIST_SRC" "$PLIST"
UID_NUM=$(id -u)
launchctl bootout "gui/$UID_NUM" "$PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$UID_NUM" "$PLIST"

echo "== 3/3 真验证 =="
sleep 2
if pgrep -lf TickTock >/dev/null; then
  echo "✅ 安装完成。窗口默认隐藏，按 ⌥⌘T 唤出；双击设定抢票时间和链接"
else
  echo "⚠️ 进程未检测到，请检查 /tmp/ticktock.err.log"
fi
