import AppKit
import Combine
import ChumenCore

private final class StackedSpeedStatusView: NSView {
    private let iconView = NSImageView()
    private let upArrowLabel = NSTextField(labelWithString: "↑")
    private let downArrowLabel = NSTextField(labelWithString: "↓")
    private let upValueLabel = NSTextField(labelWithString: "0 KB/s")
    private let downValueLabel = NSTextField(labelWithString: "0 KB/s")
    private static let rateFormatter = ByteCountFormatter()
    private static let statusFont = NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)
    private static let iconSize: CGFloat = 16
    private static let leadingPadding: CGFloat = 4
    private static let iconTextGap: CGFloat = 4
    private static let arrowWidth: CGFloat = 8
    private static let arrowValueGap: CGFloat = 2
    private static let trailingPadding: CGFloat = 4
    private static let preferredWidth: CGFloat = {
        let referenceRateWidth = ["999 KB/s", "99.9 MB/s", "9.99 GB/s"]
            .map { ($0 as NSString).size(withAttributes: [.font: statusFont]).width }
            .max() ?? 54
        let contentWidth = leadingPadding + iconSize + iconTextGap + arrowWidth + arrowValueGap + referenceRateWidth + trailingPadding
        return ceil(contentWidth)
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func update(icon: NSImage?, up: Int64, down: Int64) {
        iconView.image = icon
        upValueLabel.stringValue = Self.formatRate(up)
        downValueLabel.stringValue = Self.formatRate(down)
        needsLayout = true
    }

    static func statusItemWidth() -> CGFloat {
        preferredWidth
    }

    override func layout() {
        super.layout()
        let height = bounds.height
        let rowHeight: CGFloat = 10
        let rowGap: CGFloat = 0
        let blockHeight = rowHeight * 2 + rowGap
        let blockY = floor((height - blockHeight) / 2)
        let iconY = floor((height - Self.iconSize) / 2)
        let textX = Self.leadingPadding + Self.iconSize + Self.iconTextGap
        let valueX = textX + Self.arrowWidth + Self.arrowValueGap
        let valueWidth = max(0, bounds.width - valueX - Self.trailingPadding)

        iconView.frame = NSRect(x: Self.leadingPadding, y: iconY, width: Self.iconSize, height: Self.iconSize)
        upArrowLabel.frame = NSRect(x: textX, y: blockY + rowHeight + rowGap, width: Self.arrowWidth, height: rowHeight)
        downArrowLabel.frame = NSRect(x: textX, y: blockY, width: Self.arrowWidth, height: rowHeight)
        upValueLabel.frame = NSRect(x: valueX, y: blockY + rowHeight + rowGap, width: valueWidth, height: rowHeight)
        downValueLabel.frame = NSRect(x: valueX, y: blockY, width: valueWidth, height: rowHeight)
    }

    private func configure() {
        iconView.imageScaling = .scaleProportionallyDown
        upArrowLabel.textColor = .systemRed
        downArrowLabel.textColor = .systemBlue
        for label in [upArrowLabel, downArrowLabel, upValueLabel, downValueLabel] {
            label.font = Self.statusFont
            label.alignment = .left
            label.cell?.usesSingleLineMode = true
            label.cell?.lineBreakMode = .byClipping
            label.isBordered = false
            label.isBezeled = false
            label.drawsBackground = false
            label.isEditable = false
            label.isSelectable = false
            label.translatesAutoresizingMaskIntoConstraints = true
        }
        upValueLabel.textColor = .labelColor
        downValueLabel.textColor = .labelColor

        addSubview(iconView)
        addSubview(upArrowLabel)
        addSubview(downArrowLabel)
        addSubview(upValueLabel)
        addSubview(downValueLabel)
    }

    private static func formatRate(_ bytes: Int64) -> String {
        "\(bytes == 0 ? "0 KB" : rateFormatter.string(fromByteCount: bytes))/s"
    }
}

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    static let shared = StatusBarController()

    private var model: AppModel?
    private var openMainWindow: (() -> Void)?
    private var statusItem: NSStatusItem?
    private let statusMenu = NSMenu()
    private var cancellables = Set<AnyCancellable>()
    private weak var stackedSpeedView: StackedSpeedStatusView?

    private override init() {
        super.init()
        statusMenu.autoenablesItems = false
        statusMenu.delegate = self
    }

    func install(model: AppModel, openMainWindow: @escaping () -> Void, replaceOpenAction: Bool = true) {
        self.model = model
        if replaceOpenAction || self.openMainWindow == nil {
            self.openMainWindow = openMainWindow
        }

        updateStatusItemVisibility()
        bindModel(model)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu(menu)
    }

    private func bindModel(_ model: AppModel) {
        cancellables.removeAll()
        model.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateStatusItemVisibility()
                }
            }
            .store(in: &cancellables)
    }

    private func updateStatusItemVisibility() {
        guard let model else { return }
        if !model.settings.showStatusBarItem {
            // 用户可以完全隐藏状态栏入口；设置恢复后会重新创建 NSStatusItem。
            if let statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
                self.statusItem = nil
            }
            return
        }

        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.button?.target = self
            item.button?.action = #selector(showMenu)
            item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
            item.menu = statusMenu
            statusItem = item
        }

        statusItem?.menu = statusMenu
        updateButton()
    }

    private func updateButton() {
        guard let model, let button = statusItem?.button else { return }
        let title = model.statusBarTitleText
        let isStackedSpeed = model.settings.statusBarDisplayMode == .stackedSpeed
        statusItem?.length = statusItemLength(for: model)

        if isStackedSpeed {
            updateStackedSpeedButton(button, model: model)
            return
        }

        stackedSpeedView?.removeFromSuperview()
        stackedSpeedView = nil
        button.image = statusIcon(for: model)
        button.imageScaling = .scaleProportionallyDown
        button.imagePosition = title.isEmpty ? .imageOnly : .imageLeading
        button.alignment = .left
        button.cell?.usesSingleLineMode = true
        button.cell?.wraps = false
        button.cell?.lineBreakMode = .byClipping
        button.title = ""
        button.attributedTitle = attributedStatusTitle(title.isEmpty ? "" : " \(title)")
        button.toolTip = model.statusBarTooltipText
        button.setAccessibilityLabel("Chumen")
        button.setAccessibilityTitle(title.isEmpty ? "Chumen" : "Chumen \(title)")
    }

    private func updateStackedSpeedButton(_ button: NSStatusBarButton, model: AppModel) {
        button.image = nil
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.toolTip = model.statusBarTooltipText
        button.setAccessibilityLabel("Chumen")
        button.setAccessibilityTitle("Chumen \(model.statusBarStackedSpeedText.replacingOccurrences(of: "\n", with: " "))")

        let view: StackedSpeedStatusView
        if let existing = stackedSpeedView, existing.superview == button {
            view = existing
        } else {
            stackedSpeedView?.removeFromSuperview()
            view = StackedSpeedStatusView(frame: button.bounds)
            view.autoresizingMask = [.width, .height]
            button.addSubview(view)
            stackedSpeedView = view
        }

        view.frame = button.bounds
        view.update(icon: statusIcon(for: model), up: model.uploadSpeed, down: model.downloadSpeed)
    }

    private func statusIcon(for model: AppModel) -> NSImage {
        StatusBarIconFactory.image(for: statusDoorIconState(for: model))
    }

    private func statusDoorIconState(for model: AppModel) -> StatusBarDoorIconState {
        let tunIsActivelyRouting = model.isRunning && model.settings.enableTun && !model.tunRuntimeFailed
        if tunIsActivelyRouting {
            return .open
        }
        if model.systemProxyEnabled && !model.systemProxyRuntimeFailed {
            return .proxy
        }
        return .closed
    }

    private func attributedStatusTitle(_ title: String) -> NSAttributedString {
        guard !title.isEmpty else { return NSAttributedString(string: "") }
        return NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.labelColor
            ]
        )
    }

    private func statusItemLength(for model: AppModel) -> CGFloat {
        guard !model.statusBarTitleText.isEmpty else { return NSStatusItem.squareLength }
        switch model.settings.statusBarDisplayMode {
        case .speed, .traffic:
            return measuredStatusItemLength(for: model.statusBarTitleText, minimum: 68, maximum: 126)
        case .stackedSpeed:
            return StackedSpeedStatusView.statusItemWidth()
        case .custom:
            return measuredStatusItemLength(for: model.statusBarTitleText, minimum: 44, maximum: 136)
        case .statusAndSpeed:
            return measuredStatusItemLength(for: model.statusBarTitleText, minimum: 96, maximum: 180)
        case .appName, .status:
            return NSStatusItem.variableLength
        case .iconOnly:
            return NSStatusItem.squareLength
        }
    }

    private func measuredStatusItemLength(for title: String, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        let textWidth = attributedStatusTitle(title.isEmpty ? "" : " \(title)").size().width
        let iconAndPaddingWidth: CGFloat = 28
        return min(max(ceil(textWidth + iconAndPaddingWidth), minimum), maximum)
    }

    private func rebuildMenu(_ menu: NSMenu) {
        guard let model else { return }
        menu.removeAllItems()

        menu.addItem(menuItem(
            title: "\(model.isRunning ? model.t(.running) : model.t(.stopped)) · \(model.settings.mode.rawValue)",
            symbol: model.isRunning ? "checkmark.circle" : "pause.circle",
            enabled: false
        ))
        menu.addItem(menuItem(
            title: model.speedText.replacingOccurrences(of: "\n", with: " / "),
            symbol: "speedometer",
            enabled: false
        ))
        menu.addItem(.separator())

        menu.addItem(menuItem(
            title: model.t(.dashboard),
            symbol: "rectangle.grid.2x2",
            action: #selector(openWindowAction)
        ))
        menu.addItem(menuItem(
            title: model.isRunning ? model.t(.stop) : model.t(.start),
            symbol: model.isRunning ? "stop.fill" : "play.fill",
            action: #selector(toggleCore),
            enabled: !model.isCoreTransitioning
        ))
        menu.addItem(menuItem(
            title: model.t(.refresh),
            symbol: "arrow.clockwise",
            action: #selector(refreshAll)
        ))
        menu.addItem(.separator())

        menu.addItem(submenuItem(
            title: "\(model.t(.outboundMode)) (\(model.settings.mode.rawValue))",
            symbol: "arrow.triangle.branch",
            submenu: modeMenu(model)
        ))
        menu.addItem(submenuItem(
            title: model.t(.profiles),
            symbol: "doc.text",
            submenu: profilesMenu(model)
        ))
        menu.addItem(submenuItem(
            title: model.t(.proxies),
            symbol: "point.3.connected.trianglepath.dotted",
            submenu: proxiesMenu(model)
        ))
        menu.addItem(.separator())

        menu.addItem(menuItem(
            title: systemProxyMenuTitle(model),
            symbol: model.systemProxyRuntimeFailed ? "exclamationmark.triangle" : "network",
            action: #selector(toggleSystemProxy),
            state: systemProxyMenuState(model)
        ))
        menu.addItem(menuItem(
            title: tunMenuTitle(model),
            symbol: isTunIneffective(model) ? "exclamationmark.triangle" : "shield",
            action: #selector(toggleTun),
            enabled: !model.isCoreTransitioning,
            state: tunMenuState(model)
        ))
        menu.addItem(.separator())

        menu.addItem(submenuItem(
            title: model.t(.connections),
            symbol: "link",
            submenu: connectionsMenu(model)
        ))
        menu.addItem(submenuItem(
            title: model.t(.coreTools),
            symbol: "terminal",
            submenu: coreToolsMenu(model)
        ))
        menu.addItem(menuItem(
            title: model.t(.openDataDirectory),
            symbol: "folder",
            action: #selector(openDataDirectory)
        ))
        menu.addItem(submenuItem(
            title: model.t(.more),
            symbol: "ellipsis.circle",
            submenu: moreMenu(model)
        ))
        menu.addItem(.separator())

        let quit = menuItem(title: model.t(.quit), symbol: "power", action: #selector(quit))
        quit.keyEquivalent = "q"
        quit.keyEquivalentModifierMask = [.command]
        menu.addItem(quit)
    }

    private func modeMenu(_ model: AppModel) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        for mode in ProxyMode.allCases {
            menu.addItem(menuItem(
                title: mode.rawValue,
                action: #selector(applyMode),
                state: model.settings.mode == mode ? .on : .off,
                representedObject: mode.rawValue
            ))
        }
        return menu
    }

    private func profilesMenu(_ model: AppModel) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let activeProfileID = model.profileLibrary.activeProfileID
        let switchableProfiles = model.profileLibrary.profiles.filter { profile in
            guard let activeProfileID else { return true }
            return profile.id != activeProfileID
        }

        if let active = model.activeProfile {
            menu.addItem(menuItem(
                title: "\(model.t(.activeProfile)): \(active.name)",
                enabled: false
            ))
        } else {
            menu.addItem(menuItem(title: model.t(.unknown), enabled: false))
        }

        menu.addItem(menuItem(
            title: model.t(.update),
            symbol: "arrow.clockwise",
            action: #selector(updateActiveProfile),
            enabled: model.activeProfile?.remoteURL != nil
        ))

        if model.profileLibrary.profiles.isEmpty {
            menu.addItem(.separator())
            menu.addItem(menuItem(title: "0 \(model.t(.profiles))", enabled: false))
        } else if !switchableProfiles.isEmpty {
            menu.addItem(.separator())
            for profile in switchableProfiles {
                menu.addItem(menuItem(
                    title: profile.name,
                    action: #selector(activateProfile),
                    representedObject: profile.id
                ))
            }
        }
        return menu
    }

    private func proxiesMenu(_ model: AppModel) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(menuItem(
            title: model.t(.refreshProxies),
            symbol: "arrow.triangle.2.circlepath",
            action: #selector(refreshProxies)
        ))
        menu.addItem(.separator())

        if model.proxyGroups.isEmpty {
            menu.addItem(menuItem(title: "0 \(model.t(.groups))", enabled: false))
            return menu
        }

        for group in model.proxyGroups {
            let groupMenu = NSMenu()
            groupMenu.autoenablesItems = false
            groupMenu.addItem(menuItem(
                title: model.t(.delayTest),
                symbol: "speedometer",
                action: #selector(testGroupDelay),
                representedObject: group.name
            ))
            groupMenu.addItem(menuItem(
                title: model.t(.clear),
                symbol: "pin.slash",
                action: #selector(clearProxySelection),
                representedObject: group.name
            ))
            groupMenu.addItem(.separator())

            for option in group.options {
                groupMenu.addItem(menuItem(
                    title: option,
                    action: #selector(selectProxy),
                    state: option == group.selected ? .on : .off,
                    representedObject: ProxySelection(groupName: group.name, optionName: option)
                ))
            }

            menu.addItem(submenuItem(
                title: "\(group.name) (\(group.selected))",
                symbol: "point.3.connected.trianglepath.dotted",
                submenu: groupMenu
            ))
        }
        return menu
    }

    private func connectionsMenu(_ model: AppModel) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(menuItem(title: "\(model.connections.count) \(model.t(.activeConnections))", enabled: false))
        menu.addItem(menuItem(
            title: model.t(.refreshConnections),
            symbol: "arrow.triangle.2.circlepath",
            action: #selector(refreshConnections)
        ))
        menu.addItem(menuItem(
            title: model.t(.closeAll),
            symbol: "xmark.circle",
            action: #selector(closeAllConnections),
            enabled: !model.connections.isEmpty
        ))
        return menu
    }

    private func coreToolsMenu(_ model: AppModel) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(menuItem(
            title: model.t(.reloadRuntimeConfig),
            symbol: "arrow.clockwise.circle",
            action: #selector(reloadRuntimeConfig)
        ))
        menu.addItem(menuItem(
            title: model.t(.flushFakeIP),
            symbol: "trash",
            action: #selector(flushFakeIP)
        ))
        menu.addItem(menuItem(
            title: model.t(.flushDNS),
            symbol: "trash.circle",
            action: #selector(flushDNS)
        ))
        menu.addItem(menuItem(
            title: model.t(.updateGeo),
            symbol: "globe",
            action: #selector(updateGeo)
        ))
        menu.addItem(menuItem(
            title: model.t(.openDashboard),
            symbol: "safari",
            action: #selector(openDashboard)
        ))
        return menu
    }

    private func moreMenu(_ model: AppModel) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(menuItem(
            title: model.t(.clearLogs),
            symbol: "trash",
            action: #selector(clearLogs)
        ))
        menu.addItem(menuItem(
            title: model.t(.restartApplication),
            symbol: "arrow.clockwise",
            action: #selector(restartApplication)
        ))
        return menu
    }

    private func menuItem(
        title: String,
        symbol: String? = nil,
        action: Selector? = nil,
        enabled: Bool = true,
        state: NSControl.StateValue = .off,
        representedObject: Any? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = action == nil ? nil : self
        item.isEnabled = enabled
        item.state = state
        item.representedObject = representedObject
        if let symbol, let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            image.isTemplate = true
            item.image = image
        }
        return item
    }

    private func submenuItem(title: String, symbol: String, submenu: NSMenu) -> NSMenuItem {
        let item = menuItem(title: title, symbol: symbol)
        item.submenu = submenu
        return item
    }

    private func tunMenuTitle(_ model: AppModel) -> String {
        if isTunIneffective(model) {
            return "\(model.t(.tunMode)) (\(model.tunRuntimeFailureTitle))"
        }
        return model.t(.tunMode)
    }

    private func tunMenuState(_ model: AppModel) -> NSControl.StateValue {
        if model.tunRuntimeFailed {
            return .mixed
        }
        return model.settings.enableTun ? .on : .off
    }

    private func isTunIneffective(_ model: AppModel) -> Bool {
        model.tunRuntimeFailed
    }

    private func systemProxyMenuTitle(_ model: AppModel) -> String {
        if model.systemProxyRuntimeFailed {
            return "\(model.t(.systemProxy)) (\(model.t(.failed)))"
        }
        return model.t(.systemProxy)
    }

    private func systemProxyMenuState(_ model: AppModel) -> NSControl.StateValue {
        if model.systemProxyRuntimeFailed {
            return .mixed
        }
        return model.systemProxyEnabled ? .on : .off
    }

    @objc private func showMenu() {
        guard let statusItem else { return }
        statusItem.menu = statusMenu
        statusItem.button?.performClick(nil)
    }

    @objc private func openWindowAction() {
        openMainWindow?()
    }

    @objc private func toggleCore() {
        guard let model else { return }
        model.isRunning ? model.stop() : model.start()
    }

    @objc private func refreshAll() {
        guard let model else { return }
        Task { await model.refreshAll() }
    }

    @objc private func refreshProxies() {
        guard let model else { return }
        Task { await model.refreshProxies() }
    }

    @objc private func refreshConnections() {
        guard let model else { return }
        Task { await model.refreshConnections() }
    }

    @objc private func applyMode(_ sender: NSMenuItem) {
        guard let model, let rawMode = sender.representedObject as? String, let mode = ProxyMode(rawValue: rawMode) else { return }
        model.applyMode(mode)
    }

    @objc private func activateProfile(_ sender: NSMenuItem) {
        guard let model, let profileID = sender.representedObject as? String else { return }
        guard let profile = model.profileLibrary.profiles.first(where: { $0.id == profileID }) else { return }
        model.activateProfile(profile)
    }

    @objc private func updateActiveProfile() {
        model?.updateActiveProfile()
    }

    @objc private func selectProxy(_ sender: NSMenuItem) {
        guard let model, let selection = sender.representedObject as? ProxySelection else { return }
        guard let group = model.proxyGroups.first(where: { $0.name == selection.groupName }) else { return }
        model.selectProxy(group: group, name: selection.optionName)
    }

    @objc private func testGroupDelay(_ sender: NSMenuItem) {
        guard let model, let groupName = sender.representedObject as? String else { return }
        guard let group = model.proxyGroups.first(where: { $0.name == groupName }) else { return }
        model.testGroupDelay(group)
    }

    @objc private func clearProxySelection(_ sender: NSMenuItem) {
        guard let model, let groupName = sender.representedObject as? String else { return }
        guard let group = model.proxyGroups.first(where: { $0.name == groupName }) else { return }
        model.clearProxySelection(group)
    }

    @objc private func toggleSystemProxy() {
        model?.toggleSystemProxy()
    }

    @objc private func toggleTun() {
        guard let model else { return }
        model.setTunEnabled(!model.settings.enableTun)
    }

    @objc private func closeAllConnections() {
        model?.closeAllConnections()
    }

    @objc private func reloadRuntimeConfig() {
        model?.reloadRuntimeConfigViaAPI()
    }

    @objc private func flushFakeIP() {
        model?.flushFakeIPCache()
    }

    @objc private func flushDNS() {
        model?.flushDNSCache()
    }

    @objc private func updateGeo() {
        model?.updateConfigGeo()
    }

    @objc private func openDashboard() {
        model?.openDashboardURL()
    }

    @objc private func openDataDirectory() {
        model?.openDataDirectory()
    }

    @objc private func clearLogs() {
        model?.clearLogs()
    }

    @objc private func restartApplication() {
        model?.restartApplication()
    }

    @objc private func quit() {
        model?.quit()
    }
}

private final class ProxySelection: NSObject {
    let groupName: String
    let optionName: String

    init(groupName: String, optionName: String) {
        self.groupName = groupName
        self.optionName = optionName
        super.init()
    }
}
