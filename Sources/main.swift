import Cocoa
import Foundation
import ServiceManagement

struct SessionIndexEntry: Decodable {
    let id: String
    let threadName: String?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case threadName = "thread_name"
        case updatedAt = "updated_at"
    }
}

struct ChatProcess: Decodable {
    let chatTitle: String?
    let command: String
    let conversationId: String
    let cwd: String?
    let osPid: Int?
    let processId: String?
    let startedAtMs: Double
    let updatedAtMs: Double?
}

struct RolloutSession {
    let id: String
    let title: String?
    let cwd: String?
    let path: String
    let threadSource: String?
    let updatedAt: Date
    let turnId: String?
    let turnStartedAt: Date?
    let turnCompletedAt: Date?
    let turnCompletionReason: String?
    let isTurnActive: Bool
    let hasTurnState: Bool
}

struct ThreadIndexEntry: Decodable {
    let id: String
    let rolloutPath: String
    let touchedAtMs: Double
    let title: String?
    let cwd: String?
    let threadSource: String?

    enum CodingKeys: String, CodingKey {
        case id
        case rolloutPath = "rollout_path"
        case touchedAtMs = "touched_at_ms"
        case title
        case cwd
        case threadSource = "thread_source"
    }
}

struct ActiveItem {
    let id: String
    let title: String
    let detail: String
    let pid: Int?
    let startedAt: Date?
    let completedAt: Date?
}

struct UsageSession: Codable {
    let dedupeKey: String
    let threadId: String
    let turnId: String?
    let sourceType: String
    let startedAt: Date
    let completedAt: Date
    let durationSeconds: Int
    let completionReason: String
    let observedFirstAt: Date
    let observedLastAt: Date
    let appVersion: String
}

struct DailyUsageRollup: Codable {
    var date: String
    var sourceType: String
    var sessionsCount: Int
    var totalDurationSeconds: Int
    var maxDurationSeconds: Int
}

struct UsageStore: Codable {
    var trackingStartedAt: Date
    var recordedKeys: [String]
    var sessions: [UsageSession]
    var dailyRollups: [DailyUsageRollup]
}

struct UsageStats {
    let turnsCompleted: Int
    let totalDurationSeconds: Int
    let averageDurationSeconds: Int
    let longestDurationSeconds: Int
    let trackingStartedAt: Date?
}

struct StatusSnapshot {
    enum Kind {
        case command
        case completed
        case running
        case idle
    }

    let kind: Kind
    let title: String
    let detail: String
    let startedAt: Date?
    let updatedAt: Date?
    let activeItems: [ActiveItem]
}

final class ConversationMenuPayload: NSObject {
    let id: String
    let clearsWhenOpened: Bool

    init(id: String, clearsWhenOpened: Bool) {
        self.id = id
        self.clearsWhenOpened = clearsWhenOpened
    }
}

final class StatusBarContentView: NSView {
    struct Segment {
        let title: String
        let item: ActiveItem?
        let completed: Bool
        let opensCodex: Bool
        let opensMenu: Bool
    }

    var icon: NSImage?
    var segments: [Segment] = []
    var font = NSFont.menuBarFont(ofSize: 12)
    var onSegmentClick: ((ActiveItem) -> Void)?
    var onOpenCodexClick: (() -> Void)?
    var onMenuClick: (() -> Void)?
    var onConversationMenuClick: (() -> Void)?

    private var hitRects: [(rect: NSRect, segment: Segment)] = []
    private let iconSize = NSSize(width: 18, height: 18)
    private let horizontalPadding: CGFloat = 5
    private let iconTextGap: CGFloat = 4
    private let segmentGap: CGFloat = 7
    private let dividerWidth: CGFloat = 1
    private let height: CGFloat = 22

    override var intrinsicContentSize: NSSize {
        NSSize(width: measuredWidth(), height: height)
    }

    func configure(icon: NSImage?, segments: [Segment], font: NSFont) {
        self.icon = icon
        self.segments = segments
        self.font = font
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    func updateIcon(_ icon: NSImage?) {
        self.icon = icon
        setNeedsDisplay(iconDrawRect().insetBy(dx: -1, dy: -1))
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        var x = horizontalPadding
        if let icon {
            icon.draw(in: iconDrawRect())
        }
        x += iconSize.width
        if !dirtyRect.intersects(textDrawBounds()) && !hitRects.isEmpty {
            return
        }

        hitRects.removeAll()

        if !segments.isEmpty {
            x += iconTextGap
        }

        for (index, segment) in segments.enumerated() {
            if index > 0 {
                NSColor.separatorColor.withAlphaComponent(0.9).setFill()
                let dividerRect = NSRect(
                    x: x,
                    y: (bounds.height - 14) / 2,
                    width: dividerWidth,
                    height: 14
                )
                dividerRect.fill()
                x += dividerWidth + segmentGap
            }

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: segment.completed ? NSColor.systemGreen : NSColor.labelColor
            ]
            let string = segment.title as NSString
            let size = string.size(withAttributes: attributes)
            let rect = NSRect(
                x: x,
                y: (bounds.height - ceil(size.height)) / 2,
                width: ceil(size.width),
                height: ceil(size.height)
            )
            string.draw(in: rect, withAttributes: attributes)

            hitRects.append((
                rect: rect.insetBy(dx: -segmentGap / 2, dy: -4),
                segment: segment
            ))
            x += ceil(size.width) + segmentGap
        }
    }

    override func mouseUp(with event: NSEvent) {
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            onMenuClick?()
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        if iconContains(point) {
            onMenuClick?()
            return
        }

        if let hit = hitRects.first(where: { $0.rect.contains(point) }) {
            if let item = hit.segment.item {
                onSegmentClick?(item)
            } else if hit.segment.opensCodex {
                onOpenCodexClick?()
            } else if hit.segment.opensMenu {
                onConversationMenuClick?()
            }
            return
        }

        onMenuClick?()
    }

    override func rightMouseUp(with event: NSEvent) {
        onMenuClick?()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    private func iconDrawRect() -> NSRect {
        NSRect(
            x: horizontalPadding,
            y: (bounds.height - iconSize.height) / 2,
            width: iconSize.width,
            height: iconSize.height
        )
    }

    private func textDrawBounds() -> NSRect {
        NSRect(
            x: horizontalPadding + iconSize.width,
            y: 0,
            width: max(0, bounds.width - horizontalPadding - iconSize.width),
            height: bounds.height
        )
    }

    private func measuredWidth() -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textWidth = segments.reduce(CGFloat(0)) { partial, segment in
            partial + ceil((segment.title as NSString).size(withAttributes: attributes).width)
        }
        let dividerTotal = CGFloat(max(0, segments.count - 1)) * (dividerWidth + segmentGap)
        let segmentSpacing = CGFloat(max(0, segments.count)) * segmentGap
        let textGap = segments.isEmpty ? 0 : iconTextGap
        return horizontalPadding * 2 + iconSize.width + textGap + textWidth + dividerTotal + segmentSpacing
    }

    func item(at point: NSPoint) -> ActiveItem? {
        hitRects.first(where: { $0.rect.contains(point) })?.segment.item
    }

    func iconContains(_ point: NSPoint) -> Bool {
        iconDrawRect().insetBy(dx: -4, dy: -4).contains(point)
    }
}

