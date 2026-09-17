---
name: ticktock-countdown
description: "TickTock：swiftc + AppKit 写 macOS 原生浮动倒计时小窗（抢票/秒杀/重要时刻提醒）。毫秒级倒计时、灵活时间解析（20:00 / 9-20 10:00 / 2026-9-20 10:00:00.500 / 中文年月日）、剩 10 分钟自动浮现并打开链接、全局热键 ⌥⌘T 显隐、LaunchAgent 开机自启崩溃自愈。当用户要『倒计时/抢票提醒/到点自动打开网页』时使用。"
version: 1.0.0
author: Hermes Agent
platforms: [macos]
metadata:
  hermes:
    tags: [macos, swift, appkit, countdown, launchagent, desktop-widget, ticket-grabbing]
    related_skills: [macos-sticky-note, github-push-publish]
---

# TickTock · macOS 原生倒计时小窗（swiftc + AppKit + LaunchAgent）

## 何时用

用户要"倒计时 / 抢票 / 秒杀提醒 / 到某个时刻自动打开某个链接"。系统提醒事项/日历不够用（不醒目、不精确到秒、不会自动打开网页），第三方 App 也不必要（本机无 brew，App Store 的带广告或收费）——直接 swiftc 写原生小窗。与 `macos-sticky-note` 同一套技术栈（无边框浮动窗 + LaunchAgent 常驻），本技能叠加倒计时专属逻辑。

**已跑实例（2026-09，Ariana 的 Mac，实测验证）**：
- 源码/二进制/配置：`~/Library/Application Support/TickTock/`（main.swift、TickTock、config.txt）
- LaunchAgent：`~/Library/LaunchAgents/com.ari.ticktock.plist`（RunAtLoad + KeepAlive 崩溃自愈）
- 日志：/tmp/ticktock.log、/tmp/ticktock.err.log
- 完整源码模板：本技能 `templates/main.swift`（517 行单文件，直接可编译）

## 功能与交互（给用户的"操作 → 效果"表）

| 操作 | 效果 |
| --- | --- |
| 全局热键 ⌥⌘T | 显示/隐藏窗口（任何 App 里都可用；Carbon 热键，无需辅助功能权限） |
| 单击卡片 | 折叠 ↔ 展开（小时钟条 ↔ 完整倒计时面板） |
| 双击卡片 | 弹设定框：抢票时间（必填）+ 抢票链接（选填） |
| 右键卡片 | 菜单：设定时间/链接、清除设定、隐藏窗口、退出 |
| 倒计时到 T-10 分钟 | 自动浮现 + 展开 + 用默认浏览器打开设定链接（每目标只触发一次） |
| 倒计时归零 | 显示"🎉 时间到，已开抢！"变绿 |

视觉：折叠 = 200×56 小条只显示 🕐 HH:mm:ss；展开 = 352×164 深色面板（毫秒大时钟、日期星期、目标时间、橙色毫秒级倒计时——最后 1 分钟变红、提示行）。窗口 floating 常驻、跨 Space/全屏跟随、不占 Dock（accessory）。

## 配置文件格式

`~/Library/Application Support/TickTock/config.txt`，纯文本两行：
```
<unix 时间戳，可带毫秒，如 1789620300.000>
<链接 URL，可为空>
```
兼容旧版 `target.txt`（只有时间戳一行）。程序启动时读取；**agent 帮用户改配置后必须重启进程**（`pkill -f TickTock`，KeepAlive 自动拉起）才生效。测试完记得清掉假数据，防止误触发弹浏览器。

## 时间解析（parseTarget，改代码时别破坏）

用户口头报的格式全收：`10:00:00` / `10:00` / `9-20 10:00` / `2026-9-20 10:00:00.500`；全角冒号`：`、`/` 分隔、中文`年月日号`自动归一。规则：没写日期 = 今天（已过点自动顺延到明天）；没写年份 = 今年（已过点滚到明年）。解析失败返回 nil → UI 弹"没看懂这个时间"错误框，不写坏配置。

## 编译部署

一键脚本（镜像包 `scripts/`）：
```bash
bash scripts/build-and-restart.sh   # 改完源码：重编译 + 重启 LaunchAgent + 真验证
bash scripts/install.sh             # 首次安装（编译 + 装 LaunchAgent + 启动）
bash scripts/uninstall.sh           # 停止并移除自启
```
手动等价命令：
```bash
swiftc -O -o "$HOME/Library/Application Support/TickTock/TickTock" main.swift -framework Cocoa
# ⚠️ 含顶层代码的文件必须命名 main.swift，否则 swiftc 报错
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.ari.ticktock.plist 2>/dev/null
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.ari.ticktock.plist
pgrep -lf TickTock; tail /tmp/ticktock.err.log   # 真验证再报喜
```

