---
name: macos-sticky-note
description: "用 swiftc（Xcode CLT，无需 Xcode/brew）写 macOS 原生桌面便利贴/无边框常驻小窗：AppKit 无边框浮动窗口、折叠展开、定时读文件联动刷新，LaunchAgent 部署成开机自启、崩溃自愈、与 Hermes 生命周期解耦。当用户要『便利贴/一直 pin 在桌面/小组件式常驻』而 Obsidian 等普通窗口置顶不满足时使用。"
version: 1.0.0
author: Hermes Agent
platforms: [macos]
metadata:
  hermes:
    tags: [macos, swift, appkit, launchagent, desktop-widget, sticky-note]
    related_skills: [obsidian-vault-automation, hermes-cron]
---

# macOS 原生桌面便利贴 / 常驻小窗（swiftc + AppKit + LaunchAgent）

## 何时用（先确认形态，别做错方向）

用户说"固定在桌面 / pin 住 / 像便利贴"时，先分清两种体验：
- **窗口级置顶** = 完整应用窗口浮在最上层 —— Obsidian 的 always-on-top 只能给这个。实测用户不接受："好像只是弹出对话框"。
- **桌面便利贴** = 无边框、圆角、小卡片，常驻屏幕角落、不抢焦点、内容自动同步 —— 用户说的"便利贴一样一直显示在桌面"是这个。Obsidian/任何普通窗口 app 都做不到，要原生小窗。

用户明确要便利贴体验后，首选本方案（本机已验证）：`swiftc`（Xcode CommandLineTools 自带，无需装 Xcode/brew/node）+ AppKit 纯代码 + LaunchAgent 常驻。不引第三方（无 brew 时 Übersicht/Plash 安装繁琐；Plash 还要付费）。

实例（2026-09，Ariana 的英语学习便签）：`/Users/didi/Library/Application Support/LearningSticky/LearningSticky`（二进制），LaunchAgent `~/Library/LaunchAgents/com.ari.learning-sticky.plist`，读 `/Users/didi/Desktop/语言准备/今日学习.md` 每 30s 刷新。源码模板：本技能 `templates/main.swift`（含折叠/展开完整版，直接改路径/文案即可复用）。

## 交付流程

1. **源码**：从 `templates/main.swift` 复制修改（文件路径常量、窗口宽高、标题文案、markdown 渲染规则）。
2. **编译**：
   ```bash
   mkdir -p "/Users/didi/Library/Application Support/<AppName>"
   swiftc -O -o "/Users/didi/Library/Application Support/<AppName>/<Binary>" /tmp/main.swift -framework Cocoa
   ```
   ⚠️ 顶层代码（`NSApplication.shared` + `app.run()`）所在文件**必须命名 main.swift**，否则 swiftc 报错。
3. **部署 LaunchAgent**（独立常驻 + 开机自启 + 崩溃自愈，Hermes 退出不影响）：
   ```xml
   <!-- ~/Library/LaunchAgents/com.<name>.plist -->
   <key>Label</key><string>com.ari.learning-sticky</string>
   <key>ProgramArguments</key><array><string>/abs/path/to/Binary</string></array>
   <key>RunAtLoad</key><true/>
   <key>KeepAlive</key><true/>
   <key>StandardOutPath</key><string>/tmp/app.log</string>
   <key>StandardErrorPath</key><string>/tmp/app.err.log</string>
   ```
   ```bash
   UID_NUM=$(id -u)
   launchctl bootout "gui/$UID_NUM" ~/Library/LaunchAgents/com.<name>.plist 2>/dev/null  # 幂等：先卸旧的
   launchctl bootstrap "gui/$UID_NUM" ~/Library/LaunchAgents/com.<name>.plist
   ```
4. **真验证**（沿用"别自嗨"纪律）：`pgrep -lf <Binary>` 确认进程存活 + `cat /tmp/app.err.log` 无报错，再告诉用户"已上线，看屏幕右上角"。

## 迭代改版（用户会频繁加功能）

改源码 → 重新 `swiftc`（输出覆盖同一路径）→ **bootout + bootstrap 重启**（或直接 `kill <pid>`，KeepAlive 会自动拉起新二进制——launchd 重启的是已替换的新文件）→ pgrep + err.log 验证。改完要明确告诉用户新交互是什么、让他试哪些动作。

## 关键技术点（模板里都已实现，改时别破坏）

