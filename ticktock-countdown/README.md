# ⏱ TickTock · macOS 原生倒计时小窗（Skill 包）

抢票 / 秒杀 / 重要时刻倒计时：毫秒级刷新、到点前 10 分钟自动弹出并打开链接、平时隐藏、⌥⌘T 随手唤起。
纯 `swiftc` + AppKit 单文件编译，无需 Xcode / brew / 第三方依赖，LaunchAgent 开机自启 + 崩溃自愈。

本目录是完整可迁移的 skill 包（Hermes 技能 `macos/ticktock-countdown` 的镜像副本）。

## 功能一览

| 操作 | 效果 |
| --- | --- |
| ⌥⌘T（全局热键） | 显示 / 隐藏窗口，任何 App 里都可用 |
| 单击卡片 | 折叠（小时钟条）↔ 展开（完整倒计时面板） |
| 双击卡片 | 设定抢票时间（必填）+ 抢票链接（选填） |
| 右键卡片 | 设定 / 清除 / 隐藏 / 退出 |
| 剩 10 分钟 | 自动浮现 + 展开 + 默认浏览器打开链接（每目标仅一次） |
| 归零 | 🎉 时间到，已开抢！（变绿） |

时间格式很宽容：`20:00` / `10:00:00` / `9-20 10:00` / `2026-9-20 10:00:00.500` / `2026年9月20日 10:00`，没写日期默认今天（过点顺延明天），没写年份默认今年（过点滚到明年）。

## 目录结构

| 文件 | 说明 |
| --- | --- |
| `SKILL.md` | Skill 定义与完整操作手册（与 Hermes 内同步） |
| `templates/main.swift` | 完整源码（517 行单文件，实测编译运行） |
| `scripts/build-and-restart.sh` | 改完源码 → 编译 + 重启（日常迭代） |
| `scripts/install.sh` | 首次安装（编译 + LaunchAgent + 启动） |
| `scripts/uninstall.sh` | 停止并移除开机自启 |
| `LaunchAgent/com.ari.ticktock.plist` | 开机自启 + 崩溃自愈配置 |

## 快速上手

```bash
git clone https://github.com/Ariana-Zhao/AI.git
cd AI/ticktock-countdown
bash scripts/install.sh        # 首次安装
bash scripts/build-and-restart.sh   # 以后改源码迭代用这个
```

30 秒验收：⌥⌘T 唤出 → 双击设一个 11 分钟后的时间 + 任意链接 → 到 T-10 分钟看它自动弹出并打开浏览器 → 右键「清除设定」。

调试：`TICKTOCK_EXPANDED=*** 环境变量启动 = 启动即展开（截图/调试用）。配置文件在 `~/Library/Application Support/TickTock/config.txt`（第 1 行 unix 时间戳、第 2 行链接），改完 `pkill -f TickTock` 重启生效。
