import AppKit

enum GuidedWorkbenchSection: String, CaseIterable {
    case home
    case dictation
    case meetings
    case voice
    case library
    case personalization
    case models
    case settings

    var title: String {
        switch self {
        case .home: "Home"
        case .dictation: "Dictation"
        case .meetings: "Meetings"
        case .voice: "Voice Studio"
        case .library: "Library"
        case .personalization: "Personalization"
        case .models: "Models"
        case .settings: "Settings"
        }
    }

    var subtitle: String {
        switch self {
        case .home: "Status and setup"
        case .dictation: "Speak into any app"
        case .meetings: "Capture and review"
        case .voice: "Record and create audio"
        case .library: "Transcripts and imports"
        case .personalization: "Corrections and snippets"
        case .models: "Local speech engines"
        case .settings: "General, privacy, checkup"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .dictation: "waveform"
        case .meetings: "person.2.wave.2"
        case .voice: "waveform.badge.mic"
        case .library: "books.vertical"
        case .personalization: "sparkles"
        case .models: "cpu"
        case .settings: "command"
        }
    }

    var group: String {
        switch self {
        case .home, .dictation, .meetings, .voice: "Workspace"
        case .library, .personalization: "Library"
        case .models, .settings: "System"
        }
    }

    var subpages: [String] {
        switch self {
        case .home: ["Overview"]
        case .dictation: ["Live", "Settings"]
        case .meetings: ["Capture & Review"]
        case .voice: ["Record & Create"]
        case .library: ["History", "Audio File"]
        case .personalization: ["Learning", "Vocabulary", "Snippets", "Private Apps", "Confidence", "Dictionary"]
        case .models: ["Installed & Available"]
        case .settings: ["General", "Dictation", "Intelligence", "Privacy", "Checkup", "Pawprints", "Support", "About"]
        }
    }
}

struct GuidedWorkbenchRoute: Equatable {
    let section: GuidedWorkbenchSection
    let subpage: Int

    init(section: GuidedWorkbenchSection, subpage: Int = 0) {
        self.section = section
        self.subpage = min(max(0, subpage), max(0, section.subpages.count - 1))
    }
}

enum GuidedWorkbenchSurfaceSizing {
    case fill
    case top(NSSize)
    case scroll(NSSize)
}

struct GuidedWorkbenchSurface {
    let view: NSView
    let sizing: GuidedWorkbenchSurfaceSizing
}

@MainActor
final class GuidedWorkbenchWindowController: NSWindowController, NSWindowDelegate {
    var onRouteChange: ((GuidedWorkbenchRoute) -> GuidedWorkbenchSurface?)?
    var onCanClose: (() -> Bool)?

    private let contentHost = NSView()
    private let tabRail = NSView()
    private let sectionLabel = kikiLabel("WORKSPACE", size: 10, weight: .bold, color: KikiPalette.accentText)
    private let titleLabel = kikiLabel("Home", size: 15, weight: .semibold)
    private let readinessLabel = kikiLabel("● Ready", size: 11, weight: .semibold, color: KikiPalette.accentText)
    private let subnavigation = KikiFocusableSegmentedControl()
    private var navButtons: [GuidedWorkbenchSection: WorkbenchNavigationButton] = [:]
    private var currentWrapper: NSView?
    private var tabRailHeightConstraint: NSLayoutConstraint?
    private var shouldCenterOnFirstShow = true
    private var dictationState: DictationState = .noModel
    private var checkupSnapshot: KikiCheckupSnapshot?
    private(set) var route = GuidedWorkbenchRoute(section: .home)

    private static let compactMinimumSize = NSSize(width: 900, height: 650)

