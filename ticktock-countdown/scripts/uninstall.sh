#!/bin/bash
# ===== TickTock 倒计时：停止并移除开机自启（保留源码与配置，重装即恢复）=====
UID_NUM=$(id -u)
PLIST="$HOME/Library/LaunchAgents/com.ari.ticktock.plist"
launchctl bootout "gui/$UID_NUM" "$PLIST" 2>/dev/null || true
rm -f "$PLIST"
pkill -f "TickTock" 2>/dev/null || true
sleep 1
if pgrep -lf TickTock >/dev/null; then
  echo "❌ 进程仍在，手动 kill: $(pgrep -lf TickTock)"
else
  echo "✅ 已停止并移除自启（配置在 ~/Library/Application Support/TickTock/ 未动）"
fi