- **无边框便签卡片**：`NSWindow(styleMask: [.borderless])` + `isOpaque=false` + `backgroundColor=.clear`；卡片是 contentView 上的圆角 layer 视图（`cornerRadius` + 半透明米黄底 + 细边框 + `hasShadow`）。
- **浮动常驻**：`window.level = .floating`（浮在普通窗口上）；`collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`（全屏/切 Space 都跟着）；`orderFrontRegardless()` 强制显示（accessory app 不 activate 也能显示）。
- **不占 Dock**：`app.setActivationPolicy(.accessory)`；退出只能靠自建入口（右键菜单"退出"）。
- **拖动**：无边框窗口 `isMovableByWindowBackground` 无效 → contentView 自定义 NSView 子类，`mouseDown` 里 `win?.performDrag(with: event)`；`clickCount == 2` 时触发双击 toggle（折叠/展开）。
- **右键菜单**：把 NSMenu 同时赋给卡片容器和 textView（textView 默认会弹编辑菜单，需覆盖）。
- **内容渲染**：NSTextView（`isEditable=false, drawsBackground=false`）按行解析 md 子集：`## `→粗体标题、`- [ ]`→"☐ "、`- [x]`→"☑ "+删除线、`🔑`→强调色、其余正文；emoji 直接显示。中英混排无问题。
- **点击打勾（双向写回文件，用户要"便签上能打勾+取消+两边联动"时加）**：把 "☐/☑ " 前缀做成 `NSLinkAttributeName` 链接（值 `check://行号`，行号=该行在 md 里的索引）；`textView.linkTextAttributes = [.underlineStyle: 0, .cursor: NSCursor.pointingHand]`（去下划线、留手型光标）；AppDelegate 遵循 `NSTextViewDelegate`，实现 `textView(_:clickedOnLink:at:)` 解析行号 → 读文件 → 翻转该行 → 原子写回 → 重渲染。Obsidian 检测到文件变化自动刷新，即"便签勾 ↔ Obsidian 勾"双向同步。
  ⚠️ **格式坑（踩过）**：写回必须是 `- [x] `（x 后带空格）或 `- [ ] `，Obsidian 才认 checkbox；曾因 `"- [x]" + dropFirst(6)` 少拼空格写成 `- [x]1.` 导致 Obsidian 不认、且后续无法取消。正确姿势：宽容解析（`- [` 后允许 ` ` / `x` / `X`，`]` 后吞掉任意空格再取内容）+ 统一规范输出。
- **一键重置**：右键菜单加"♻️ 重置全部勾选"，把所有 checkbox 行恢复为 `- [ ] `（防手滑全勾完想重来）。
- **文件联动刷新**：`Timer` + `RunLoop.main.add(timer, forMode: .common)`（默认 mode 在拖窗/菜单时不触发），每 30s 重读目标文件。Obsidian/cron 写文件 → 便签自动同步，无需任何 IPC。
- **折叠/展开**：右上角圆钮（chevron.up/down SF Symbol）+ 双击切换；动画 `NSAnimationContext.runAnimationGroup { window.animator().setFrame(target) }`（0.18s），**动画开始先隐藏所有子视图、完成回调里再 layout**（否则拉伸错位）；折叠条高度 ~48px 顶部对齐展开（`y: f.maxY - 高`），展开/折叠目标都要 `clampToScreen`（visibleFrame 内，防拖到屏幕底后展开飞出屏）。
- **子视图布局**：窗口尺寸变化后手动 layout（expanded/collapsed 两个布局函数），别依赖 autoresizing。

## 用户协作偏好（Ariana）

- 中文沟通；技术概念先大白话。
- **交付节奏**：小步迭代、每步真验证后再报喜；她明确骂过"别自嗨了行吗"——命令 exit 0 ≠ 成功，GUI 效果要回读 ground truth（进程/日志/文件）或让她肉眼确认。演示类操作（如"19:18 跑一次看看"）用后台定时任务到点执行 + notify，注意彩排不要动正式状态（进度文件）。
- 新交互给"操作 → 效果"对照表让她试（点按钮、双击、拖动、右键）。

## 支持文件

- `templates/main.swift` — 完整可用源码（折叠/展开 + 点击 ☐/☑ 双向打勾写回 + 一键重置全部勾选，2026-09 实测编译运行）。改 `kFilePath`/标题/尺寸即可复用于其它常驻内容（倒计时、待办、日报等）。