    init() {
        let visibleSize = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1_440, height: 900)
        let initialSize = NSSize(
            width: min(1_240, max(1_020, visibleSize.width * 0.86)),
            height: min(840, max(720, visibleSize.height * 0.90))
        )
        let window = WorkbenchWindow(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Kiki Workbench"
        window.appearance = Settings.appearanceMode.appearance
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.minSize = Self.compactMinimumSize
        window.isReleasedWhenClosed = false
        let frameAutosaveName = "KikiGuidedWorkbenchAdaptiveV4"
        let restoredSavedFrame = window.setFrameUsingName(frameAutosaveName)
        if let screen = window.screen ?? NSScreen.main {
            window.setFrame(window.constrainFrameRect(window.frame, to: screen), display: false)
        }
        window.setFrameAutosaveName(frameAutosaveName)
        super.init(window: window)
        shouldCenterOnFirstShow = !restoredSavedFrame
        window.delegate = self
        buildContent()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(section: GuidedWorkbenchSection = .home, subpage: Int = 0) {
        select(GuidedWorkbenchRoute(section: section, subpage: subpage))
        showWindow(nil)
        if shouldCenterOnFirstShow {
            window?.center()
            shouldCenterOnFirstShow = false
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func select(_ route: GuidedWorkbenchRoute) {
        self.route = route
        updateNavigation()
        reloadSurface()
        applyWindowPolicy(for: route.section)
    }

    func isShowing(section: GuidedWorkbenchSection, subpage: Int? = nil) -> Bool {
        guard window?.isVisible == true, route.section == section else { return false }
        return subpage.map { route.subpage == $0 } ?? true
    }

    func updateDictationState(_ state: DictationState) {
        dictationState = state
        updateReadinessStatus()
    }

    func updateCheckupSnapshot(_ snapshot: KikiCheckupSnapshot) {
        checkupSnapshot = snapshot
        updateReadinessStatus()
    }

    private func updateReadinessStatus() {
        let state = dictationState
        switch state {
        case .noModel:
            readinessLabel.stringValue = "● Model unavailable"
            readinessLabel.textColor = KikiPalette.khaki
        case .loadingModel:
            readinessLabel.stringValue = "● Loading model"
            readinessLabel.textColor = KikiPalette.khaki
        case .idle:
            if checkupSnapshot?.isReady == true {
                readinessLabel.stringValue = "● Ready"
                readinessLabel.textColor = KikiPalette.accentText
            } else {
                readinessLabel.stringValue = "● Checkup incomplete"
                readinessLabel.textColor = KikiPalette.khaki
            }
        case .recording:
            readinessLabel.stringValue = "● Listening"
            readinessLabel.textColor = KikiPalette.accentText
        case .transcribing:
            readinessLabel.stringValue = "● Transcribing"
            readinessLabel.textColor = KikiPalette.khaki
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        onCanClose?() ?? true
    }

    func windowDidResize(_ notification: Notification) {
        guard let scroll = currentWrapper as? NSScrollView,
              let document = scroll.documentView as? WorkbenchScrollDocument else { return }
        document.updateViewport(scroll.contentSize)
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        if route.section == .home {
            (currentWrapper as? GuidedWorkbenchHomeView)?.prepareForAvailableWidth(frameSize.width - 258)
        }
        return frameSize
    }

    private func buildContent() {
        guard let content = window?.contentView else { return }
        let backdrop = KikiBackdropView()
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        let sidebar = makeSidebar()
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        let main = makeMainArea()
        main.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(backdrop)
        content.addSubview(sidebar)
        content.addSubview(main)
        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            backdrop.topAnchor.constraint(equalTo: content.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            sidebar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: content.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 258),
            main.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            main.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            main.topAnchor.constraint(equalTo: content.topAnchor),
            main.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
    }

    private func makeSidebar() -> NSView {
        let sidebar = KikiSidebarView()
        sidebar.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.sidebar")

        let portrait = KikiCircularPortraitView()
        let brandTitle = kikiLabel("Kiki", size: 19, weight: .bold)
        let brandDetail = kikiLabel("VOICE INTELLIGENCE", size: 10, weight: .semibold, color: KikiPalette.tertiaryText)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        let releaseDetail = kikiLabel("RELEASE \(version) · BUILD \(build)", size: 10, weight: .medium, color: KikiPalette.khaki)
        releaseDetail.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.release")
        let brandCopy = NSStackView(views: [brandTitle, brandDetail, releaseDetail])
        brandCopy.orientation = .vertical
        brandCopy.alignment = .leading
        brandCopy.spacing = 2
        let brand = NSStackView(views: [portrait, brandCopy])
        brand.orientation = .horizontal
        brand.alignment = .centerY
        brand.spacing = 11

        let workflowLabel = kikiLabel("CHOOSE A WORKFLOW", size: 10, weight: .bold, color: KikiPalette.accentText)
        let navigation = NSStackView()
        navigation.orientation = .vertical
        navigation.alignment = .leading
        navigation.spacing = 4

        var previousGroup: String?
        for section in GuidedWorkbenchSection.allCases {
            if previousGroup != section.group {
                let group = kikiLabel(section.group.uppercased(), size: 10, weight: .bold, color: KikiPalette.tertiaryText)
                group.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.group.\(section.group.lowercased())")
                navigation.addArrangedSubview(group)
                navigation.setCustomSpacing(7, after: group)
                previousGroup = section.group
            }
            let button = WorkbenchNavigationButton(section: section, target: self, action: #selector(navigate(_:)))
            button.tag = GuidedWorkbenchSection.allCases.firstIndex(of: section) ?? 0
            button.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.nav.\(section.rawValue)")
            navButtons[section] = button
            navigation.addArrangedSubview(button)
            button.widthAnchor.constraint(equalTo: navigation.widthAnchor).isActive = true
        }

        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let document = KikiFlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        navigation.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(navigation)
        scroll.documentView = document
        NSLayoutConstraint.activate([
            navigation.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            navigation.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            navigation.topAnchor.constraint(equalTo: document.topAnchor),
            navigation.bottomAnchor.constraint(equalTo: document.bottomAnchor),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
        ])

        for view in [brand, workflowLabel, scroll] { view.translatesAutoresizingMaskIntoConstraints = false }
        sidebar.addSubview(brand)
        sidebar.addSubview(workflowLabel)
        sidebar.addSubview(scroll)
        NSLayoutConstraint.activate([
            portrait.widthAnchor.constraint(equalToConstant: 48),
            portrait.heightAnchor.constraint(equalToConstant: 48),
            brand.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 20),
            brand.trailingAnchor.constraint(lessThanOrEqualTo: sidebar.trailingAnchor, constant: -16),
            brand.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 50),
            workflowLabel.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 20),
            workflowLabel.topAnchor.constraint(equalTo: brand.bottomAnchor, constant: 22),
            scroll.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 14),
            scroll.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -14),
            scroll.topAnchor.constraint(equalTo: workflowLabel.bottomAnchor, constant: 12),
            scroll.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -16),
        ])
        return sidebar
    }

    private func makeMainArea() -> NSView {
        let main = NSView()
        let contextBar = NSView()
        contextBar.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.context-bar")
        contextBar.wantsLayer = true
        contextBar.layer?.borderWidth = 1
        contextBar.layer?.borderColor = KikiPalette.stroke.cgColor
        contextBar.layer?.backgroundColor = KikiPalette.surface.cgColor

        let contextCopy = NSStackView(views: [sectionLabel, titleLabel])
        contextCopy.orientation = .horizontal
        contextCopy.alignment = .centerY
        contextCopy.spacing = 10
        let localLabel = kikiLabel("FULLY LOCAL", size: 10, weight: .bold, color: KikiPalette.tertiaryText)
        let status = NSStackView(views: [readinessLabel, localLabel])
        status.orientation = .horizontal
        status.alignment = .centerY
        status.spacing = 13
        contextCopy.translatesAutoresizingMaskIntoConstraints = false
        status.translatesAutoresizingMaskIntoConstraints = false
        contextBar.addSubview(contextCopy)
        contextBar.addSubview(status)

        subnavigation.trackingMode = .selectOne
        subnavigation.segmentStyle = .texturedRounded
        subnavigation.selectedSegmentBezelColor = KikiPalette.accent
        subnavigation.target = self
        subnavigation.action = #selector(subnavigationChanged)
        subnavigation.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.subnavigation")

        tabRail.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.tab-rail")
        tabRail.wantsLayer = true
        tabRail.layer?.backgroundColor = KikiPalette.sidebar.withAlphaComponent(0.56).cgColor
        tabRail.layer?.borderWidth = 1
        tabRail.layer?.borderColor = KikiPalette.stroke.cgColor
        subnavigation.translatesAutoresizingMaskIntoConstraints = false
        tabRail.addSubview(subnavigation)

        contentHost.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.content")
        contentHost.translatesAutoresizingMaskIntoConstraints = false
        contextBar.translatesAutoresizingMaskIntoConstraints = false
        tabRail.translatesAutoresizingMaskIntoConstraints = false
        main.addSubview(contextBar)
        main.addSubview(tabRail)
        main.addSubview(contentHost)
        let tabRailHeightConstraint = tabRail.heightAnchor.constraint(equalToConstant: 44)
        self.tabRailHeightConstraint = tabRailHeightConstraint
        NSLayoutConstraint.activate([
            contextBar.leadingAnchor.constraint(equalTo: main.leadingAnchor),
            contextBar.trailingAnchor.constraint(equalTo: main.trailingAnchor),
            contextBar.topAnchor.constraint(equalTo: main.topAnchor),
            contextBar.heightAnchor.constraint(equalToConstant: 74),
            contextCopy.leadingAnchor.constraint(equalTo: contextBar.leadingAnchor, constant: 24),
            contextCopy.bottomAnchor.constraint(equalTo: contextBar.bottomAnchor, constant: -14),
            status.trailingAnchor.constraint(equalTo: contextBar.trailingAnchor, constant: -24),
            status.centerYAnchor.constraint(equalTo: contextCopy.centerYAnchor),
            tabRail.leadingAnchor.constraint(equalTo: main.leadingAnchor),
            tabRail.trailingAnchor.constraint(equalTo: main.trailingAnchor),
            tabRail.topAnchor.constraint(equalTo: contextBar.bottomAnchor),
            tabRailHeightConstraint,
            subnavigation.leadingAnchor.constraint(equalTo: tabRail.leadingAnchor, constant: 22),
            subnavigation.centerYAnchor.constraint(equalTo: tabRail.centerYAnchor),
            subnavigation.trailingAnchor.constraint(lessThanOrEqualTo: tabRail.trailingAnchor, constant: -22),
            contentHost.leadingAnchor.constraint(equalTo: main.leadingAnchor),
            contentHost.trailingAnchor.constraint(equalTo: main.trailingAnchor),
            contentHost.topAnchor.constraint(equalTo: tabRail.bottomAnchor),
            contentHost.bottomAnchor.constraint(equalTo: main.bottomAnchor),
        ])
        return main
    }

    private func updateNavigation() {
        navButtons.forEach { $0.value.isSelectedPage = $0.key == route.section }
        sectionLabel.stringValue = route.section.group.uppercased()
        titleLabel.stringValue = route.section.title

        let labels = route.section.subpages
        subnavigation.segmentCount = labels.count
        for (index, label) in labels.enumerated() {
            subnavigation.setLabel(label, forSegment: index)
            subnavigation.setWidth(0, forSegment: index)
        }
        subnavigation.selectedSegment = route.subpage
        let hasSubnavigation = labels.count > 1
        subnavigation.isHidden = !hasSubnavigation
        tabRail.isHidden = !hasSubnavigation
        tabRailHeightConstraint?.constant = hasSubnavigation ? 44 : 0
    }

    private func reloadSurface() {
        guard let surface = onRouteChange?(route) else { return }
        currentWrapper?.removeFromSuperview()
        surface.view.removeFromSuperview()

        switch surface.sizing {
        case .fill:
            surface.view.translatesAutoresizingMaskIntoConstraints = false
            contentHost.addSubview(surface.view)
            NSLayoutConstraint.activate([
                surface.view.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor),
                surface.view.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor),
                surface.view.topAnchor.constraint(equalTo: contentHost.topAnchor),
                surface.view.bottomAnchor.constraint(equalTo: contentHost.bottomAnchor),
            ])
            currentWrapper = surface.view
        case let .top(size):
            let scroll = KikiScrollView()
            scroll.fillsBackground = false
            scroll.hasVerticalScroller = true
            scroll.hasHorizontalScroller = false
            let document = WorkbenchScrollDocument(
                hostedView: surface.view,
                preferredSize: size,
                centersVertically: false
            )
            scroll.documentView = document
            scroll.translatesAutoresizingMaskIntoConstraints = false
            contentHost.addSubview(scroll)
            NSLayoutConstraint.activate([
                scroll.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor),
                scroll.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor),
                scroll.topAnchor.constraint(equalTo: contentHost.topAnchor),
                scroll.bottomAnchor.constraint(equalTo: contentHost.bottomAnchor),
            ])
            contentHost.layoutSubtreeIfNeeded()
            document.updateViewport(scroll.contentSize)
            currentWrapper = scroll
        case let .scroll(size):
            let scroll = KikiScrollView()
            scroll.fillsBackground = false
            scroll.hasVerticalScroller = true
            scroll.hasHorizontalScroller = false
            let document = WorkbenchScrollDocument(hostedView: surface.view, preferredSize: size)
            scroll.documentView = document
            scroll.translatesAutoresizingMaskIntoConstraints = false
            contentHost.addSubview(scroll)
            NSLayoutConstraint.activate([
                scroll.leadingAnchor.constraint(equalTo: contentHost.leadingAnchor),
                scroll.trailingAnchor.constraint(equalTo: contentHost.trailingAnchor),
                scroll.topAnchor.constraint(equalTo: contentHost.topAnchor),
                scroll.bottomAnchor.constraint(equalTo: contentHost.bottomAnchor),
            ])
            contentHost.layoutSubtreeIfNeeded()
            document.updateViewport(scroll.contentSize)
            currentWrapper = scroll
        }
        contentHost.layoutSubtreeIfNeeded()
        updateRouteKeyViewBoundary(for: surface.view)
    }

    private func updateRouteKeyViewBoundary(for surfaceView: NSView) {
        // AppKit keeps stale key-loop links when a route replaces the complete
        // content subtree. Keep an explicit, live visual-order sequence instead
        // of asking that cached loop to reconnect itself.
        var routeKeyViews = validKeyViews(in: surfaceView)
        if route.section == .home,
           let primary = view(in: surfaceView, identifier: "kiki.workbench.home.dictation"),
           let index = routeKeyViews.firstIndex(where: { $0 === primary }) {
            routeKeyViews.remove(at: index)
            routeKeyViews.insert(primary, at: 0)
        }
        if !subnavigation.isHidden,
           subnavigation.acceptsFirstResponder,
           !routeKeyViews.contains(where: { $0 === subnavigation }) {
            routeKeyViews.insert(subnavigation, at: 0)
        }
        (window as? WorkbenchWindow)?.setRouteKeyViewBoundary(
            sidebarNavigation: GuidedWorkbenchSection.allCases.compactMap { navButtons[$0] },
            routeKeyViews: routeKeyViews,
            defaultSidebarOrigin: navButtons[route.section]
        )
    }

    private func view(in root: NSView, identifier: String) -> NSView? {
        if root.identifier?.rawValue == identifier {
            return root
        }
        for child in root.subviews {
            if let match = view(in: child, identifier: identifier) {
                return match
            }
        }
        return nil
    }

    private func validKeyViews(in root: NSView) -> [NSView] {
        var result: [NSView] = []
        func visit(_ view: NSView) {
            guard !view.isHidden, view.alphaValue > 0.01 else { return }
            if view !== root,
               view.acceptsFirstResponder,
               (view as? NSControl)?.isEnabled != false {
                result.append(view)
            }
            for child in view.subviews {
                visit(child)
            }
        }
        visit(root)
        return result.sorted { lhs, rhs in
            let left = lhs.convert(lhs.bounds, to: nil)
            let right = rhs.convert(rhs.bounds, to: nil)
            if abs(left.maxY - right.maxY) > 6 {
                return left.maxY > right.maxY
            }
            return left.minX < right.minX
        }
    }

    private func applyWindowPolicy(for section: GuidedWorkbenchSection) {
        guard let window else { return }
        let desired: NSSize
        switch section {
        case .home, .dictation, .models, .settings:
            desired = Self.compactMinimumSize
        case .meetings, .voice:
            desired = NSSize(width: 1_100, height: 780)
        case .library:
            desired = NSSize(width: 1_160, height: 720)
        case .personalization:
            desired = NSSize(width: 1_200, height: 780)
        }

        let screen = window.screen ?? NSScreen.main
        let available = screen?.visibleFrame.size ?? desired
        let minimum = NSSize(
            width: min(desired.width, available.width),
            height: min(desired.height, available.height)
        )
        window.minSize = minimum

        guard window.frame.width + 0.5 < minimum.width || window.frame.height + 0.5 < minimum.height else { return }
        var frame = window.frame
        let previousTop = frame.maxY
        frame.size.width = max(frame.width, minimum.width)
        frame.size.height = max(frame.height, minimum.height)
        frame.origin.y = previousTop - frame.height
        if let screen {
            frame = window.constrainFrameRect(frame, to: screen)
        }
        window.setFrame(frame, display: true)
    }

    @objc private func navigate(_ sender: WorkbenchNavigationButton) {
        guard GuidedWorkbenchSection.allCases.indices.contains(sender.tag) else { return }
        let destination = GuidedWorkbenchSection.allCases[sender.tag]
        let currentEvent = NSApp.currentEvent
        let isMouseNavigation = currentEvent?.window === window
            && (currentEvent?.type == .leftMouseDown || currentEvent?.type == .leftMouseUp)
        (window as? WorkbenchWindow)?.setPendingSidebarOrigin(
            sender,
            isMouseNavigation: isMouseNavigation
        )
        select(GuidedWorkbenchRoute(section: destination))
    }

    @objc private func subnavigationChanged() {
        select(GuidedWorkbenchRoute(section: route.section, subpage: subnavigation.selectedSegment))
    }

}

