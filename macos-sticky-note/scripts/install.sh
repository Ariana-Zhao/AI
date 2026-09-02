#!/bin/bash
# ===== LearningSticky 学习便签：首次安装（拷贝 LaunchAgent + 启动）=====
set -e
SRCDIR="$(cd "$(dirname "$0")/.." && pwd)"
PLIST_SRC="$SRCDIR/LaunchAgent/com.ari.learning-sticky.plist"
PLIST="$HOME/Library/LaunchAgents/com.ari.learning-sticky.plist"

cp "$PLIST_SRC" "$PLIST"
UID_NUM=$(id -u)
launchctl bootout "gui/$UID_NUM" "$PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$UID_NUM" "$PLIST"
sleep 2
if pgrep -lf LearningSticky >/dev/null; then
  echo "✅ 安装完成，便签已启动（看屏幕右上角）"
else
  echo "⚠️ 进程未检测到，请检查 /tmp/learning-sticky.err.log"
fi