## 关键技术点（倒计时专属；无边框窗通用技术见 macos-sticky-note）

- **50fps 倒计时**：Timer 0.02s + tolerance 0.005，且必须 `RunLoop.main.add(timer, forMode: .common)`——默认 mode 在拖窗/弹菜单期间不走表。
- **T-10 分钟自动触发（autoReveal）**：tick() 里判断 `剩余 ∈ [0, 600]` 且 `firedFor != 目标时间戳` → 展开 + orderFrontRegardless + NSWorkspace.open(url)，随即记录 firedFor 防止每帧重复触发。**启动时若目标已过期，立即置 firedFor = 该时间戳**——否则重启/崩溃拉起后会突然弹浏览器（实踩）。
- **URL 容错（normalizeURL）**：去内部空格、缺协议自动补 https://、URL(string:) 失败再 percent-encode 重试。
- **全局热键 ⌥⌘T**：Carbon `RegisterEventHotKey`（signature 0x5449434B "TICK"，无需辅助功能权限）；handler 是无捕获 C 回调，内部必须 `DispatchQueue.main.async` 再碰 UI；用顶层 `fileprivate weak var tickApp: AppDelegate?` 让 handler 够到 delegate；`EventTypeSpec` 必须写 `OSType(kEventClassKeyboard)`。
- **默认隐藏启动**：倒计时是"关键时刻才需要"的东西，平时藏起来热键唤起。调试/截图用环境变量 `TICKTOCK_EXPANDED=*** 启动即展开。
- **⚠️ accessory app 必须手动装主菜单，否则 ⌘V 失效**（最大坑，实踩）：`setActivationPolicy(.accessory)` 的程序没有主菜单，macOS 剪贴板快捷键靠 Edit 菜单分发——没菜单 = NSAlert 输入框里 ⌘V 无人接收，粘不进任何东西。**根因不是输入内容**（长 URL 带中文/特殊符号也只是普通文本），别被"链接太复杂"带偏。修复 = `setupMainMenu()`：App 菜单占位（第一项，系统约定）+ Edit 菜单 Cut/Copy/Paste/Select All（`NSText.cut/copy/paste/selectAll` selector 沿 responder 链自动转发到焦点输入框）。无焦点验证法：构造 ⌘V 的 NSEvent，对比装菜单前后 `NSApp.mainMenu?.performKeyEquivalent(with:)` 返回 false→true。
- **⚠️ 隐式解包属性进数组**：`var label: NSTextField!` 放进数组字面量被推断成 `[NSTextField?]`，后续 `.isHidden` 全报 optional 错；必须显式 `let allLabels: [NSTextField] = [...]`。
- **部署真验证三连**（防假部署，exit 0 ≠ 成功）：`ls -la` 看二进制时间戳刷新、`nm <binary> | grep <新函数名>` 确认符号编进去了、`strings <binary> | grep <新字符串>`；然后 `pkill` 旧进程让 KeepAlive 拉起新二进制。err.log 里 `IMKCFRunLoopWakeUpReliable` 是输入法噪音，无害别误判。

## 迭代流程

改 `templates/main.swift`（跑机上的 `~/Library/Application Support/TickTock/main.swift` 要保持同步）→ `bash scripts/build-and-restart.sh` → pgrep + err.log 真验证 → 给用户 30 秒亲手验收步骤：⌥⌘T 唤出 → 双击设一个 11 分钟后的时间 + 任意链接 → 看它 10 分钟线自动弹出并打开浏览器 → 右键清除设定。

## 支持文件

- `templates/main.swift` — 完整源码（517 行单文件，2026-09 实测编译运行）：折叠/展开、双击设定、灵活时间解析、T-10min 自动开链接、⌥⌘T 全局热键、右键菜单、LaunchAgent 常驻。改常量（尺寸/文案/kPreOpenSeconds）即可复用为其它倒计时场景。
- `scripts/build-and-restart.sh` — 改完源码：编译 + 重启 + 真验证（含 nm 符号核验）。
- `scripts/install.sh` — 首次安装（编译 + 装 LaunchAgent + 启动）。
- `scripts/uninstall.sh` — 停止并移除自启（保留配置）。
- `LaunchAgent/com.ari.ticktock.plist` — 开机自启 + KeepAlive 崩溃自愈。
- 本包同步发布在 GitHub：`Ariana-Zhao/AI` 仓库 `ticktock-countdown/` 目录（镜像副本，改动后记得同步 push，流程见技能 github-push-publish）。