enum WorkbenchTabTraversal: Equatable {
    case forward
    case reverse

    static func direction(for modifiers: NSEvent.ModifierFlags) -> WorkbenchTabTraversal? {
        let relevant = modifiers.intersection([.shift, .control, .option, .command])
        if relevant.isEmpty || relevant == [.option] { return .forward }
        if relevant == [.shift] || relevant == [.shift, .option] { return .reverse }
        return nil
    }
}

@MainActor
final class WorkbenchWindow: NSWindow {
    private var sidebarNavigation: [NSView] = []
    private var routeKeyViews: [NSView] = []
    private weak var defaultSidebarOrigin: NSView?
    private weak var pendingSidebarOrigin: NSView?
    private weak var reverseBoundaryOrigin: NSView?

    func setRouteKeyViewBoundary(
        sidebarNavigation: [NSView],
        routeKeyViews: [NSView],
        defaultSidebarOrigin: NSView?
    ) {
        self.sidebarNavigation = sidebarNavigation
        self.routeKeyViews = routeKeyViews
        self.defaultSidebarOrigin = defaultSidebarOrigin
        reverseBoundaryOrigin = nil
    }

    func setPendingSidebarOrigin(_ sender: NSView, isMouseNavigation: Bool) {
        let liveOrigin = firstResponder as? NSView
        let origin: NSView
        if isMouseNavigation {
            makeFirstResponder(sender)
            origin = sender
        } else if let liveOrigin,
                  sidebarNavigation.contains(where: { $0 === liveOrigin }) {
            origin = liveOrigin
        } else {
            origin = sender
        }
        pendingSidebarOrigin = origin
        reverseBoundaryOrigin = nil
    }

