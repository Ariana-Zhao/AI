import Cocoa

// ===== 语言准备 · 桌面学习便利贴（支持折叠 + 点击打勾，与 Obsidian 双向同步）=====
// 读取 Obsidian vault 的「今日学习.md」，以便签形式常驻桌面显示，定时自动刷新。
// 交互：点 ☐/☑ 打勾并写回文件；右上角按钮 / 双击卡片折叠展开；按住空白拖动；右键菜单。

let kFilePath = "/Users/didi/Desktop/语言准备/今日学习.md"
let kRefreshInterval: TimeInterval = 30
let kWidth: CGFloat = 390
let kExpandedHeight: CGFloat = 600
let kCollapsedHeight: CGFloat = 48
let kCheckLinkPrefix = "check://"

// 可拖拽容器（无边框窗口手动实现拖动，双击触发折叠/展开）
final class DragContainer: NSView {
    weak var win: NSWindow?
    var onDoubleClick: (() -> Void)?
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
            return
        }
        win?.performDrag(with: event)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSTextViewDelegate {
    var window: NSWindow!
    var card: DragContainer!
    var textView: NSTextView!
    var scroll: NSScrollView!
    var collapseBtn: NSButton!
    var headerLabel: NSTextField!
    var collapsedLabel: NSTextField!
    var isCollapsed = false
    var timer: Timer?

    // MARK: - 生命周期

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildWindow()
        reloadContent()
        let t = Timer(timeInterval: kRefreshInterval, repeats: true) { [weak self] _ in
            self?.reloadContent()
        }
        t.tolerance = 5
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    // MARK: - 构建

    func buildWindow() {
        let rect = NSRect(x: 0, y: 0, width: kWidth, height: kExpandedHeight)
        window = NSWindow(contentRect: rect, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        card = DragContainer(frame: rect)
        card.win = window
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor(calibratedRed: 1.0, green: 0.976, blue: 0.82, alpha: 0.97).cgColor
        card.layer?.cornerRadius = 16
        card.layer?.borderWidth = 0.5
        card.layer?.borderColor = NSColor(calibratedWhite: 0.0, alpha: 0.15).cgColor
        card.onDoubleClick = { [weak self] in self?.toggleCollapse() }

        // 内容滚动区
        scroll = NSScrollView(frame: .zero)
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false

        textView = NSTextView(frame: .zero)
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 2, height: 6)
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = self
        textView.linkTextAttributes = [
            .underlineStyle: 0,
            .cursor: NSCursor.pointingHand
        ]
        scroll.documentView = textView
        card.addSubview(scroll)

        // 展开态顶部小标题
        headerLabel = makeLabel("📌 语言准备 · 每日打卡（点 ☐ 打勾）", size: 11, color: NSColor(calibratedWhite: 0.5, alpha: 1))
        card.addSubview(headerLabel)

        // 折叠态小条文字
        collapsedLabel = makeLabel("📌 语言准备 · 今日学习（点右侧按钮或双击展开）", size: 12, color: NSColor(calibratedWhite: 0.3, alpha: 1))
        card.addSubview(collapsedLabel)

        // 折叠/展开按钮（右上角圆钮）
        collapseBtn = NSButton(frame: .zero)
        collapseBtn.isBordered = false
        collapseBtn.target = self
        collapseBtn.action = #selector(toggleCollapse)
        collapseBtn.wantsLayer = true
        collapseBtn.layer?.backgroundColor = NSColor(calibratedWhite: 0.0, alpha: 0.07).cgColor
        collapseBtn.layer?.cornerRadius = 14
        collapseBtn.imagePosition = .imageOnly
        collapseBtn.contentTintColor = NSColor(calibratedWhite: 0.35, alpha: 1)
        card.addSubview(collapseBtn)

        window.contentView = card

        // 右键菜单
        let menu = NSMenu()
        let refreshItem = NSMenuItem(title: "🔄 立即刷新", action: #selector(reloadContent), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        let toggleItem = NSMenuItem(title: "折叠/展开", action: #selector(toggleCollapse), keyEquivalent: "t")
        toggleItem.target = self
        menu.addItem(toggleItem)
        let resetItem = NSMenuItem(title: "♻️ 重置全部勾选", action: #selector(resetAllChecks), keyEquivalent: "R")
        resetItem.target = self
        menu.addItem(resetItem)
        let openItem = NSMenuItem(title: "📖 在 Obsidian 打开", action: #selector(openInObsidian), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)
        let quitItem = NSMenuItem(title: "退出便签", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        card.menu = menu
        textView.menu = menu

        // 初始位置：屏幕右上角
        if let vf = NSScreen.main?.visibleFrame {
            let initial = NSRect(x: vf.maxX - kWidth - 24, y: vf.maxY - kExpandedHeight - 24, width: kWidth, height: kExpandedHeight)
            window.setFrame(initial, display: true)
        }
        layoutExpanded()
        window.orderFrontRegardless()
    }

    func makeLabel(_ s: String, size: CGFloat, color: NSColor, bold: Bool = false) -> NSTextField {
        let l = NSTextField(labelWithString: s)
        l.font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        l.textColor = color
        l.isBezeled = false
        l.drawsBackground = false
        l.lineBreakMode = .byTruncatingTail
        return l
    }

    // MARK: - 布局

    func layoutExpanded() {
        let b = card.bounds
        headerLabel.isHidden = false
        collapsedLabel.isHidden = true
        scroll.isHidden = false
        headerLabel.frame = NSRect(x: 18, y: b.height - 34, width: b.width - 130, height: 20)
        collapseBtn.frame = NSRect(x: b.width - 40, y: b.height - 40, width: 28, height: 28)
        scroll.frame = NSRect(x: 16, y: 16, width: b.width - 32, height: b.height - 16 - 52)
        collapseBtn.image = NSImage(systemSymbolName: "chevron.up", accessibilityDescription: "折叠")
    }

    func layoutCollapsed() {
        let b = card.bounds
        headerLabel.isHidden = true
        scroll.isHidden = true
        collapsedLabel.isHidden = false
        collapsedLabel.frame = NSRect(x: 16, y: (b.height - 20) / 2, width: b.width - 90, height: 20)
        collapseBtn.frame = NSRect(x: b.width - 40, y: (b.height - 28) / 2, width: 28, height: 28)
        collapseBtn.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "展开")
    }

    // MARK: - 折叠/展开

    @objc func toggleCollapse() {
        isCollapsed.toggle()
        let f = window.frame
        if isCollapsed {
            headerLabel.isHidden = true
            scroll.isHidden = true
            collapsedLabel.isHidden = true
            let target = clampToScreen(NSRect(x: f.origin.x, y: f.maxY - kCollapsedHeight, width: f.width, height: kCollapsedHeight))
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.18
                self.window.animator().setFrame(target, display: true)
            }, completionHandler: { [weak self] in
                self?.layoutCollapsed()
            })
        } else {
            collapsedLabel.isHidden = true
            let target = clampToScreen(NSRect(x: f.origin.x, y: f.maxY - kExpandedHeight, width: f.width, height: kExpandedHeight))
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.18
                self.window.animator().setFrame(target, display: true)
            }, completionHandler: { [weak self] in
                self?.layoutExpanded()
            })
        }
    }

    func clampToScreen(_ r: NSRect) -> NSRect {
        guard let vf = NSScreen.main?.visibleFrame else { return r }
        let x = min(max(r.origin.x, vf.minX), max(vf.minX, vf.maxX - r.width))
        let y = min(max(r.origin.y, vf.minY), max(vf.minY, vf.maxY - r.height))
        return NSRect(x: x.isFinite ? x : vf.minX, y: y.isFinite ? y : vf.minY, width: r.width, height: r.height)
    }

    // MARK: - 打勾（点 ☐/☑ 写回文件）

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        guard let s = link as? String, s.hasPrefix(kCheckLinkPrefix) else { return false }
        guard let idx = Int(s.dropFirst(kCheckLinkPrefix.count)) else { return false }
        toggleLine(idx)
        return true
    }

    func toggleLine(_ idx: Int) {
        guard let data = FileManager.default.contents(atPath: kFilePath),
              let md = String(data: data, encoding: .utf8) else { return }
        var lines = md.components(separatedBy: "\n")
        guard idx >= 0 && idx < lines.count else { return }
        let line = lines[idx]
        // 宽容解析行首 checkbox（兼容缺空格的历史格式），输出统一规范格式
        guard line.hasPrefix("- [") else { return }
        let after = line.dropFirst(3)
        guard let first = after.first, first == " " || first == "x" || first == "X" else { return }
        let isDone = (first == "x" || first == "X")
        guard let closeIdx = line.firstIndex(of: "]") else { return }
        var restStart = line.index(after: closeIdx)
        while restStart < line.endIndex, line[restStart] == " " {
            restStart = line.index(after: restStart)
        }
        let rest = String(line[restStart...])
        lines[idx] = (isDone ? "- [ ] " : "- [x] ") + rest
        let out = lines.joined(separator: "\n")
        do {
            try out.write(toFile: kFilePath, atomically: true, encoding: .utf8)
        } catch {
            return
        }
        reloadContent()
    }

    // 一键重置：把全部勾选恢复为未完成（防手滑全勾完想重来）
    @objc func resetAllChecks() {
        guard let data = FileManager.default.contents(atPath: kFilePath),
              let md = String(data: data, encoding: .utf8) else { return }
        var lines = md.components(separatedBy: "\n")
        var changed = false
        for (i, line) in lines.enumerated() {
            guard line.hasPrefix("- [") else { continue }
            let after = line.dropFirst(3)
            guard let first = after.first, first == " " || first == "x" || first == "X" else { continue }
            guard let closeIdx = line.firstIndex(of: "]") else { continue }
            var restStart = line.index(after: closeIdx)
            while restStart < line.endIndex, line[restStart] == " " {
                restStart = line.index(after: restStart)
            }
            let rest = String(line[restStart...])
            let newLine = "- [ ] " + rest
            if newLine != line {
                lines[i] = newLine
                changed = true
            }
        }
        guard changed else { return }
        do {
            try lines.joined(separator: "\n").write(toFile: kFilePath, atomically: true, encoding: .utf8)
        } catch {
            return
        }
        reloadContent()
    }

    // MARK: - 内容渲染

    @objc func reloadContent() {
        guard let data = FileManager.default.contents(atPath: kFilePath),
              let md = String(data: data, encoding: .utf8) else {
            setPlaceholder("（尚未生成今日学习内容）\n\n等 cron 推送后会自动出现～")
            return
        }
        textView.textStorage?.setAttributedString(render(markdown: md))
    }

    func setPlaceholder(_ s: String) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor(calibratedWhite: 0.4, alpha: 1)
        ]
        textView.textStorage?.setAttributedString(NSAttributedString(string: s, attributes: attrs))
    }

    func render(markdown: String) -> NSAttributedString {
        let out = NSMutableAttributedString()
        let dark = NSColor(calibratedWhite: 0.22, alpha: 1)
        let doneGray = NSColor(calibratedWhite: 0.55, alpha: 1)
        let accent = NSColor(calibratedRed: 0.72, green: 0.45, blue: 0.05, alpha: 1)
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 3
        para.paragraphSpacing = 3

        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: dark,
            .paragraphStyle: para
        ]
        let doneAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: doneGray,
            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
            .paragraphStyle: para
        ]

        for (idx, rawLine) in markdown.components(separatedBy: "\n").enumerated() {
            if rawLine.hasPrefix("## ") {
                let title = String(rawLine.dropFirst(3))
                out.append(NSAttributedString(string: title + "\n", attributes: [
                    .font: NSFont.boldSystemFont(ofSize: 16),
                    .foregroundColor: dark,
                    .paragraphStyle: para
                ]))
            } else if rawLine.hasPrefix("- [x]") || rawLine.hasPrefix("- [X]") {
                let content = String(rawLine.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                let box = NSMutableAttributedString(string: "☑", attributes: [
                    .font: NSFont.systemFont(ofSize: 13),
                    .foregroundColor: doneGray,
                    .link: kCheckLinkPrefix + String(idx)
                ])
                out.append(box)
                out.append(NSAttributedString(string: " " + content + "\n", attributes: doneAttrs))
            } else if rawLine.hasPrefix("- [ ]") {
                let content = String(rawLine.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                let box = NSMutableAttributedString(string: "☐", attributes: [
                    .font: NSFont.systemFont(ofSize: 13),
                    .foregroundColor: dark,
                    .link: kCheckLinkPrefix + String(idx)
                ])
                out.append(box)
                out.append(NSAttributedString(string: " " + content + "\n", attributes: bodyAttrs))
            } else if rawLine.hasPrefix("🔑") {
                out.append(NSAttributedString(string: rawLine + "\n", attributes: [
                    .font: NSFont.boldSystemFont(ofSize: 13),
                    .foregroundColor: accent,
                    .paragraphStyle: para
                ]))
            } else if !rawLine.isEmpty {
                out.append(NSAttributedString(string: rawLine + "\n", attributes: bodyAttrs))
            }
        }
        return out
    }

    @objc func openInObsidian() {
        if let url = URL(string: "obsidian://open?vault=%E8%AF%AD%E8%A8%80%E5%87%86%E5%A4%87&file=%E4%BB%8A%E6%97%A5%E5%AD%A6%E4%B9%A0") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

// 入口（accessory：不占 Dock，纯桌面小工具）
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
