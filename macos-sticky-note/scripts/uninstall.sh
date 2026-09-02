#!/bin/bash
# ===== LearningSticky 学习便签：卸载（停止进程 + 移除开机自启）=====
set -e
PLIST="$HOME/Library/LaunchAgents/com.ari.learning-sticky.plist"
UID_NUM=$(id -u)
launchctl bootout "gui/$UID_NUM" "$PLIST" 2>/dev/null || true
rm -f "$PLIST"
echo "✅ 已停止便签并移除开机自启"
echo "（二进制保留在 ~/Library/Application Support/LearningSticky/，如需彻底删除可手动移除）"