    @discardableResult
    func performRouteTraversal(_ traversal: WorkbenchTabTraversal) -> Bool {
        let available = routeKeyViews.filter(isAvailableRouteKeyView)
        guard !available.isEmpty else { return false }
        let liveResponder = logicalFirstResponder()

        switch traversal {
        case .forward:
            let sidebarOrigin: NSView? = if let pendingSidebarOrigin {
                pendingSidebarOrigin
            } else if let liveResponder,
                      sidebarNavigation.contains(where: { $0 === liveResponder }) {
                liveResponder
            } else {
                nil
            }
            if let sidebarOrigin {
                pendingSidebarOrigin = nil
                if focus(available[0]) {
                    reverseBoundaryOrigin = sidebarOrigin
                    return true
                }
            }

            guard let liveResponder,
                  let index = available.firstIndex(where: { $0 === liveResponder }) else {
                return false
            }
            if available.indices.contains(index + 1) {
                return focus(available[index + 1])
            }
            if let origin = reverseBoundaryOrigin ?? defaultSidebarOrigin,
               focus(origin) {
                reverseBoundaryOrigin = nil
                return true
            }

        case .reverse:
            pendingSidebarOrigin = nil
            guard let liveResponder,
                  let index = available.firstIndex(where: { $0 === liveResponder }) else {
                return false
            }
            if index > 0 {
                return focus(available[index - 1])
            }
            if let origin = reverseBoundaryOrigin ?? defaultSidebarOrigin,
               focus(origin) {
                reverseBoundaryOrigin = nil
                return true
            }
        }
        return false
    }