final class CodexStatusController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let statusBarView = StatusBarContentView(frame: NSRect(x: 0, y: 0, width: 26, height: 22))
    private let statusMenu = NSMenu()
    private let conversationMenu = NSMenu()
    private let home = FileManager.default.homeDirectoryForCurrentUser
    private let pollInterval: TimeInterval = 2.5
    private let displayInterval: TimeInterval = 1.0
    private let animationInterval: TimeInterval = 1.0 / 12.0
    private let recentWindow: TimeInterval = 10 * 60
    private let activeWriteWindow: TimeInterval = 10 * 60
    private let activeTurnStaleWindow: TimeInterval = 24 * 60 * 60
    private let completedFinishMinimum: TimeInterval = 5 * 60
    private let completedRetentionWindow: TimeInterval = 10
    private let staleCommandWindow: TimeInterval = 24 * 60 * 60
    private let textFont = NSFont.menuBarFont(ofSize: 12)
    private let activeColor = NSColor.systemGreen
    private let recentColor = NSColor.systemBlue
    private let idleColor = NSColor.secondaryLabelColor
    private let defaults = UserDefaults.standard
    private let stateQueue = DispatchQueue(label: "codex-status.state", qos: .utility)
    private let watchQueue = DispatchQueue(label: "codex-status.watch", qos: .utility)
    private var animationStartedAt = Date()
    private var completedAnimationStart: Date?
    private var lastCompletedIds = Set<String>()
    private var refreshInFlight = false
    private var pendingRefresh = false
    private var refreshWorkItem: DispatchWorkItem?
    private var fileWatchers: [DispatchSourceFileSystemObject] = []
    private var watcherFileDescriptors: [CInt] = []
    private var cachedCodexRunning = false
    private var lastCodexProcessCheck = Date.distantPast
    private var settingsWindow: NSWindow?
    private var lastRenderedIconKey = ""
    private var lastRenderedSegmentsKey = "<unset>"
    private var cachedStatusIcon: NSImage?
    private var cachedStatusIcons: [String: NSImage] = [:]
    private var rolloutSessionCache: [String: (contentUpdatedAt: Date, session: RolloutSession)] = [:]
    private lazy var templateLogo = Bundle.main.path(forResource: "codexTemplate", ofType: "png").flatMap(NSImage.init(contentsOfFile:))
    private lazy var startupLogo = Bundle.main.path(forResource: "codexStartupLogo", ofType: "png").flatMap(NSImage.init(contentsOfFile:))
    private lazy var outlineLogo = Bundle.main.path(forResource: "codexOutlineLogo", ofType: "svg").flatMap(NSImage.init(contentsOfFile:))

    private enum IconStyle: String {
        case outline
        case solid
        case codex
    }

    private enum UsageWindow: String {
        case sevenDays
        case thirtyDays
        case sixtyDays
        case all
    }

    private enum UsageSourceFilter: String {
        case all
        case main
        case subagent
    }

    private var maxMenuBarChats: Int {
        get {
            let value = defaults.integer(forKey: "maxMenuBarChats")
            return value > 0 ? value : 4
        }
        set {
            defaults.set(max(1, min(12, newValue)), forKey: "maxMenuBarChats")
            render()
        }
    }

    private var shimmerCycleSeconds: TimeInterval {
        get {
            let value = defaults.double(forKey: "shimmerCycleSeconds")
            if value > 0 {
                return value
            }

            let oldFrameValue = defaults.integer(forKey: "shimmerCycleFrames")
            if oldFrameValue > 0 {
                return max(1.5, min(6.0, TimeInterval(oldFrameValue) / 24.0))
            }

            return 2.5
        }
        set {
            defaults.set(max(1.5, min(6.0, newValue)), forKey: "shimmerCycleSeconds")
            cachedStatusIcons.removeAll(keepingCapacity: true)
            render()
        }
    }

    private var iconStyle: IconStyle {
        get {
            let raw = defaults.string(forKey: "iconStyle") ?? ""
            if raw == "filled" || raw == "startupLogo" { return .codex }
            if raw == "template" { return .solid }
            return IconStyle(rawValue: raw) ?? .outline
        }
        set {
            defaults.set(newValue.rawValue, forKey: "iconStyle")
            render()
        }
    }

    private var showTimerStrip: Bool {
        get {
            guard defaults.object(forKey: "showTimerStrip") != nil else { return true }
            return defaults.bool(forKey: "showTimerStrip")
        }
        set {
            defaults.set(newValue, forKey: "showTimerStrip")
            render()
        }
    }

    private var launchAtLogin: Bool {
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            }
            return defaults.bool(forKey: "launchAtLogin")
        }
        set {
            defaults.set(newValue, forKey: "launchAtLogin")
            if #available(macOS 13.0, *) {
                do {
                    if newValue {
                        if SMAppService.mainApp.status != .enabled {
                            try SMAppService.mainApp.register()
                        }
                    } else if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    NSLog("Codex Status launch-at-login update failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private var debugLoggingEnabled: Bool {
        defaults.bool(forKey: "debugLogging")
    }

    private var usageWindow: UsageWindow {
        get {
            UsageWindow(rawValue: defaults.string(forKey: "usageWindow") ?? "") ?? .thirtyDays
        }
        set {
            defaults.set(newValue.rawValue, forKey: "usageWindow")
        }
    }

    private var usageSourceFilter: UsageSourceFilter {
        get {
            UsageSourceFilter(rawValue: defaults.string(forKey: "usageSourceFilter") ?? "") ?? .all
        }
        set {
            defaults.set(newValue.rawValue, forKey: "usageSourceFilter")
        }
    }

    private var activeRolloutStartCache: [String: TimeInterval] {
        get { defaults.dictionary(forKey: "activeRolloutStartCache") as? [String: TimeInterval] ?? [:] }
        set { defaults.set(newValue, forKey: "activeRolloutStartCache") }
    }

    private var taskStartedAtCache: [String: TimeInterval] {
        get { defaults.dictionary(forKey: "taskStartedAtCache") as? [String: TimeInterval] ?? [:] }
        set { defaults.set(newValue, forKey: "taskStartedAtCache") }
    }

    private var timer: Timer?
    private var displayTimer: Timer?
    private var animationTimer: Timer?
    private var snapshot = StatusSnapshot(
        kind: .idle,
        title: "Codex",
        detail: "Idle",
        startedAt: nil,
        updatedAt: nil,
        activeItems: []
    )

    private var clearedCompletedIds: Set<String> {
        get { Set(defaults.stringArray(forKey: "clearedCompletedIds") ?? []) }
        set { defaults.set(Array(newValue), forKey: "clearedCompletedIds") }
    }

    private var sessionIndexPath: String {
        home.appendingPathComponent(".codex/session_index.jsonl").path
    }

    private var stateWalPath: String {
        home.appendingPathComponent(".codex/state_5.sqlite-wal").path
    }

    private var stateDatabasePath: String {
        home.appendingPathComponent(".codex/state_5.sqlite").path
    }

    private var chatProcessesPath: String {
        home.appendingPathComponent(".codex/process_manager/chat_processes.json").path
    }

    private var debugPath: String {
        home.appendingPathComponent(".codex/statusbar/codex-status-debug.json").path
    }

    private var applicationSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? home.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Codex Status", isDirectory: true)
    }

    private var usageStoreURL: URL {
        applicationSupportDirectory.appendingPathComponent("usage-store.json")
    }

    private var sessionsRoot: URL {
        home.appendingPathComponent(".codex/sessions")
    }

    override init() {
        super.init()
        NSApp.setActivationPolicy(.accessory)
        ensureUsageStoreExists()

        statusMenu.delegate = self
        statusBarView.onMenuClick = { [weak self] in self?.showStatusMenu() }
        statusBarView.onOpenCodexClick = { [weak self] in self?.openCodex() }
        statusBarView.onConversationMenuClick = { [weak self] in self?.showConversationMenu() }
        statusBarView.onSegmentClick = { [weak self] item in self?.openItem(item) }
        statusItem.view = statusBarView

        render()
        refresh()

        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        let displayTimer = Timer(timeInterval: displayInterval, repeats: true) { [weak self] _ in
            self?.render()
        }
        RunLoop.main.add(displayTimer, forMode: .common)
        self.displayTimer = displayTimer

        let animationTimer = Timer(timeInterval: animationInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.shouldAnimateIcon() {
                self.renderLogo()
            }
        }
        RunLoop.main.add(animationTimer, forMode: .common)
        self.animationTimer = animationTimer

        startFileWatchers()
    }

    deinit {
        fileWatchers.forEach { $0.cancel() }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let open = NSMenuItem(title: "Open Codex", action: #selector(openCodex), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        let settings = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Codex Status", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func openCodex() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Codex.app"))
        }
    }

    @objc private func openConversationFromMenu(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? ConversationMenuPayload else {
            openCodex()
            return
        }
        openConversation(id: payload.id)
        if payload.clearsWhenOpened {
            clearCompleted(id: payload.id)
        }
        refresh()
    }

    private func showStatusMenu() {
        menuNeedsUpdate(statusMenu)
        statusItem.popUpMenu(statusMenu)
    }

    private func showConversationMenu() {
        conversationMenu.removeAllItems()

        guard !snapshot.activeItems.isEmpty else {
            let item = NSMenuItem(title: "Open Codex", action: #selector(openCodex), keyEquivalent: "")
            item.target = self
            conversationMenu.addItem(item)
            statusItem.popUpMenu(conversationMenu)
            return
        }

        let headerTitle = snapshot.kind == .completed ? "Completed conversations" : "Active conversations"
        let header = NSMenuItem(title: headerTitle, action: nil, keyEquivalent: "")
        header.isEnabled = false
        conversationMenu.addItem(header)
        conversationMenu.addItem(.separator())

        for item in snapshot.activeItems {
            let elapsed: String
            if let startedAt = item.startedAt, let completedAt = item.completedAt {
                elapsed = " - \(formatDuration(from: startedAt, to: completedAt))"
            } else {
                elapsed = item.startedAt.map { " - \(formatElapsed(since: $0))" } ?? ""
            }

            let entry = NSMenuItem(
                title: "\(truncatedConversationTitle(item.title))\(elapsed)",
                action: #selector(openConversationFromMenu(_:)),
                keyEquivalent: ""
            )
            entry.target = self
            entry.representedObject = ConversationMenuPayload(
                id: item.id,
                clearsWhenOpened: item.completedAt != nil
            )
            conversationMenu.addItem(entry)
        }

        statusItem.popUpMenu(conversationMenu)
    }

    private func openItem(_ item: ActiveItem) {
        openConversation(id: item.id)
        if item.completedAt != nil {
            clearCompleted(id: item.id)
        }
        refresh()
    }

    private func openConversation(id: String) {
        var components = URLComponents()
        components.scheme = "codex"
        components.host = "threads"
        components.path = "/\(id)"

        if let url = components.url, NSWorkspace.shared.open(url) {
            return
        }

        openCodex()
    }

    private func clearCompleted(id: String) {
        var ids = clearedCompletedIds
        ids.insert(id)
        clearedCompletedIds = ids
    }

    @objc private func revealStateFiles() {
        NSWorkspace.shared.activateFileViewerSelecting([
            URL(fileURLWithPath: sessionIndexPath),
            URL(fileURLWithPath: chatProcessesPath)
        ].filter { FileManager.default.fileExists(atPath: $0.path) })
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func openSettings() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 650),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)

        let content = NSView(frame: window.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 680, height: 650))
        content.autoresizingMask = [.width, .height]
        content.appearance = NSAppearance(named: .darkAqua)
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor(red: 0.078, green: 0.078, blue: 0.078, alpha: 1).cgColor

        let primaryTextColor = NSColor(calibratedWhite: 0.88, alpha: 1)
        let secondaryTextColor = NSColor(calibratedWhite: 0.62, alpha: 1)

        func label(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor? = nil) -> NSTextField {
            let field = NSTextField(labelWithString: text)
            field.font = NSFont.systemFont(ofSize: size, weight: weight)
            field.textColor = color ?? primaryTextColor
            field.lineBreakMode = .byTruncatingTail
            return field
        }

        func makeGroup(_ frame: NSRect) -> NSView {
            let view = NSView(frame: frame)
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor(red: 0.125, green: 0.125, blue: 0.125, alpha: 1).cgColor
            view.layer?.cornerRadius = 8
            view.layer?.borderWidth = 1
            view.layer?.borderColor = NSColor.white.withAlphaComponent(0.075).cgColor
            return view
        }

        func addSeparator(to group: NSView, y: CGFloat) {
            let separator = NSView(frame: NSRect(x: 0, y: y, width: group.bounds.width, height: 1))
            separator.autoresizingMask = [.width]
            separator.wantsLayer = true
            separator.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.055).cgColor
            group.addSubview(separator)
        }

        func addRowText(to group: NSView, y: CGFloat, title: String, detail: String) {
            let titleField = label(title, size: 13, weight: .regular)
            titleField.frame = NSRect(x: 24, y: y + 37, width: 340, height: 18)
            group.addSubview(titleField)

            let detailField = label(detail, size: 12, weight: .regular, color: secondaryTextColor)
            detailField.frame = NSRect(x: 24, y: y + 15, width: 400, height: 18)
            group.addSubview(detailField)
        }

        func filterButton(_ title: String, tag: Int, frame: NSRect, action: Selector) -> NSButton {
            let button = NSButton(title: title, target: self, action: action)
            button.frame = frame
            button.tag = tag
            button.isBordered = false
            button.bezelStyle = .regularSquare
            button.alignment = .center
            button.setButtonType(.momentaryChange)
            return button
        }

        let statsSection = label("Activity", size: 14, weight: .semibold)
        statsSection.frame = NSRect(x: 44, y: 604, width: 200, height: 20)
        content.addSubview(statsSection)

        let dateFilters = [
            ("7D", 2200, NSRect(x: 478, y: 480, width: 28, height: 22)),
            ("30D", 2201, NSRect(x: 514, y: 480, width: 38, height: 22)),
            ("60D", 2202, NSRect(x: 560, y: 480, width: 38, height: 22)),
            ("All", 2203, NSRect(x: 606, y: 480, width: 30, height: 22))
        ]
        dateFilters.forEach { title, tag, frame in
            content.addSubview(filterButton(title, tag: tag, frame: frame, action: #selector(changeUsageWindow(_:))))
        }

        let sourceFilters = [
            ("All work", 2210, NSRect(x: 32, y: 480, width: 92, height: 22)),
            ("Main", 2211, NSRect(x: 122, y: 480, width: 58, height: 22)),
            ("Subagents", 2212, NSRect(x: 178, y: 480, width: 104, height: 22))
        ]
        sourceFilters.forEach { title, tag, frame in
            content.addSubview(filterButton(title, tag: tag, frame: frame, action: #selector(changeUsageSource(_:))))
        }

        let stats = usageStats(window: usageWindow, source: usageSourceFilter)
        let statsGroup = makeGroup(NSRect(x: 44, y: 510, width: 592, height: 72))
        content.addSubview(statsGroup)

        let statTitles = ["Turns completed", "Total active time", "Average duration", "Longest turn"]
        let statValues = [
            "\(stats.turnsCompleted)",
            formatDuration(seconds: stats.totalDurationSeconds),
            stats.turnsCompleted > 0 ? formatDuration(seconds: stats.averageDurationSeconds) : "0s",
            stats.turnsCompleted > 0 ? formatDuration(seconds: stats.longestDurationSeconds) : "0s"
        ]
        let statWidth: CGFloat = statsGroup.bounds.width / 4
        for index in 0..<4 {
            if index > 0 {
                let divider = NSView(frame: NSRect(x: statWidth * CGFloat(index), y: 15, width: 1, height: 36))
                divider.wantsLayer = true
                divider.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.055).cgColor
                statsGroup.addSubview(divider)
            }

            let value = label(statValues[index], size: 16, weight: .regular)
            value.alignment = .center
            value.font = NSFont.monospacedDigitSystemFont(ofSize: 16, weight: .regular)
            value.frame = NSRect(x: statWidth * CGFloat(index), y: 35, width: statWidth, height: 22)
            value.tag = 2100 + index
            statsGroup.addSubview(value)

            let title = label(statTitles[index], size: 12, weight: .regular, color: secondaryTextColor)
            title.alignment = .center
            title.frame = NSRect(x: statWidth * CGFloat(index), y: 14, width: statWidth, height: 18)
            statsGroup.addSubview(title)
        }
        updateSettingsFilterStyles(in: content)

        let menuSection = label("Menu bar", size: 14, weight: .semibold)
        menuSection.frame = NSRect(x: 44, y: 430, width: 200, height: 20)
        content.addSubview(menuSection)

        let menuGroup = makeGroup(NSRect(x: 44, y: 58, width: 592, height: 350))
        content.addSubview(menuGroup)
        addSeparator(to: menuGroup, y: 280)
        addSeparator(to: menuGroup, y: 210)
        addSeparator(to: menuGroup, y: 140)
        addSeparator(to: menuGroup, y: 70)

        addRowText(to: menuGroup, y: 280, title: "Launch at login", detail: "Open Codex Status automatically when you sign in.")

        let loginSwitch = NSSwitch(frame: NSRect(x: 530, y: 299, width: 34, height: 24))
        loginSwitch.state = launchAtLogin ? .on : .off
        loginSwitch.target = self
        loginSwitch.action = #selector(changeLaunchAtLogin(_:))
        menuGroup.addSubview(loginSwitch)

        addRowText(to: menuGroup, y: 210, title: "Show timer strip", detail: "Show elapsed chat timers next to the Codex icon.")

        let stripSwitch = NSSwitch(frame: NSRect(x: 530, y: 229, width: 34, height: 24))
        stripSwitch.state = showTimerStrip ? .on : .off
        stripSwitch.target = self
        stripSwitch.action = #selector(changeShowTimerStrip(_:))
        menuGroup.addSubview(stripSwitch)

        addRowText(to: menuGroup, y: 140, title: "Max visible timers", detail: "Collapse extra active chats into +N.")

        let maxStepper = NSStepper(frame: NSRect(x: 536, y: 159, width: 28, height: 24))
        maxStepper.minValue = 1
        maxStepper.maxValue = 12
        maxStepper.integerValue = maxMenuBarChats
        menuGroup.addSubview(maxStepper)

        let maxValue = NSTextField(labelWithString: "\(maxMenuBarChats)")
        maxValue.alignment = .right
        maxValue.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        maxValue.frame = NSRect(x: 488, y: 161, width: 38, height: 20)
        menuGroup.addSubview(maxValue)

        maxStepper.target = self
        maxStepper.action = #selector(changeMaxMenuBarChats(_:))
        maxStepper.tag = 1001
        maxValue.tag = 1002

        addRowText(to: menuGroup, y: 70, title: "Icon style", detail: "Choose the status icon shown next to the timers.")

        let styleControl = NSSegmentedControl(labels: ["Outline", "Solid", "Codex"], trackingMode: .selectOne, target: self, action: #selector(changeIconStyle(_:)))
        styleControl.frame = NSRect(x: 382, y: 86, width: 182, height: 28)
        styleControl.segmentStyle = .rounded
        switch iconStyle {
        case .outline:
            styleControl.selectedSegment = 0
        case .solid:
            styleControl.selectedSegment = 1
        case .codex:
            styleControl.selectedSegment = 2
        }
        menuGroup.addSubview(styleControl)

        addRowText(to: menuGroup, y: 0, title: "Shimmer cadence", detail: "Set how often the active icon sweep repeats.")

        let shimmerControl = NSSegmentedControl(labels: ["Often", "Normal", "Calm"], trackingMode: .selectOne, target: self, action: #selector(changeShimmerCadence(_:)))
        shimmerControl.frame = NSRect(x: 382, y: 16, width: 182, height: 28)
        shimmerControl.segmentStyle = .rounded
        let cadence = shimmerCycleSeconds
        shimmerControl.selectedSegment = cadence <= 2.5 ? 0 : cadence <= 4.0 ? 1 : 2
        menuGroup.addSubview(shimmerControl)

        window.contentView = content
        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func changeMaxMenuBarChats(_ sender: NSStepper) {
        maxMenuBarChats = sender.integerValue
        if let label = settingsWindow?.contentView?.viewWithTag(1002) as? NSTextField {
            label.stringValue = "\(maxMenuBarChats)"
        }
    }

    @objc private func changeIconStyle(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 1:
            iconStyle = .solid
        case 2:
            iconStyle = .codex
        default:
            iconStyle = .outline
        }
    }

    @objc private func changeShowTimerStrip(_ sender: NSSwitch) {
        showTimerStrip = sender.state == .on
    }

    @objc private func changeUsageWindow(_ sender: NSButton) {
        switch sender.tag {
        case 2200:
            usageWindow = .sevenDays
        case 2202:
            usageWindow = .sixtyDays
        case 2203:
            usageWindow = .all
        default:
            usageWindow = .thirtyDays
        }
        updateSettingsUsageStats()
    }

    @objc private func changeUsageSource(_ sender: NSButton) {
        switch sender.tag {
        case 2211:
            usageSourceFilter = .main
        case 2212:
            usageSourceFilter = .subagent
        default:
            usageSourceFilter = .all
        }
        updateSettingsUsageStats()
    }

    private func updateSettingsUsageStats() {
        guard let content = settingsWindow?.contentView else { return }
        let stats = usageStats(window: usageWindow, source: usageSourceFilter)
        let values = [
            "\(stats.turnsCompleted)",
            formatDuration(seconds: stats.totalDurationSeconds),
            stats.turnsCompleted > 0 ? formatDuration(seconds: stats.averageDurationSeconds) : "0s",
            stats.turnsCompleted > 0 ? formatDuration(seconds: stats.longestDurationSeconds) : "0s"
        ]
        for index in 0..<values.count {
            if let field = content.viewWithTag(2100 + index) as? NSTextField {
                field.stringValue = values[index]
            }
        }
        updateSettingsFilterStyles(in: content)
    }

    private func updateSettingsFilterStyles(in content: NSView) {
        let selectedWindowTag: Int
        switch usageWindow {
        case .sevenDays:
            selectedWindowTag = 2200
        case .thirtyDays:
            selectedWindowTag = 2201
        case .sixtyDays:
            selectedWindowTag = 2202
        case .all:
            selectedWindowTag = 2203
        }

        let selectedSourceTag: Int
        switch usageSourceFilter {
        case .all:
            selectedSourceTag = 2210
        case .main:
            selectedSourceTag = 2211
        case .subagent:
            selectedSourceTag = 2212
        }

        for tag in [2200, 2201, 2202, 2203, 2210, 2211, 2212] {
            guard let button = content.viewWithTag(tag) as? NSButton else { continue }
            let selected = tag == selectedWindowTag || tag == selectedSourceTag
            let color = NSColor(calibratedWhite: selected ? 0.88 : 0.62, alpha: 1)
            let weight: NSFont.Weight = selected ? .semibold : .regular
            button.attributedTitle = NSAttributedString(
                string: button.title,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 13, weight: weight),
                    .foregroundColor: color
                ]
            )
        }
    }

    @objc private func changeLaunchAtLogin(_ sender: NSSwitch) {
        launchAtLogin = sender.state == .on
        sender.state = launchAtLogin ? .on : .off
    }

    @objc private func changeShimmerCadence(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            shimmerCycleSeconds = 2.5
        case 2:
            shimmerCycleSeconds = 6.0
        default:
            shimmerCycleSeconds = 4.0
        }
    }

    private func startFileWatchers() {
        let paths = [
            sessionIndexPath,
            chatProcessesPath,
            stateDatabasePath,
            stateWalPath,
            sessionsRoot.path
        ]
        paths.forEach { addFileWatcher(path: $0) }
    }

    private func addFileWatcher(path: String) {
        guard FileManager.default.fileExists(atPath: path) else { return }
        let descriptor = open(path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .attrib, .link, .rename, .delete],
            queue: watchQueue
        )
        source.setEventHandler { [weak self] in
            self?.refreshSoon()
        }
        source.setCancelHandler {
            close(descriptor)
        }
        watcherFileDescriptors.append(descriptor)
        fileWatchers.append(source)
        source.resume()
    }

    private func refreshSoon() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.refreshWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.refresh()
            }
            self.refreshWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
        }
    }

    private func refresh() {
        guard !refreshInFlight else {
            pendingRefresh = true
            return
        }
        pendingRefresh = false
        refreshInFlight = true

        stateQueue.async { [weak self] in
            guard let self else { return }
            let nextSnapshot = self.buildSnapshot()

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.updateCompletionAnimation(previous: self.snapshot, next: nextSnapshot)
                self.snapshot = nextSnapshot
                self.refreshInFlight = false
                self.render()
                self.updateSettingsUsageStats()
                if self.pendingRefresh {
                    self.refreshSoon()
                }
            }
        }
    }

    private func updateCompletionAnimation(previous: StatusSnapshot, next: StatusSnapshot) {
        let completedIds = Set(next.activeItems.filter { $0.completedAt != nil }.map(\.id))
        let newlyCompletedIds = completedIds.subtracting(lastCompletedIds)
        if !newlyCompletedIds.isEmpty || (previous.kind == .command && next.kind == .completed) {
            completedAnimationStart = Date()
        }
        lastCompletedIds = completedIds
    }

    private func recordUsage(for rollouts: [RolloutSession], now: Date) {
        let completed = rollouts.filter { rollout in
            guard let startedAt = rollout.turnStartedAt,
                  let completedAt = rollout.turnCompletedAt else { return false }
            return completedAt >= startedAt && completedAt.timeIntervalSince(startedAt) >= 5
        }
        guard !completed.isEmpty else { return }

        var store = readUsageStore(now: now)
        var keys = Set(store.recordedKeys)
        var changed = false
        for rollout in completed {
            guard let startedAt = rollout.turnStartedAt,
                  let completedAt = rollout.turnCompletedAt else { continue }
            guard completedAt >= store.trackingStartedAt else { continue }
            let duration = max(0, Int(completedAt.timeIntervalSince(startedAt)))
            let key = usageDedupeKey(for: rollout, startedAt: startedAt, completedAt: completedAt, duration: duration)
            guard !keys.contains(key) else { continue }
            keys.insert(key)
            let sourceType = normalizedSourceType(rollout.threadSource)
            let session = UsageSession(
                dedupeKey: key,
                threadId: rollout.id,
                turnId: rollout.turnId,
                sourceType: sourceType,
                startedAt: startedAt,
                completedAt: completedAt,
                durationSeconds: duration,
                completionReason: rollout.turnCompletionReason ?? "unknown",
                observedFirstAt: now,
                observedLastAt: now,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
            )
            store.sessions.append(session)
            upsertDailyRollup(for: session, in: &store)
            changed = true
        }

        guard changed else { return }
        store.recordedKeys = Array(keys)
        compactUsageStore(&store, now: now)
        writeUsageStore(store)
    }

    private func usageDedupeKey(for rollout: RolloutSession, startedAt: Date, completedAt: Date, duration: Int) -> String {
        if let turnId = rollout.turnId {
            return "\(rollout.id)#\(turnId)"
        }
        return "\(rollout.id)#\(Int(startedAt.timeIntervalSince1970))#\(Int(completedAt.timeIntervalSince1970))#\(duration)"
    }

    private func normalizedSourceType(_ raw: String?) -> String {
        raw == "subagent" ? "subagent" : "main"
    }

    private func upsertDailyRollup(for session: UsageSession, in store: inout UsageStore) {
        let key = dayKey(for: session.completedAt)
        if let index = store.dailyRollups.firstIndex(where: { $0.date == key && $0.sourceType == session.sourceType }) {
            store.dailyRollups[index].sessionsCount += 1
            store.dailyRollups[index].totalDurationSeconds += session.durationSeconds
            store.dailyRollups[index].maxDurationSeconds = max(store.dailyRollups[index].maxDurationSeconds, session.durationSeconds)
        } else {
            store.dailyRollups.append(DailyUsageRollup(
                date: key,
                sourceType: session.sourceType,
                sessionsCount: 1,
                totalDurationSeconds: session.durationSeconds,
                maxDurationSeconds: session.durationSeconds
            ))
        }
    }

    private func readUsageStore(now: Date = Date()) -> UsageStore {
        guard let data = try? Data(contentsOf: usageStoreURL),
              let store = try? JSONDecoder().decode(UsageStore.self, from: data) else {
            return UsageStore(trackingStartedAt: now, recordedKeys: [], sessions: [], dailyRollups: [])
        }
        return store
    }

    private func ensureUsageStoreExists() {
        guard !FileManager.default.fileExists(atPath: usageStoreURL.path) else { return }
        writeUsageStore(UsageStore(trackingStartedAt: Date(), recordedKeys: [], sessions: [], dailyRollups: []))
    }

    private func writeUsageStore(_ store: UsageStore) {
        do {
            try FileManager.default.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(store)
            try data.write(to: usageStoreURL, options: [.atomic])
        } catch {
            NSLog("Codex Status usage store write failed: \(error.localizedDescription)")
        }
    }

    private func compactUsageStore(_ store: inout UsageStore, now: Date) {
        let cutoff = now.addingTimeInterval(-60 * 24 * 60 * 60)
        store.sessions = store.sessions.filter { $0.completedAt >= cutoff }
        let recentKeys = Set(store.sessions.map(\.dedupeKey))
        store.recordedKeys = store.recordedKeys.filter { recentKeys.contains($0) }
        store.dailyRollups.sort {
            if $0.date == $1.date { return $0.sourceType < $1.sourceType }
            return $0.date < $1.date
        }
    }

    private func usageStats(window: UsageWindow, source: UsageSourceFilter, now: Date = Date()) -> UsageStats {
        var store = readUsageStore(now: now)
        compactUsageStore(&store, now: now)
        let rows = store.dailyRollups.filter { rollup in
            usageSourceMatches(rollup.sourceType, filter: source) && usageDateMatches(rollup.date, window: window, now: now)
        }
        let count = rows.reduce(0) { $0 + $1.sessionsCount }
        let total = rows.reduce(0) { $0 + $1.totalDurationSeconds }
        let longest = rows.map(\.maxDurationSeconds).max() ?? 0
        return UsageStats(
            turnsCompleted: count,
            totalDurationSeconds: total,
            averageDurationSeconds: count > 0 ? total / count : 0,
            longestDurationSeconds: longest,
            trackingStartedAt: store.dailyRollups.isEmpty && store.sessions.isEmpty ? nil : store.trackingStartedAt
        )
    }

    private func usageSourceMatches(_ sourceType: String, filter: UsageSourceFilter) -> Bool {
        switch filter {
        case .all:
            return true
        case .main:
            return sourceType == "main"
        case .subagent:
            return sourceType == "subagent"
        }
    }

    private func usageDateMatches(_ day: String, window: UsageWindow, now: Date) -> Bool {
        guard window != .all else { return true }
        let days: Int
        switch window {
        case .sevenDays:
            days = 7
        case .thirtyDays:
            days = 30
        case .sixtyDays:
            days = 60
        case .all:
            days = 0
        }
        let cutoff = Calendar.current.startOfDay(for: now.addingTimeInterval(TimeInterval(-(days - 1) * 24 * 60 * 60)))
        return day >= dayKey(for: cutoff)
    }

    private func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func buildSnapshot() -> StatusSnapshot {
        let now = Date()
        let codexRunning = cachedIsCodexRunning(now: now)
        let sessions = readRecentSessions(limit: 60)
        let sessionTitles = readSessionTitleIndex()
        let rolloutSessions = readRecentRolloutSessions(titleIndex: sessionTitles)
        recordUsage(for: rolloutSessions, now: now)
        let liveCommands = readChatProcesses().filter { command in
            guard let pid = command.osPid, isProcessAlive(pid: pid) else { return false }
            return now.timeIntervalSince(Date(timeIntervalSince1970: command.startedAtMs / 1000)) < staleCommandWindow
        }

        let activeRollouts = rolloutSessions.filter { rollout in
            if rollout.isTurnActive, let startedAt = rollout.turnStartedAt {
                return now.timeIntervalSince(startedAt) < activeTurnStaleWindow
            }
            if rollout.hasTurnState {
                return false
            }
            return now.timeIntervalSince(rollout.updatedAt) < activeWriteWindow
        }.sorted {
            ($0.turnStartedAt ?? $0.updatedAt) < ($1.turnStartedAt ?? $1.updatedAt)
        }
        if !activeRollouts.isEmpty || !liveCommands.isEmpty {
            let activeRolloutIds = Set(activeRollouts.map(\.id))
            pruneActiveRolloutStartCache(keeping: activeRolloutIds)

            let rolloutItems = activeRollouts.map { rollout in
                let detectedStartedAt = rollout.turnStartedAt ?? rollout.updatedAt
                return ActiveItem(
                    id: rollout.id,
                    title: rollout.title ?? URL(fileURLWithPath: rollout.cwd ?? rollout.path).lastPathComponent,
                    detail: rollout.cwd ?? "Agent turn active",
                    pid: nil,
                    startedAt: persistedActiveStart(for: rollout.id, detected: detectedStartedAt),
                    completedAt: nil
                )
            }
            let commandItems = liveCommands
                .filter { !activeRolloutIds.contains($0.conversationId) }
                .sorted { $0.startedAtMs < $1.startedAtMs }
                .map { command in
                    ActiveItem(
                        id: command.conversationId,
                        title: commandTitle(for: command, titleIndex: sessionTitles),
                        detail: command.command,
                        pid: command.osPid,
                        startedAt: Date(timeIntervalSince1970: command.startedAtMs / 1000),
                        completedAt: nil
                    )
                }
            let activeItems = (rolloutItems + commandItems).sorted {
                ($0.startedAt ?? .distantFuture) < ($1.startedAt ?? .distantFuture)
            }
            let primary = activeItems.first!
            let title = activeItems.count > 1 ? "\(activeItems.count) Codex conversations" : "Codex: \(primary.title)"
            writeDebug(codexRunning: codexRunning, selected: "active:\(activeItems.map(\.title).joined(separator: ",")) rollouts=\(rolloutSessions.count) liveCommands=\(liveCommands.count)")
            return StatusSnapshot(
                kind: .command,
                title: title,
                detail: primary.detail,
                startedAt: activeItems.compactMap(\.startedAt).min(),
                updatedAt: liveCommands.compactMap { $0.updatedAtMs.map { Date(timeIntervalSince1970: $0 / 1000) } }.max(),
                activeItems: activeItems
            )
        }

        pruneActiveRolloutStartCache(keeping: [])

        let clearedIds = clearedCompletedIds
        let completedRollouts = rolloutSessions.filter { rollout in
            guard !clearedIds.contains(rollout.id),
                  let startedAt = rollout.turnStartedAt,
                  let completedAt = rollout.turnCompletedAt else { return false }
            let duration = completedAt.timeIntervalSince(startedAt)
            let qualifies = rollout.threadSource != "subagent" && duration >= completedFinishMinimum
            return qualifies && now.timeIntervalSince(completedAt) < completedRetentionWindow
        }.sorted {
            ($0.turnCompletedAt ?? $0.updatedAt) > ($1.turnCompletedAt ?? $1.updatedAt)
        }
        if !completedRollouts.isEmpty {
            let completedItems = completedRollouts.map { rollout in
                ActiveItem(
                    id: rollout.id,
                    title: rollout.title ?? URL(fileURLWithPath: rollout.cwd ?? rollout.path).lastPathComponent,
                    detail: rollout.cwd ?? "Agent turn completed",
                    pid: nil,
                    startedAt: rollout.turnStartedAt,
                    completedAt: rollout.turnCompletedAt
                )
            }
            writeDebug(codexRunning: codexRunning, selected: "completed:\(completedItems.map(\.title).joined(separator: ",")) rollouts=\(rolloutSessions.count)")
            return StatusSnapshot(
                kind: .completed,
                title: completedItems.count > 1 ? "\(completedItems.count) completed Codex conversations" : "Completed: \(completedItems[0].title)",
                detail: "Click a completed conversation to clear it",
                startedAt: completedItems.compactMap(\.startedAt).min(),
                updatedAt: completedRollouts.compactMap(\.turnCompletedAt).max(),
                activeItems: completedItems
            )
        }

        if codexRunning {
            writeDebug(codexRunning: codexRunning, selected: "running rollouts=\(rolloutSessions.count)")
            return StatusSnapshot(
                kind: .running,
                title: "Codex",
                detail: "No active chats",
                startedAt: nil,
                updatedAt: sessions.first?.updatedAt,
                activeItems: []
            )
        }

        writeDebug(codexRunning: codexRunning, selected: "idle")
        return StatusSnapshot(
            kind: .idle,
            title: "Codex",
            detail: "No active chats",
            startedAt: nil,
            updatedAt: sessions.first?.updatedAt,
            activeItems: []
        )
    }

    private func render() {
        let icon = currentStatusIcon()
        let segments = showTimerStrip ? statusBarSegments() : []
        let segmentsKey = statusBarSegmentsKey(segments)

        if segmentsKey != lastRenderedSegmentsKey {
            statusBarView.configure(icon: icon, segments: segments, font: textFont)
            let width = ceil(statusBarView.intrinsicContentSize.width)
            statusItem.length = max(26, width)
            statusBarView.frame = NSRect(x: 0, y: 0, width: statusItem.length, height: 22)
            lastRenderedSegmentsKey = segmentsKey
        } else {
            statusBarView.updateIcon(icon)
        }
    }

    private func shouldAnimateIcon() -> Bool {
        if snapshot.kind == .command {
            return true
        }
        return false
    }

    private func renderLogo() {
        statusBarView.updateIcon(currentStatusIcon())
    }

    private func currentStatusIcon() -> NSImage? {
        let (color, colorKey) = statusIconColor()
        let phase = currentShimmerPhase()
        let phaseBucket = shouldAnimateIcon() ? Int((phase * 120).rounded(.down)) : 0
        let cadenceKey = String(format: "%.2f", shimmerCycleSeconds)
        let iconKey = "\(iconStyle.rawValue)|\(colorKey)|\(phaseBucket)|\(cadenceKey)"
        if iconKey == lastRenderedIconKey, let cachedStatusIcon {
            return cachedStatusIcon
        }
        if let icon = cachedStatusIcons[iconKey] {
            cachedStatusIcon = icon
            lastRenderedIconKey = iconKey
            return icon
        }

        let icon = codexIcon(color: color, active: shouldAnimateIcon(), phase: phase)
        if cachedStatusIcons.count > 192 {
            cachedStatusIcons.removeAll(keepingCapacity: true)
        }
        cachedStatusIcons[iconKey] = icon
        cachedStatusIcon = icon
        lastRenderedIconKey = iconKey
        return icon
    }

    private func currentShimmerPhase() -> CGFloat {
        guard shouldAnimateIcon() else { return 0 }
        let cadence = max(0.1, shimmerCycleSeconds)
        let elapsed = Date().timeIntervalSince(animationStartedAt)
        let progress = elapsed.truncatingRemainder(dividingBy: cadence) / cadence
        return CGFloat(progress)
    }

    private func statusIconColor() -> (NSColor, String) {
        let color: NSColor
        let key: String
        switch snapshot.kind {
        case .command:
            color = activeColor
            key = "active"
        case .completed:
            color = NSColor.systemTeal
            key = "completed"
        case .running:
            color = NSColor.systemTeal
            key = "running"
        case .idle:
            color = NSColor.systemRed
            key = "idle"
        }
        return (color, key)
    }

    private func statusBarSegments() -> [StatusBarContentView.Segment] {
        let entries = menuBarTimerEntries()
        let overflow = max(0, snapshot.activeItems.count - max(1, maxMenuBarChats))
        let opensDirectly = snapshot.activeItems.count == 1
        var segments = entries.map { entry in
            StatusBarContentView.Segment(
                title: entry.title,
                item: opensDirectly ? entry.item : nil,
                completed: entry.completed,
                opensCodex: entry.opensCodex,
                opensMenu: entry.opensMenu || (!opensDirectly && entry.item != nil)
            )
        }

        if overflow > 0 {
            segments.append(StatusBarContentView.Segment(
                title: "+\(overflow)",
                item: nil,
                completed: false,
                opensCodex: false,
                opensMenu: true
            ))
        }

        return segments
    }

    private func statusBarSegmentsKey(_ segments: [StatusBarContentView.Segment]) -> String {
        segments.map { segment in
            [
                segment.title,
                segment.item?.id ?? "",
                segment.completed ? "1" : "0",
                segment.opensCodex ? "1" : "0",
                segment.opensMenu ? "1" : "0"
            ].joined(separator: "\u{1f}")
        }.joined(separator: "\u{1e}")
    }

    private func menuBarTimerEntries() -> [(title: String, item: ActiveItem?, completed: Bool, opensCodex: Bool, opensMenu: Bool)] {
        switch snapshot.kind {
        case .command:
            if !snapshot.activeItems.isEmpty {
                return timerEntries(for: snapshot.activeItems, completed: false)
            }
            return [(snapshot.startedAt.map { formatElapsed(since: $0) } ?? "active", nil, false, false, true)]
        case .completed:
            return timerEntries(for: snapshot.activeItems, completed: true)
        case .running:
            return [("No active chats", nil, false, true, false)]
        case .idle:
            return [("No active chats", nil, false, true, false)]
        }
    }

    private func timerEntries(for items: [ActiveItem], completed: Bool) -> [(title: String, item: ActiveItem?, completed: Bool, opensCodex: Bool, opensMenu: Bool)] {
        let visibleLimit = max(1, maxMenuBarChats)
        return items.prefix(visibleLimit).map { item -> (title: String, item: ActiveItem?, completed: Bool, opensCodex: Bool, opensMenu: Bool) in
            if completed, let startedAt = item.startedAt, let completedAt = item.completedAt {
                return (formatDuration(from: startedAt, to: completedAt), item, true, false, false)
            }

            return (item.startedAt.map { formatElapsed(since: $0) } ?? "active", item, false, false, false)
        }
    }

    private func codexIcon(color: NSColor, active: Bool, phase: CGFloat) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        let shimmerStart: CGFloat = 0.08
        let shimmerDuration: CGFloat = 0.62
        let shimmerActive = active && phase >= shimmerStart && phase <= shimmerStart + shimmerDuration
        let sweepProgress = max(0, min(1, (phase - shimmerStart) / shimmerDuration))

        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        NSGraphicsContext.current?.shouldAntialias = true

        let selectedLogo: NSImage?
        switch iconStyle {
        case .outline:
            selectedLogo = outlineLogo ?? templateLogo
        case .solid:
            selectedLogo = templateLogo
        case .codex:
            selectedLogo = startupLogo ?? outlineLogo ?? templateLogo
        }

        if let logo = selectedLogo {
            let rect = NSRect(origin: .zero, size: size)
            if iconStyle == .codex {
                logo.draw(in: rect, from: .zero, operation: .sourceOver, fraction: active ? 1 : 0.72)
            } else {
                color.set()
                logo.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
                rect.fill(using: .sourceAtop)
            }

            if shimmerActive, let cgImage = logo.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                let context = NSGraphicsContext.current?.cgContext
                context?.saveGState()
                context?.clip(to: rect, mask: cgImage)

                let sweepWidth = size.width * 0.68
                let x = -sweepWidth + (size.width + sweepWidth * 2.2) * sweepProgress
                let sweepRect = NSRect(x: x, y: 0, width: sweepWidth, height: size.height)
                let gradient = NSGradient(colors: [
                    NSColor.white.withAlphaComponent(0.0),
                    NSColor.white.withAlphaComponent(0.46),
                    NSColor.white.withAlphaComponent(0.0)
                ])
                gradient?.draw(in: sweepRect, angle: 0)
                context?.restoreGState()
            }
        } else {
            color.setStroke()
            let path = NSBezierPath(roundedRect: NSRect(x: 3, y: 3, width: 12, height: 12), xRadius: 4, yRadius: 4)
            path.lineWidth = 2
            path.stroke()
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func readRecentSessions(limit: Int) -> [SessionIndexEntry] {
        guard let handle = FileHandle(forReadingAtPath: sessionIndexPath) else { return [] }
        defer { try? handle.close() }

        let size = (try? handle.seekToEnd()) ?? 0
        let chunkSize: UInt64 = 128 * 1024
        try? handle.seek(toOffset: size > chunkSize ? size - chunkSize : 0)

        guard let data = try? handle.readToEnd(),
              let content = String(data: data, encoding: .utf8) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = ISO8601DateFormatter.codex.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(raw)")
        }

        return content
            .split(separator: "\n")
            .suffix(limit)
            .compactMap { line -> SessionIndexEntry? in
                guard let lineData = String(line).data(using: .utf8) else { return nil }
                return try? decoder.decode(SessionIndexEntry.self, from: lineData)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func readChatProcesses() -> [ChatProcess] {
        guard let data = FileManager.default.contents(atPath: chatProcessesPath) else { return [] }
        return (try? JSONDecoder().decode([ChatProcess].self, from: data)) ?? []
    }

    private func readRecentRolloutSessions(titleIndex: [String: String]) -> [RolloutSession] {
        var sessionsById: [String: RolloutSession] = [:]
        var indexedPaths = Set<String>()

        readRecentThreadIndexEntries()
            .compactMap { entry -> RolloutSession? in
                indexedPaths.insert(entry.rolloutPath)
                return readRolloutSession(from: entry, titleIndex: titleIndex)
            }
            .forEach { session in
                sessionsById[session.id] = session
            }

        let discoveredSessions = readRecentRolloutFiles(excluding: indexedPaths, titleIndex: titleIndex)
        for session in discoveredSessions {
            if let existing = sessionsById[session.id] {
                sessionsById[session.id] = mergeRolloutSession(existing, with: session)
            } else {
                sessionsById[session.id] = session
            }
        }

        return sessionsById.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func readRecentRolloutFiles(excluding indexedPaths: Set<String>, titleIndex: [String: String]) -> [RolloutSession] {
        let candidateURLs = (FileManager.default.enumerator(
            at: sessionsRoot,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )?.compactMap { $0 as? URL }) ?? []

        return candidateURLs
            .filter { $0.pathExtension == "jsonl" && !indexedPaths.contains($0.path) }
            .compactMap { url -> RolloutSession? in
                guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                      let updatedAt = values.contentModificationDate,
                      Date().timeIntervalSince(updatedAt) < activeTurnStaleWindow else { return nil }
                return readRolloutSession(at: url, updatedAt: updatedAt, titleIndex: titleIndex)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func mergeRolloutSession(_ primary: RolloutSession, with discovered: RolloutSession) -> RolloutSession {
        let preferDiscoveredTurnState = discovered.turnId != nil || discovered.hasTurnState
        return RolloutSession(
            id: primary.id,
            title: primary.title ?? discovered.title,
            cwd: primary.cwd ?? discovered.cwd,
            path: primary.path,
            threadSource: primary.threadSource ?? discovered.threadSource,
            updatedAt: max(primary.updatedAt, discovered.updatedAt),
            turnId: preferDiscoveredTurnState ? discovered.turnId : primary.turnId,
            turnStartedAt: preferDiscoveredTurnState ? discovered.turnStartedAt : primary.turnStartedAt,
            turnCompletedAt: preferDiscoveredTurnState ? discovered.turnCompletedAt : primary.turnCompletedAt,
            turnCompletionReason: preferDiscoveredTurnState ? discovered.turnCompletionReason : primary.turnCompletionReason,
            isTurnActive: preferDiscoveredTurnState ? discovered.isTurnActive : primary.isTurnActive,
            hasTurnState: preferDiscoveredTurnState ? discovered.hasTurnState : primary.hasTurnState
        )
    }

    private func readRecentThreadIndexEntries() -> [ThreadIndexEntry] {
        guard FileManager.default.fileExists(atPath: stateDatabasePath) else { return [] }

        let cutoffMs = (Date().timeIntervalSince1970 - activeTurnStaleWindow) * 1000
        let query = """
        select
          id,
          rollout_path,
          max(coalesce(updated_at_ms, 0), coalesce(recency_at_ms, 0)) as touched_at_ms,
          title,
          cwd,
          thread_source
        from threads
        where rollout_path is not null
          and rollout_path <> ''
          and max(coalesce(updated_at_ms, 0), coalesce(recency_at_ms, 0)) >= \(Int(cutoffMs))
        order by touched_at_ms desc
        limit 24;
        """

        let task = Process()
        let output = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        task.arguments = ["-readonly", "-json", stateDatabasePath, query]
        task.standardOutput = output
        task.standardError = Pipe()

        do {
            try task.run()
        } catch {
            return []
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard task.terminationStatus == 0, !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([ThreadIndexEntry].self, from: data)) ?? []
    }

    private func readRolloutSession(from entry: ThreadIndexEntry, titleIndex: [String: String]) -> RolloutSession? {
        guard FileManager.default.fileExists(atPath: entry.rolloutPath) else { return nil }
        let url = URL(fileURLWithPath: entry.rolloutPath)
        let contentUpdatedAt = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date(timeIntervalSince1970: entry.touchedAtMs / 1000)
        let indexedUpdatedAt = Date(timeIntervalSince1970: entry.touchedAtMs / 1000)
        if let cached = rolloutSessionCache[entry.rolloutPath],
           cached.contentUpdatedAt == contentUpdatedAt {
            let session = cached.session
            return RolloutSession(
                id: entry.id,
                title: titleIndex[entry.id] ?? entry.title ?? session.title,
                cwd: entry.cwd ?? session.cwd,
                path: entry.rolloutPath,
                threadSource: entry.threadSource ?? session.threadSource,
                updatedAt: max(indexedUpdatedAt, contentUpdatedAt),
                turnId: session.turnId,
                turnStartedAt: session.turnStartedAt,
                turnCompletedAt: session.turnCompletedAt,
                turnCompletionReason: session.turnCompletionReason,
                isTurnActive: session.isTurnActive,
                hasTurnState: session.hasTurnState
            )
        }

        let turnState = readRolloutTurnState(at: url)

        let session = RolloutSession(
            id: entry.id,
            title: titleIndex[entry.id] ?? entry.title,
            cwd: entry.cwd,
            path: entry.rolloutPath,
            threadSource: entry.threadSource,
            updatedAt: max(indexedUpdatedAt, contentUpdatedAt),
            turnId: turnState.turnId,
            turnStartedAt: turnState.startedAt,
            turnCompletedAt: turnState.completedAt,
            turnCompletionReason: turnState.completionReason,
            isTurnActive: turnState.isActive,
            hasTurnState: turnState.hasState
        )
        cacheRolloutSession(session, contentUpdatedAt: contentUpdatedAt)
        return session
    }

    private func readRolloutSession(at url: URL, updatedAt: Date, titleIndex: [String: String]) -> RolloutSession? {
        if let cached = rolloutSessionCache[url.path],
           cached.contentUpdatedAt == updatedAt {
            let session = cached.session
            return RolloutSession(
                id: session.id,
                title: titleIndex[session.id] ?? session.title,
                cwd: session.cwd,
                path: session.path,
                threadSource: session.threadSource,
                updatedAt: updatedAt,
                turnId: session.turnId,
                turnStartedAt: session.turnStartedAt,
                turnCompletedAt: session.turnCompletedAt,
                turnCompletionReason: session.turnCompletionReason,
                isTurnActive: session.isTurnActive,
                hasTurnState: session.hasTurnState
            )
        }

        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 1024 * 1024),
              let text = String(data: data, encoding: .utf8),
              let first = text.split(separator: "\n").first,
              let jsonData = String(first).data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              obj["type"] as? String == "session_meta",
              let payload = obj["payload"] as? [String: Any],
              let id = payload["id"] as? String else { return nil }
        let turnState = readRolloutTurnState(at: url)

        let session = RolloutSession(
            id: id,
            title: titleIndex[id] ?? payload["thread_name"] as? String ?? payload["agent_nickname"] as? String,
            cwd: payload["cwd"] as? String,
            path: url.path,
            threadSource: payload["thread_source"] as? String,
            updatedAt: updatedAt,
            turnId: turnState.turnId,
            turnStartedAt: turnState.startedAt,
            turnCompletedAt: turnState.completedAt,
            turnCompletionReason: turnState.completionReason,
            isTurnActive: turnState.isActive,
            hasTurnState: turnState.hasState
        )
        cacheRolloutSession(session, contentUpdatedAt: updatedAt)
        return session
    }

    private func cacheRolloutSession(_ session: RolloutSession, contentUpdatedAt: Date) {
        rolloutSessionCache[session.path] = (contentUpdatedAt, session)
        guard rolloutSessionCache.count > 256 else { return }
        let oldestKeys = rolloutSessionCache
            .sorted { $0.value.contentUpdatedAt < $1.value.contentUpdatedAt }
            .prefix(rolloutSessionCache.count - 256)
            .map(\.key)
        oldestKeys.forEach { rolloutSessionCache.removeValue(forKey: $0) }
    }

    private func readSessionTitleIndex() -> [String: String] {
        guard let handle = FileHandle(forReadingAtPath: sessionIndexPath) else { return [:] }
        defer { try? handle.close() }
        guard let data = try? handle.readToEnd(),
              let content = String(data: data, encoding: .utf8) else { return [:] }

        return content
            .split(separator: "\n")
            .reduce(into: [String: String]()) { result, line in
                guard let lineData = String(line).data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                      let id = obj["id"] as? String,
                      let title = obj["thread_name"] as? String,
                      !title.isEmpty else { return }
                result[id] = title
            }
    }

    private func readRolloutTurnState(at url: URL) -> (turnId: String?, startedAt: Date?, completedAt: Date?, completionReason: String?, isActive: Bool, hasState: Bool) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return (nil, nil, nil, nil, false, false) }
        defer { try? handle.close() }

        let size = (try? handle.seekToEnd()) ?? 0
        let chunk: UInt64 = 2 * 1024 * 1024
        try? handle.seek(toOffset: size > chunk ? size - chunk : 0)

        guard let data = try? handle.readToEnd(),
              let text = String(data: data, encoding: .utf8) else { return (nil, nil, nil, nil, false, false) }

        var lastTurnId: String?
        var openTurnStartedAt: Date?
        var lastCompletedStartedAt: Date?
        var lastCompletedAt: Date?
        var completedTurnIds = Set<String>()
        var firstSeenByTurnId: [String: Date] = [:]
        var terminalAnswerTurnIds = Set<String>()
        var abortedTurnIds = Set<String>()
        var completionReasonByTurnId: [String: String] = [:]
        var sawCompaction = false

        for line in text.split(separator: "\n") {
            guard let lineData = String(line).data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let type = obj["type"] as? String else { continue }

            let timestamp = (obj["timestamp"] as? String).flatMap { ISO8601DateFormatter.codexAny.date(from: $0) }
            if type == "compacted" {
                sawCompaction = true
            }

            if type == "event_msg",
               let payload = obj["payload"] as? [String: Any],
               payload["type"] as? String == "task_started",
               let turnId = payload["turn_id"] as? String {
                lastTurnId = turnId
                if let timestamp {
                    firstSeenByTurnId[turnId] = min(firstSeenByTurnId[turnId] ?? timestamp, timestamp)
                    openTurnStartedAt = openTurnStartedAt.map { min($0, timestamp) } ?? timestamp
                }
            } else if type == "turn_context",
               let payload = obj["payload"] as? [String: Any],
               let turnId = payload["turn_id"] as? String {
                lastTurnId = turnId
                if let timestamp {
                    firstSeenByTurnId[turnId] = firstSeenByTurnId[turnId] ?? timestamp
                    openTurnStartedAt = openTurnStartedAt ?? timestamp
                }
            } else if type == "event_msg",
                      let payload = obj["payload"] as? [String: Any],
                      payload["type"] as? String == "task_complete",
                      let turnId = payload["turn_id"] as? String {
                completedTurnIds.insert(turnId)
                completionReasonByTurnId[turnId] = "completed"
                if let completedAt = completedAt(from: payload, fallback: timestamp) {
                    lastCompletedStartedAt = openTurnStartedAt ?? firstSeenByTurnId[turnId]
                    lastCompletedAt = completedAt
                }
                if turnId == lastTurnId {
                    openTurnStartedAt = nil
                }
            } else if type == "event_msg",
                      let payload = obj["payload"] as? [String: Any],
                      let turnId = abortedTurnId(from: payload, fallback: lastTurnId) {
                abortedTurnIds.insert(turnId)
                completionReasonByTurnId[turnId] = "stopped"
                lastCompletedStartedAt = openTurnStartedAt ?? firstSeenByTurnId[turnId]
                lastCompletedAt = timestamp
                if turnId == lastTurnId {
                    openTurnStartedAt = nil
                }
            } else if type == "event_msg",
                      let payload = obj["payload"] as? [String: Any],
                      payload["type"] as? String == "context_compacted" {
                sawCompaction = true
            } else if type == "response_item",
                      let payload = obj["payload"] as? [String: Any],
                      let turnId = turnId(from: payload) {
                lastTurnId = turnId
                if let timestamp {
                    firstSeenByTurnId[turnId] = firstSeenByTurnId[turnId] ?? timestamp
                    openTurnStartedAt = openTurnStartedAt ?? firstSeenByTurnId[turnId]
                }
                if payload["type"] as? String == "message",
                   payload["role"] as? String == "assistant",
                   payload["phase"] as? String == "final_answer" {
                    terminalAnswerTurnIds.insert(turnId)
                    completionReasonByTurnId[turnId] = completionReasonByTurnId[turnId] ?? "completed"
                    lastCompletedStartedAt = openTurnStartedAt ?? firstSeenByTurnId[turnId]
                    lastCompletedAt = timestamp
                    openTurnStartedAt = nil
                }
            }
        }

        guard let turnId = lastTurnId else { return (nil, nil, nil, nil, false, false) }
        let isComplete = completedTurnIds.contains(turnId)
            || terminalAnswerTurnIds.contains(turnId)
            || abortedTurnIds.contains(turnId)
        if isComplete {
            var startedAt = lastCompletedStartedAt ?? firstSeenByTurnId[turnId]
            if startedAt == nil,
               sawCompaction,
               let fullStart = readTaskStartedAt(in: url, turnId: turnId) {
                startedAt = min(startedAt ?? fullStart, fullStart)
            }
            return (turnId, startedAt, lastCompletedAt, completionReasonByTurnId[turnId] ?? "unknown", false, true)
        }
        var startedAt = openTurnStartedAt ?? firstSeenByTurnId[turnId]
        if startedAt == nil,
           sawCompaction,
           let fullStart = readTaskStartedAt(in: url, turnId: turnId) {
            startedAt = min(startedAt ?? fullStart, fullStart)
        }
        return (turnId, startedAt, nil, nil, true, true)
    }

    private func readTaskStartedAt(in url: URL, turnId: String) -> Date? {
        let cacheKey = "\(url.path)#\(turnId)"
        if let cached = taskStartedAtCache[cacheKey] {
            return Date(timeIntervalSince1970: cached)
        }

        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.readToEnd(),
              let text = String(data: data, encoding: .utf8) else { return nil }

        for line in text.split(separator: "\n") {
            guard let lineData = String(line).data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  obj["type"] as? String == "event_msg",
                  let payload = obj["payload"] as? [String: Any],
                  payload["type"] as? String == "task_started",
                  payload["turn_id"] as? String == turnId,
                  let rawTimestamp = obj["timestamp"] as? String,
                  let timestamp = ISO8601DateFormatter.codexAny.date(from: rawTimestamp) else { continue }
            var cache = taskStartedAtCache
            cache[cacheKey] = timestamp.timeIntervalSince1970
            taskStartedAtCache = cache
            return timestamp
        }
        return nil
    }

    private func completedAt(from payload: [String: Any], fallback: Date?) -> Date? {
        if let raw = payload["completed_at"] as? Double {
            return Date(timeIntervalSince1970: raw)
        }
        if let raw = payload["completed_at"] as? Int {
            return Date(timeIntervalSince1970: TimeInterval(raw))
        }
        return fallback
    }

    private func persistedActiveStart(for id: String, detected: Date) -> Date {
        var cache = activeRolloutStartCache
        if let cached = cache[id] {
            let cachedDate = Date(timeIntervalSince1970: cached)
            if cachedDate <= detected {
                return cachedDate
            }
        }
        cache[id] = detected.timeIntervalSince1970
        activeRolloutStartCache = cache
        return detected
    }

    private func pruneActiveRolloutStartCache(keeping activeIds: Set<String>) {
        var cache = activeRolloutStartCache
        let originalCount = cache.count
        cache = cache.filter { activeIds.contains($0.key) }
        if cache.count != originalCount {
            activeRolloutStartCache = cache
        }
    }

    private func abortedTurnId(from payload: [String: Any], fallback: String?) -> String? {
        guard let eventType = payload["type"] as? String else { return nil }
        let lowered = eventType.lowercased()
        let terminalMarkers = ["abort", "cancel", "interrupt", "stop"]
        guard terminalMarkers.contains(where: { lowered.contains($0) }) else { return nil }
        return payload["turn_id"] as? String ?? fallback
    }

    private func turnId(from payload: [String: Any]) -> String? {
        if let metadata = payload["metadata"] as? [String: Any],
           let turnId = metadata["turn_id"] as? String {
            return turnId
        }
        if let metadata = payload["internal_chat_message_metadata_passthrough"] as? [String: Any],
           let turnId = metadata["turn_id"] as? String {
            return turnId
        }
        return nil
    }

    private func isCodexRunning() -> Bool {
        if NSWorkspace.shared.runningApplications.contains(where: { app in
            app.bundleIdentifier == "com.openai.codex" || app.localizedName == "Codex"
        }) {
            return true
        }

        return processRows().contains { row in
            let line = row.raw
            return line.contains("/Applications/Codex.app/")
                || line.contains("Codex.app/Contents/MacOS/Codex")
                || line.contains("codex app-server")
        }
    }

    private func cachedIsCodexRunning(now: Date) -> Bool {
        guard now.timeIntervalSince(lastCodexProcessCheck) >= 5 else {
            return cachedCodexRunning
        }
        lastCodexProcessCheck = now
        cachedCodexRunning = isCodexRunning()
        return cachedCodexRunning
    }

    private func isProcessAlive(pid: Int) -> Bool {
        guard pid > 0 else { return false }
        return kill(pid_t(pid), 0) == 0
    }

    private func activeKernelProcesses(from rows: [ProcessRow]) -> [(project: String, pid: Int, startedAt: Date?)] {
        rows.compactMap { row in
            let line = row.command
            guard line.contains("cua_node/bin/node"),
                  line.contains("--session-id"),
                  line.contains("--working-dir") else { return nil }
            let project = extractWorkingDirectory(from: line).map {
                URL(fileURLWithPath: $0).lastPathComponent
            } ?? "Kernel"
            return (project, row.pid, row.startedAt)
        }
    }

    private func writeDebug(codexRunning: Bool, selected: String) {
        guard debugLoggingEnabled else { return }
        let payload: [String: Any] = [
            "ts": ISO8601DateFormatter().string(from: Date()),
            "selected": selected,
            "codexRunning": codexRunning
        ]

        do {
            let dir = URL(fileURLWithPath: debugPath).deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: URL(fileURLWithPath: debugPath), options: [.atomic])
            try data.write(to: URL(fileURLWithPath: "/tmp/codex-status-debug.json"), options: [.atomic])
        } catch {
            let fallback = "{\"selected\":\"\(selected)\",\"debugError\":\"\(error.localizedDescription)\"}\n"
            try? fallback.write(toFile: "/tmp/codex-status-debug-error.json", atomically: true, encoding: .utf8)
        }
    }

    struct ProcessRow {
        let pid: Int
        let elapsedSeconds: Int
        let command: String

        var startedAt: Date {
            Date(timeIntervalSinceNow: -TimeInterval(elapsedSeconds))
        }

        var raw: String {
            "\(pid) \(command)"
        }
    }

    private func processRows() -> [ProcessRow] {
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["axo", "pid=,etime=,command="]
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return [] }
        return output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count == 3,
                  let pid = Int(parts[0]),
                  let elapsed = elapsedSeconds(from: String(parts[1])) else { return nil }
            return ProcessRow(pid: pid, elapsedSeconds: elapsed, command: String(parts[2]))
        }
    }

    private func elapsedSeconds(from raw: String) -> Int? {
        let daySplit = raw.split(separator: "-", maxSplits: 1).map(String.init)
        let dayCount: Int
        let timePart: String
        if daySplit.count == 2 {
            dayCount = Int(daySplit[0]) ?? 0
            timePart = daySplit[1]
        } else {
            dayCount = 0
            timePart = raw
        }

        let units = timePart.split(separator: ":").compactMap { Int($0) }
        let seconds: Int
        switch units.count {
        case 3:
            seconds = units[0] * 3600 + units[1] * 60 + units[2]
        case 2:
            seconds = units[0] * 60 + units[1]
        case 1:
            seconds = units[0]
        default:
            return nil
        }
        return dayCount * 86400 + seconds
    }

    private func extractWorkingDirectory(from command: String) -> String? {
        guard let range = command.range(of: "--working-dir ") else { return nil }
        let tail = command[range.upperBound...]
        return tail.split(separator: " ").first.map(String.init)
    }

    private func commandTitle(for command: ChatProcess, titleIndex: [String: String]) -> String {
        if let title = command.chatTitle, !title.isEmpty {
            return title
        }
        if let title = titleIndex[command.conversationId], !title.isEmpty {
            return title
        }
        if let cwd = command.cwd, !cwd.isEmpty {
            return URL(fileURLWithPath: cwd).lastPathComponent
        }
        return command.conversationId
    }

    private func truncatedConversationTitle(_ title: String, limit: Int = 50) -> String {
        let normalized = title
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > limit else { return normalized }
        let end = normalized.index(normalized.startIndex, offsetBy: max(0, limit - 3))
        return "\(normalized[..<end])..."
    }

    private func formatElapsed(since date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        return formatDuration(seconds: seconds)
    }

    private func formatDuration(from start: Date, to end: Date) -> String {
        formatDuration(seconds: max(0, Int(end.timeIntervalSince(start))))
    }

    private func formatDuration(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        if minutes > 0 {
            return "\(minutes)m \(secs)s"
        }
        return "\(secs)s"
    }

    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = .current
        formatter.setLocalizedDateFormatFromTemplate("MMM d, y")
        return formatter.string(from: date)
    }

    private func relativeTime(_ date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 10 { return "just now" }
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }
}

extension ISO8601DateFormatter {
    static let codex: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let codexAny: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

let app = NSApplication.shared
let controller = CodexStatusController()
withExtendedLifetime(controller) {
    app.run()
}
