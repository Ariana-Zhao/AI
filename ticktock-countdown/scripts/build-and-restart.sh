#!/bin/bash
# ===== TickTock 倒计时：重新编译 + 重启 LaunchAgent =====
# 用法：改完 templates/main.swift 后运行本脚本，即改即生效
set -e
SRCDIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$HOME/Library/Application Support/TickTock"
BIN_NAME="TickTock"
PLIST="$HOME/Library/LaunchAgents/com.ari.ticktock.plist"

echo "== 1/3 编译 =="
mkdir -p "$APP_DIR"
# ⚠️ 含顶层代码的源文件必须叫 main.swift，否则 swiftc 报错
swiftc -O -o "$APP_DIR/$BIN_NAME" "$SRCDIR/templates/main.swift" -framework Cocoa
echo "✅ 编译完成: $APP_DIR/$BIN_NAME"

# 真部署核验（防假部署）：时间戳 + 符号
ls -la "$APP_DIR/$BIN_NAME"
nm "$APP_DIR/$BIN_NAME" 2>/dev/null | grep -qi setupMainMenu && echo "✅ 符号核验通过 (setupMainMenu)" || echo "⚠️ 符号核验未命中，检查源码"

echo "== 2/3 重启 LaunchAgent =="
UID_NUM=$(id -u)
launchctl bootout "gui/$UID_NUM" "$PLIST" 2>/dev/null || true
sleep 1
launchctl bootstrap "gui/$UID_NUM" "$PLIST"
echo "✅ 已加载"

echo "== 3/3 真验证 =="
sleep 2
if pgrep -lf "$BIN_NAME" >/dev/null; then echo "✅ 进程存活"; else echo "❌ 进程未运行"; fi
if [ -f /tmp/ticktock.err.log ]; then
  ERR=$(grep -v IMKCFRunLoopWakeUpReliable /tmp/ticktock.err.log | tail -5)
  [ -n "$ERR" ] && echo "⚠️ 错误日志: $ERR" || echo "✅ 无错误日志（IMK 输入法噪音已过滤）"
fi
echo "提示：⌥⌘T 唤出窗口验收；调试可 TICKTOCK_EXPANDED=*** 启动即展开"