    private func logicalFirstResponder() -> NSView? {
        guard let responder = firstResponder as? NSView else { return nil }
        if let fieldEditor = responder as? NSTextView,
           fieldEditor.isFieldEditor,
           let owner = fieldEditor.delegate as? NSView {
            return owner
        }
        return responder
    }

    private func isAvailableRouteKeyView(_ view: NSView) -> Bool {
        guard view.window === self,
              (view as? NSControl)?.isEnabled != false else { return false }
        var candidate: NSView? = view
        while let current = candidate {
            if current.isHidden || current.alphaValue <= 0.01 { return false }
            candidate = current.superview
        }
        return true
    }

    private func focus(_ view: NSView) -> Bool {
        guard makeFirstResponder(view) else { return false }
        view.scrollToVisible(view.bounds)
        return true
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            pendingSidebarOrigin = nil
            reverseBoundaryOrigin = nil
        }

        if event.type == .keyDown, event.keyCode == 48 {
            let traversal = WorkbenchTabTraversal.direction(for: event.modifierFlags)
            if let traversal,
               performRouteTraversal(traversal) {
                return
            }
            if traversal == nil {
                reverseBoundaryOrigin = nil
            }
        }
        super.sendEvent(event)
    }
}

@MainActor
private final class WorkbenchNavigationButton: NSButton {
    var isSelectedPage = false { didSet { updateStyle() } }
    private var showsKeyboardFocus = false
    private let keyboardFocusLayer = CAShapeLayer()
    private let symbolView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let chevronView = NSImageView()

