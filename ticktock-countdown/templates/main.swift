import Cocoa
import Carbon

// MARK: - 常量
let collapsedW: CGFloat = 200, collapsedH: CGFloat = 56
let expandedW: CGFloat = 352, expandedH: CGFloat = 164

let kSupportDir = NSHomeDirectory() + "/Library/Application Support/TickTock"
let kConfigFile = kSupportDir + "/config.txt"   // 第1行=目标时间戳，第2行=链接
let kTargetFile = kSupportDir + "/target.txt"   // 旧版兼容

// 提前弹出/开链接的秒数（10 分钟）
let kPreOpenSeconds: TimeInterval = 600

// MARK: - 配置存取
func loadConfig() -> (Date?, String) {
    if let s = try? String(contentsOfFile: kConfigFile, encoding: .utf8) {
        let lines = s.components(separatedBy: "\n")
        var t: Date? = nil
        if let d = Double(lines[0].trimmingCharacters(in: .whitespacesAndNewlines)) {
            t = Date(timeIntervalSince1970: d)
        }
        let u = lines.count > 1 ? lines[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        return (t, u)
    }
    // 兼容旧版 target.txt
    if let s = try? String(contentsOfFile: kTargetFile, encoding: .utf8),
       let d = Double(s.trimmingCharacters(in: .whitespacesAndNewlines)) {
        return (Date(timeIntervalSince1970: d), "")
    }
    return (nil, "")
}

func saveConfig(_ t: Date?, _ u: String) {
    try? FileManager.default.createDirectory(atPath: kSupportDir, withIntermediateDirectories: true)
    let l0 = t.map { String(format: "%.3f", $0.timeIntervalSince1970) } ?? ""
    let content = l0 + "\n" + u + "\n"
    try? content.write(toFile: kConfigFile, atomically: true, encoding: .utf8)
}

func normalizeURL(_ s: String) -> URL? {
    var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !t.isEmpty else { return nil }
    t = t.components(separatedBy: .whitespaces).joined() // 去内部空格
    let low = t.lowercased()
    if !low.hasPrefix("http://") && !low.hasPrefix("https://") { t = "https://" + t }
    if let u = URL(string: t) { return u }
    if let enc = t.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
       let u = URL(string: enc) { return u }
    return nil
}

// 解析用户输入：支持 10:00:00 / 10:00 / 9-20 10:00 / 2026-9-20 10:00:00.500
func parseTarget(_ input: String) -> Date? {
    var s = input.trimmingCharacters(in: .whitespacesAndNewlines)
    s = s.replacingOccurrences(of: "：", with: ":")
    s = s.replacingOccurrences(of: "/", with: "-")
    s = s.replacingOccurrences(of: "年", with: "-")
    s = s.replacingOccurrences(of: "月", with: "-")
    s = s.replacingOccurrences(of: "日", with: " ")
    s = s.replacingOccurrences(of: "号", with: " ")
    guard !s.isEmpty else { return nil }

    let cal = Calendar.current
    let now = Date()
    var year: Int? = nil, month: Int? = nil, day: Int? = nil
    var hour = 0, minute = 0, second = 0, milli = 0
    var sawTime = false

    for token in s.split(separator: " ") {
        let tok = String(token)
        if tok.contains(":") {
            let pieces = tok.split(separator: ":").map(String.init)
            guard pieces.count >= 2, let h = Int(pieces[0]), let m = Int(pieces[1]) else { return nil }
            guard h >= 0, h <= 23, m >= 0, m <= 59 else { return nil }
            hour = h; minute = m; sawTime = true
            if pieces.count >= 3 {
                let secStr = pieces[2]
                if secStr.contains(".") {
                    let sp = secStr.split(separator: ".").map(String.init)
                    second = Int(sp[0]) ?? 0
                    if sp.count > 1 { milli = Int(String((sp[1] + "00").prefix(3))) ?? 0 }
                } else {
                    second = Int(secStr) ?? 0
                }
            }
            guard second >= 0, second <= 59 else { return nil }
        } else if tok.contains("-") {
            let pieces = tok.split(separator: "-").compactMap { Int($0) }
            if pieces.count == 3 { year = pieces[0]; month = pieces[1]; day = pieces[2] }
            else if pieces.count == 2 { month = pieces[0]; day = pieces[1] }
            else { return nil }
        } else {
            return nil
        }
    }
    guard sawTime else { return nil }

    if let mo = month, let d = day {
        var comps = DateComponents()
        comps.year = year ?? cal.component(.year, from: now)
        comps.month = mo; comps.day = d
        comps.hour = hour; comps.minute = minute; comps.second = second
        comps.nanosecond = milli * 1_000_000
        guard let date = cal.date(from: comps) else { return nil }
        if year == nil && date < now {
            comps.year = (comps.year ?? 0) + 1
            guard let next = cal.date(from: comps) else { return nil }
            return next
        }
        return date
    } else {
        let today = cal.startOfDay(for: now)
        guard let date = cal.date(bySettingHour: hour, minute: minute, second: second, of: today) else { return nil }
        let full = date.addingTimeInterval(Double(milli) / 1000.0)
        if full < now { return full.addingTimeInterval(86400) }
        return full
    }
}

// MARK: - 可拖动/可点击卡片
final class CardView: NSView {
    var onClick: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    private var downEvent: NSEvent?
    private var dragged = false

    override func mouseDown(with event: NSEvent) {
        downEvent = event
        dragged = false
        if event.clickCount == 2 { onDoubleClick?() }
    }
    override func mouseDragged(with event: NSEvent) {
        guard !dragged, let down = downEvent else { return }
        let dx = event.locationInWindow.x - down.locationInWindow.x
        let dy = event.locationInWindow.y - down.locationInWindow.y
        if dx * dx + dy * dy > 16 {
            dragged = true
            window?.performDrag(with: down)
        }
    }
    override func mouseUp(with event: NSEvent) {
        if !dragged && event.clickCount == 1 { onClick?() }
        downEvent = nil
        dragged = false
    }
}

// MARK: - 全局热键
fileprivate weak var tickApp: AppDelegate?
fileprivate var gHotKeyRef: EventHotKeyRef?

func hotkeyHandler(nextHandler: EventHandlerCallRef?, inEvent: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    DispatchQueue.main.async { tickApp?.toggleVisible() }
    return noErr
}

// MARK: - AppDelegate
final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var card: CardView!
    var colTime: NSTextField!
    var bigTime: NSTextField!
    var dateLabel: NSTextField!
    var targetLabel: NSTextField!
    var countdownLabel: NSTextField!
    var hintLabel: NSTextField!
    var expanded = false
    var target: Date? = nil
    var url: String = ""
    var firedFor: Double? = nil   // 已对哪个目标触发过"提前10分钟"动作
    var timer: Timer?
    var lastDayString = ""

    let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日 EEEE"
        return f
    }()
    let targetFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm:ss"
        return f
    }()
    let targetFmtYear: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日 HH:mm:ss"
        return f
    }()
    let inputFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    func makeLabel(_ size: CGFloat, _ weight: NSFont.Weight, mono: Bool, color: NSColor) -> NSTextField {
        let l = NSTextField(labelWithString: "")
        l.isBezeled = false
        l.drawsBackground = false
        l.isEditable = false
        l.isSelectable = false
        l.textColor = color
        l.font = mono
            ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
            : NSFont.systemFont(ofSize: size, weight: weight)
        return l
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()   // accessory app 没有菜单栏，必须手动装"编辑"菜单，否则 ⌘V/⌘C/⌘X/⌘A 在输入框里全部失效
        let (t0, u0) = loadConfig()
        target = t0
        url = u0
        // 启动时目标已过期 → 标记为已触发，避免重启后突然弹浏览器
        if let t = t0, t.timeIntervalSinceNow < 0 { firedFor = t.timeIntervalSince1970 }

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: collapsedW, height: collapsedH),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        card = CardView(frame: NSRect(x: 0, y: 0, width: collapsedW, height: collapsedH))
        card.wantsLayer = true
        card.layer?.cornerRadius = 14
        card.layer?.backgroundColor = NSColor(calibratedWhite: 0.10, alpha: 0.86).cgColor
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.18).cgColor
        window.contentView = card

        // 统一排版：信息行一律 14pt 浅灰白，只有倒计时高亮（24pt 粗体橙色）
        let infoColor = NSColor(calibratedWhite: 0.88, alpha: 1)
        colTime = makeLabel(21, .bold, mono: true, color: .white)
        colTime.alignment = .center
        bigTime = makeLabel(14, .regular, mono: true, color: infoColor)
        dateLabel = makeLabel(14, .regular, mono: false, color: infoColor)
        targetLabel = makeLabel(14, .regular, mono: false, color: infoColor)
        countdownLabel = makeLabel(24, .bold, mono: true, color: .systemOrange)
        hintLabel = makeLabel(14, .regular, mono: false, color: infoColor)

        let allLabels: [NSTextField] = [colTime, bigTime, dateLabel, targetLabel, countdownLabel, hintLabel]
        for v in allLabels {
            v.frame = NSRect(x: 18, y: 0, width: 100, height: 20)
            card.addSubview(v)
        }

        let menu = buildMenu()
        card.menu = menu
        for v in allLabels { v.menu = menu }

        card.onClick = { [weak self] in self?.setExpanded(!(self?.expanded ?? false)) }
        card.onDoubleClick = { [weak self] in self?.promptTarget() }

        // 默认位置：屏幕右侧（学习便签下方区域）；平时隐藏，⌥⌘T 唤出
        let sf = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let x = sf.maxX - collapsedW - 24
        let y = sf.maxY - collapsedH - 320
        window.setFrame(NSRect(x: x, y: y, width: collapsedW, height: collapsedH), display: true)

        // 默认隐藏，⌥⌘T 唤出；调试模式 TICKTOCK_EXPANDED=*** 启动即展开显示
        if ProcessInfo.processInfo.environment["TICKTOCK_EXPANDED"] == "1" {
            let f = window.frame
            window.setFrame(clampToScreen(NSRect(x: f.maxX - expandedW, y: f.maxY - expandedH, width: expandedW, height: expandedH)), display: true)
            expanded = true
            window.orderFrontRegardless()
        }
        // else: 窗口保持隐藏，热键唤起

        layout()
        tick()

        timer = Timer(timeInterval: 0.02, repeats: true) { [weak self] _ in self?.tick() }
        timer?.tolerance = 0.005
        if let t = timer { RunLoop.main.add(t, forMode: .common) }

        // 全局热键 ⌥⌘T 隐藏/唤回
        tickApp = self
        let hkID = EventHotKeyID(signature: OSType(0x5449434B), id: 1)
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_T), UInt32(cmdKey | optionKey), hkID,
            GetApplicationEventTarget(), 0, &gHotKeyRef
        )
        if status != noErr { NSLog("TickTock hotkey register failed: \(status)") }
        var et = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), hotkeyHandler, 1, &et, nil, nil)
    }

    // MARK: 主菜单（accessory app 必须手动装，否则 ⌘V/⌘C/⌘X/⌘A 在 NSAlert 输入框里失效）
    func setupMainMenu() {
        let mainMenu = NSMenu()
        // 第一个 item 是 App 菜单（占位，accessory app 不显示菜单栏，只为系统分发快捷键）
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(title: "TickTock")
        appMenu.addItem(withTitle: "Quit TickTock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        // Edit 菜单：让 ⌘V/⌘C/⌘X/⌘A 在文本框里生效
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        NSApp.mainMenu = mainMenu
    }

    // MARK: 菜单
    func buildMenu() -> NSMenu {
        let m = NSMenu()
        let items: [(String, Selector)] = [
            ("🎯 设定抢票时间 / 链接…", #selector(promptTarget)),
            ("🧹 清除设定", #selector(clearTarget)),
        ]
        for (title, sel) in items {
            let it = NSMenuItem(title: title, action: sel, keyEquivalent: "")
            it.target = self
            m.addItem(it)
        }
        m.addItem(NSMenuItem.separator())
        let hide = NSMenuItem(title: "👁 隐藏窗口 (⌥⌘T)", action: #selector(hideWindow), keyEquivalent: "")
        hide.target = self
        m.addItem(hide)
        let quit = NSMenuItem(title: "✕ 退出", action: #selector(quitApp), keyEquivalent: "")
        quit.target = self
        m.addItem(quit)
        return m
    }

    @objc func promptTarget() {
        let alert = NSAlert()
        alert.messageText = "设定抢票"
        alert.informativeText = "时间格式：20:00:00 / 9-20 10:00 / 2026-9-20 10:00:00（可带 .500 毫秒）\n链接选填：倒计时剩 10 分钟时自动弹出本窗口并打开链接"
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 112))
        let tl = NSTextField(labelWithString: "抢票时间")
        tl.frame = NSRect(x: 0, y: 90, width: 300, height: 16)
        let tf = NSTextField(frame: NSRect(x: 0, y: 64, width: 300, height: 24))
        tf.font = NSFont.systemFont(ofSize: 15)
        if let t = target { tf.stringValue = inputFmt.string(from: t) }
        else { tf.placeholderString = "例如 2026-9-20 10:00:00" }
        let ul = NSTextField(labelWithString: "抢票链接（选填）")
        ul.frame = NSRect(x: 0, y: 40, width: 300, height: 16)
        let uf = NSTextField(frame: NSRect(x: 0, y: 14, width: 300, height: 24))
        uf.font = NSFont.systemFont(ofSize: 15)
        uf.stringValue = url
        uf.placeholderString = "https://…（留空则只弹窗口）"
        container.addSubview(tl); container.addSubview(tf)
        container.addSubview(ul); container.addSubview(uf)
        alert.accessoryView = container
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")
        NSApp.activate(ignoringOtherApps: true)
        alert.window.initialFirstResponder = tf
        let resp = alert.runModal()
        guard resp == .alertFirstButtonReturn else { return }
        let timeStr = tf.stringValue.trimmingCharacters(in: .whitespaces)
        guard !timeStr.isEmpty else { return }
        guard let d = parseTarget(timeStr) else {
            let err = NSAlert()
            err.messageText = "没看懂这个时间"
            err.informativeText = "请输入类似 20:00:00 或 2026-9-20 10:00:00 的时间。"
            err.addButton(withTitle: "好")
            err.runModal()
            return
        }
        target = d
        url = uf.stringValue.trimmingCharacters(in: .whitespaces)
        firedFor = nil
        saveConfig(d, url)
        if !expanded { setExpanded(true) }
        tick()
    }

    @objc func clearTarget() {
        target = nil
        url = ""
        firedFor = nil
        saveConfig(nil, "")
        tick()
    }

    @objc func hideWindow() { window.orderOut(nil) }
    @objc func quitApp() { NSApp.terminate(nil) }

    func toggleVisible() {
        if window.isVisible { window.orderOut(nil) } else { window.orderFrontRegardless() }
    }

    // 剩 10 分钟：自动浮现 + 展开 + 打开链接
    func autoReveal() {
        if !expanded { setExpanded(true) }
        window.orderFrontRegardless()
        if let u = normalizeURL(url) {
            NSWorkspace.shared.open(u)
        }
    }

    // MARK: 展开/折叠
    func clampToScreen(_ r: NSRect) -> NSRect {
        let s = (window.screen ?? NSScreen.main)?.visibleFrame ?? r
        var f = r
        if f.maxX > s.maxX { f.origin.x = s.maxX - f.width }
        if f.minX < s.minX { f.origin.x = s.minX }
        if f.maxY > s.maxY { f.origin.y = s.maxY - f.height }
        if f.minY < s.minY { f.origin.y = s.minY }
        return f
    }

    func setExpanded(_ exp: Bool) {
        guard exp != expanded else { return }
        expanded = exp
        let f = window.frame
        let w = exp ? expandedW : collapsedW
        let h = exp ? expandedH : collapsedH
        let nf = clampToScreen(NSRect(x: f.maxX - w, y: f.maxY - h, width: w, height: h))
        for v in card.subviews { v.isHidden = true }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            self.window.animator().setFrame(nf, display: true)
        }, completionHandler: {
            self.layout()
            self.tick()
        })
    }

    func layout() {
        let b = card.bounds
        let detail: [NSTextField] = [bigTime, dateLabel, targetLabel, countdownLabel, hintLabel]
        if expanded {
            colTime.isHidden = true
            // 统一行高 18 / 间距 8，只有倒计时行加大加粗高亮
            let lineH: CGFloat = 18, bigH: CGFloat = 30, gap: CGFloat = 8
            var y = b.height - 14 - lineH
            bigTime.frame = NSRect(x: 18, y: y, width: b.width - 36, height: lineH)
            y -= lineH + gap
            dateLabel.frame = NSRect(x: 18, y: y, width: b.width - 36, height: lineH)
            y -= lineH + gap
            targetLabel.frame = NSRect(x: 18, y: y, width: b.width - 36, height: lineH)
            y -= bigH + gap
            countdownLabel.frame = NSRect(x: 18, y: y, width: b.width - 36, height: bigH)
            y -= lineH + gap
            hintLabel.frame = NSRect(x: 18, y: y, width: b.width - 36, height: lineH)
            for l in detail { l.isHidden = false }
        } else {
            for l in detail { l.isHidden = true }
            colTime.frame = NSRect(x: 0, y: (b.height - 30) / 2, width: b.width, height: 30)
            colTime.isHidden = false
        }
    }

    // MARK: 每帧刷新（50fps）
    func tick() {
        let now = Date()
        let c = Calendar.current.dateComponents([.hour, .minute, .second, .nanosecond], from: now)
        let hms = String(format: "%02d:%02d:%02d", c.hour ?? 0, c.minute ?? 0, c.second ?? 0)
        colTime.stringValue = "🕐 " + hms
        bigTime.stringValue = hms + String(format: ".%03d", (c.nanosecond ?? 0) / 1_000_000)

        let dayStr = dayFmt.string(from: now)
        if dayStr != lastDayString {
            lastDayString = dayStr
            dateLabel.stringValue = dayStr + " · 本机时间"
        }

        if let t = target {
            let df = t.timeIntervalSince(now)
            let ts = t.timeIntervalSince1970
            // 剩 10 分钟触发一次：自动浮现 + 打开链接
            if df >= 0, df <= kPreOpenSeconds, firedFor != ts {
                firedFor = ts
                autoReveal()
            }
            let thisYear = Calendar.current.component(.year, from: now)
            let tYear = Calendar.current.component(.year, from: t)
            let dateStr = tYear == thisYear ? targetFmt.string(from: t) : targetFmtYear.string(from: t)
            targetLabel.stringValue = "🎯 " + dateStr + (url.isEmpty ? "" : " · 🔗已设链接")
            if df <= 0 {
                countdownLabel.stringValue = "🎉 时间到，已开抢！"
                countdownLabel.textColor = .systemGreen
            } else {
                var r = df
                let days = Int(r / 86400); r -= Double(days) * 86400
                let hh = Int(r / 3600); r -= Double(hh) * 3600
                let mm = Int(r / 60); r -= Double(mm) * 60
                let ss = Int(r)
                let ms = Int((r - Double(ss)) * 1000)
                let body = String(format: "%02d:%02d:%02d.%03d", hh, mm, ss, ms)
                countdownLabel.stringValue = days > 0 ? "还剩 \(days)天 \(body)" : "还剩 \(body)"
                countdownLabel.textColor = df < 60 ? .systemRed : .systemOrange
            }
            hintLabel.stringValue = "剩10分钟自动弹出 · 双击改设定 · ⌥⌘T 隐藏"
        } else {
            targetLabel.stringValue = "🎯 目标：未设定"
            countdownLabel.stringValue = "未设定抢票目标"
            countdownLabel.textColor = .systemOrange
            hintLabel.stringValue = "双击设定时间和链接 · ⌥⌘T 隐藏"
        }
    }
}

// MARK: - 启动
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