    init(section: GuidedWorkbenchSection, target: AnyObject?, action: Selector?) {
        super.init(frame: .zero)
        title = ""
        isBordered = false
        focusRingType = .none
        self.target = target
        self.action = action
        toolTip = section.subtitle
        setAccessibilityLabel(section.title)
        setAccessibilityHelp(section.subtitle)
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.cornerCurve = .continuous
        keyboardFocusLayer.fillColor = NSColor.clear.cgColor
        keyboardFocusLayer.strokeColor = KikiPalette.accentText.cgColor
        keyboardFocusLayer.lineWidth = 1.5
        keyboardFocusLayer.isHidden = true
        keyboardFocusLayer.name = "kiki.workbench-nav.keyboard-focus"
        layer?.addSublayer(keyboardFocusLayer)

        symbolView.image = NSImage(systemSymbolName: section.symbol, accessibilityDescription: section.title)
        symbolView.imageScaling = .scaleProportionallyDown
        titleLabel.stringValue = section.title
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        subtitleLabel.stringValue = section.subtitle
        subtitleLabel.font = .systemFont(ofSize: 10.5, weight: .regular)
        subtitleLabel.lineBreakMode = .byTruncatingTail
        chevronView.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)

        let copy = NSStackView(views: [titleLabel, subtitleLabel])
        copy.orientation = .vertical
        copy.alignment = .leading
        copy.spacing = 2
        let row = NSStackView(views: [symbolView, copy, chevronView])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 54),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
            symbolView.widthAnchor.constraint(equalToConstant: 18),
            symbolView.heightAnchor.constraint(equalToConstant: 18),
            chevronView.widthAnchor.constraint(equalToConstant: 8),
            chevronView.heightAnchor.constraint(equalToConstant: 11),
        ])
        updateStyle()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var mouseDownCanMoveWindow: Bool { false }
    override var acceptsFirstResponder: Bool { isEnabled }
    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        showsKeyboardFocus = accepted && NSApp.currentEvent?.type == .keyDown
        updateKeyboardFocus()
        return accepted
    }
    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        showsKeyboardFocus = false
        updateKeyboardFocus()
        return resigned
    }
    override func layout() {
        super.layout()
        keyboardFocusLayer.frame = bounds
        keyboardFocusLayer.path = CGPath(
            roundedRect: bounds.insetBy(dx: 2.5, dy: 2.5),
            cornerWidth: 5,
            cornerHeight: 5,
            transform: nil
        )
        updateKeyboardFocus()
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? {
        frame.contains(point) && !isHidden && isEnabled ? self : nil
    }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); updateStyle() }

    private func updateKeyboardFocus() {
        keyboardFocusLayer.strokeColor = KikiPalette.accentText.cgColor
        keyboardFocusLayer.isHidden = !showsKeyboardFocus || window?.firstResponder !== self || !isEnabled
    }

    private func updateStyle() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = isSelectedPage ? KikiPalette.selectionSurface.withAlphaComponent(0.74).cgColor : NSColor.clear.cgColor
            layer?.borderWidth = 0
            layer?.borderColor = NSColor.clear.cgColor
            let primary = isSelectedPage ? KikiPalette.primaryText : KikiPalette.secondaryText
            let accent = isSelectedPage ? KikiPalette.accentText : KikiPalette.tertiaryText
            titleLabel.textColor = primary
            subtitleLabel.textColor = isSelectedPage ? KikiPalette.secondaryText : KikiPalette.tertiaryText
            symbolView.contentTintColor = accent
            chevronView.contentTintColor = accent
            chevronView.isHidden = !isSelectedPage
        }
    }
}

@MainActor
private final class WorkbenchCenteredView: NSView {
    private let hostedView: NSView
    private let preferredSize: NSSize

    init(hostedView: NSView, preferredSize: NSSize) {
        self.hostedView = hostedView
        self.preferredSize = preferredSize
        super.init(frame: .zero)
        addSubview(hostedView)
        hostedView.translatesAutoresizingMaskIntoConstraints = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        hostedView.frame = NSRect(
            x: max(0, (bounds.width - preferredSize.width) / 2),
            y: max(0, (bounds.height - preferredSize.height) / 2),
            width: preferredSize.width,
            height: preferredSize.height
        )
    }
}

@MainActor
private final class WorkbenchScrollDocument: NSView {
    private let hostedView: NSView
    private let preferredSize: NSSize
    private let centersVertically: Bool

    init(hostedView: NSView, preferredSize: NSSize, centersVertically: Bool = false) {
        self.hostedView = hostedView
        self.preferredSize = preferredSize
        self.centersVertically = centersVertically
        super.init(frame: NSRect(origin: .zero, size: preferredSize))
        addSubview(hostedView)
        hostedView.translatesAutoresizingMaskIntoConstraints = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }

    func updateViewport(_ viewportSize: NSSize) {
        let documentWidth = max(1, viewportSize.width)
        let hostedWidth = min(documentWidth, preferredSize.width * 1.35)
        hostedView.frame = NSRect(
            x: max(0, (documentWidth - hostedWidth) / 2),
            y: 0,
            width: hostedWidth,
            height: max(preferredSize.height, viewportSize.height)
        )
        hostedView.layoutSubtreeIfNeeded()
        let fittedHeight = hostedView.fittingSize.height
        let targetSize = NSSize(
            width: documentWidth,
            height: max(preferredSize.height, viewportSize.height, fittedHeight)
        )
        guard abs(frame.width - targetSize.width) > 0.5 || abs(frame.height - targetSize.height) > 0.5 else { return }
        frame.size = targetSize
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let availableWidth = enclosingScrollView?.contentSize.width ?? preferredSize.width
        let documentWidth = max(1, availableWidth)
        let hostedWidth = min(documentWidth, preferredSize.width * 1.35)
        let hostedHeight = max(preferredSize.height, bounds.height, hostedView.fittingSize.height)
        hostedView.frame = NSRect(
            x: max(0, (documentWidth - hostedWidth) / 2),
            y: centersVertically ? max(0, (bounds.height - hostedHeight) / 2) : 0,
            width: hostedWidth,
            height: hostedHeight
        )
    }
}

private extension NSEvent.EventType {
    var isMouseEvent: Bool {
        switch self {
        case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
             .otherMouseDown, .otherMouseUp:
            return true
        default:
            return false
        }
    }
}
