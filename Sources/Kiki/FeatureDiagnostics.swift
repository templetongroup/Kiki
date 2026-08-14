import AppKit
import Foundation
import ObjectiveC.runtime

@MainActor
enum FeatureDiagnostics {
    static func run() throws {
        try checkDarkOnlyAppearance()
        try checkCorrectionMemory()
        try checkVoiceSnippets()
        try checkContextVocabulary()
        try checkMeetingExports()
        try checkFileTranscriptExports()
        try checkDictationMenuCopy()
        try checkKikiCheckup()
        try checkUndoAndRetry()
        try checkDictationTransientRecovery()
        try checkShortRecordingRecovery()
        try checkShortcutReleaseRecovery()
        try checkPrivateSession()
        try checkMeetingCapturePrivacy()
        try checkSupportBundle()
        try checkPawprints()
        try checkPhraseBoundaries()
        try checkGuidedWorkbench()
        try checkWindowInteractions()
        try checkVoiceStudio()
    }

    private static func checkDarkOnlyAppearance() throws {
        AppearanceController.apply()
        guard Settings.appearanceMode == .dark,
              AppAppearanceMode.allCases == [.dark],
              NSApp.appearance?.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua else {
            throw failure("dark-only application appearance")
        }
    }

    private static func checkGuidedWorkbench() throws {
        let controller = GuidedWorkbenchWindowController()
        controller.onRouteChange = { _ in
            let view = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 600))
            return GuidedWorkbenchSurface(view: view, sizing: .fill)
        }
        for section in GuidedWorkbenchSection.allCases {
            for subpage in section.subpages.indices {
                let route = GuidedWorkbenchRoute(section: section, subpage: subpage)
                controller.select(route)
                guard controller.route == route else { throw failure("Guided Workbench route \(section.rawValue) \(subpage)") }
            }
        }
        guard let content = controller.window?.contentView,
              findView(in: content, identifier: "kiki.workbench.sidebar") != nil,
              findView(in: content, identifier: "kiki.workbench.content") != nil,
              findView(in: content, identifier: "kiki.workbench.context-bar")?.layer?.backgroundColor == KikiPalette.surface.cgColor,
              findView(in: content, identifier: "kiki.workbench.tab-rail")?.layer?.backgroundColor != nil,
              let subnavigation = findView(
                  in: content,
                  identifier: "kiki.workbench.subnavigation"
              ) as? KikiFocusableSegmentedControl,
              subnavigation.layer?.sublayers?.contains(where: {
                  $0.name == "kiki.segmented-control.keyboard-focus"
              }) == true,
              findView(in: content, identifier: "kiki.workbench.quick-dictation") == nil,
              let releaseLabel = findView(in: content, identifier: "kiki.workbench.release") as? NSTextField,
              releaseLabel.stringValue.hasPrefix("RELEASE "),
              GuidedWorkbenchSection.allCases.allSatisfy({
                  findView(in: content, identifier: "kiki.workbench.nav.\($0.rawValue)") is NSButton
              }),
              controller.window?.isMovableByWindowBackground == false,
              controller.window?.styleMask.contains(.resizable) == true,
              controller.window?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua,
              (controller.window?.minSize.width ?? 0) >= 900 else {
            throw failure("Guided Workbench shell")
        }
        controller.select(GuidedWorkbenchRoute(section: .home, subpage: 0))
        content.layoutSubtreeIfNeeded()
        let navigationControls = descendants(of: content).compactMap { $0 as? NSControl }
            .filter { $0.identifier?.rawValue.hasPrefix("kiki.workbench.nav.") == true }
        let navigationHitFailures = navigationControls.compactMap { control -> String? in
            control.scrollToVisible(control.bounds)
            content.layoutSubtreeIfNeeded()
            let point = control.convert(NSPoint(x: control.bounds.midX, y: control.bounds.midY), to: content)
            guard let hit = content.hitTest(point) else {
                return "\(control.identifier?.rawValue ?? "unknown") hit nothing frame=\(control.frame)"
            }
            guard hit === control || hit.isDescendant(of: control) else {
                return "\(control.identifier?.rawValue ?? "unknown") hit \(type(of: hit)) frame=\(control.frame)"
            }
            return nil
        }
        guard navigationHitFailures.isEmpty else {
            throw failure("Guided Workbench native click routing [\(navigationHitFailures.joined(separator: "; "))]")
        }

        controller.select(GuidedWorkbenchRoute(section: .home, subpage: 0))
        content.layoutSubtreeIfNeeded()
        guard let tabRail = findView(in: content, identifier: "kiki.workbench.tab-rail"),
              tabRail.isHidden,
              tabRail.frame.height < 1 else {
            throw failure("single-page Workbench sections must not reserve an empty tab rail")
        }
        guard let selectedHomeNavigation = findView(in: content, identifier: "kiki.workbench.nav.home"),
              selectedHomeNavigation.layer?.borderWidth == 0 else {
            throw failure("selected Workbench navigation must not draw a colored border")
        }

        controller.select(GuidedWorkbenchRoute(section: .dictation, subpage: 1))
        content.layoutSubtreeIfNeeded()
        guard !tabRail.isHidden,
              tabRail.frame.height >= 40 else {
            throw failure("multi-page Workbench sections must keep their compact tab rail")
        }

        controller.select(GuidedWorkbenchRoute(section: .meetings))
        let availableMeetingHeight = (controller.window?.screen ?? NSScreen.main)?.visibleFrame.height ?? 760
        guard (controller.window?.minSize.height ?? 0) >= min(760, availableMeetingHeight) else {
            throw failure("Meeting route must open tall enough to expose its actions")
        }
        controller.select(GuidedWorkbenchRoute(section: .library))
        guard (controller.window?.minSize.width ?? 0) >= 1_100 else {
            throw failure("Library route must preserve readable split-view width")
        }
        controller.select(GuidedWorkbenchRoute(section: .home))
        guard (controller.window?.minSize.width ?? 0) <= 900,
              (controller.window?.minSize.height ?? 0) <= 650 else {
            throw failure("Home route must remain freely resizable")
        }

        let compactHomeController = GuidedWorkbenchWindowController()
        let compactHomeView = GuidedWorkbenchHomeView()
        compactHomeController.onRouteChange = { route in
            route.section == .home
                ? GuidedWorkbenchSurface(view: compactHomeView, sizing: .fill)
                : nil
        }
        compactHomeController.select(GuidedWorkbenchRoute(section: .home))
        compactHomeController.window?.setContentSize(NSSize(width: 900, height: 650))
        compactHomeController.window?.contentView?.layoutSubtreeIfNeeded()
        guard let compactHomeContent = compactHomeController.window?.contentView,
              compactHomeContent.bounds.width <= 900.5,
              compactHomeView.bounds.width <= 665,
              findView(
                  in: compactHomeView,
                  identifier: "kiki.workbench.home.readiness-card"
              ) != nil else {
            throw failure(
                "Home content must fit its single setup card in a 900-point window content=\(String(describing: compactHomeController.window?.contentView?.bounds)) home=\(compactHomeView.bounds)"
            )
        }
        let homeActionIDs = [
            "kiki.workbench.home.dictation",
            "kiki.workbench.home.meeting",
            "kiki.workbench.home.voice",
            "kiki.workbench.home.audio",
        ]
        guard let homeTitle = findView(
            in: compactHomeView,
            identifier: "kiki.workbench.home.title"
        ) as? NSTextField,
              homeTitle.stringValue == "Finish Kiki setup.",
              let microphoneValue = findView(
                  in: compactHomeView,
                  identifier: "kiki.workbench.home.readiness.microphone.value"
              ) as? NSTextField,
              microphoneValue.stringValue == "Permission needed",
              let accessibilityValue = findView(
                  in: compactHomeView,
                  identifier: "kiki.workbench.home.readiness.accessibility.value"
              ) as? NSTextField,
              accessibilityValue.stringValue == "Permission needed",
              let shortcutHelp = findView(
                  in: compactHomeView,
                  identifier: "kiki.workbench.home.shortcut-help"
              ) as? NSTextField,
              shortcutHelp.stringValue
                == "In any text field: \(Settings.activationMode.configuredInstruction(for: Settings.dictationShortcut))" else {
            throw failure("Home readiness must reflect incomplete live checks")
        }

        let dictationView = GuidedWorkbenchDictationView()
        dictationView.update(state: .idle, canUndo: false, canRetry: false)
        guard let configuredShortcut = findView(
                  in: dictationView,
                  identifier: "kiki.workbench.dictation.configured-shortcut"
              ) as? NSTextField,
              configuredShortcut.stringValue
                == "Configured shortcut: \(Settings.activationMode.configuredInstruction(for: Settings.dictationShortcut))",
              let handsFreeShortcut = findView(
                  in: dictationView,
                  identifier: "kiki.workbench.dictation.hands-free-shortcut"
              ) as? NSTextField,
              handsFreeShortcut.stringValue == DictationShortcutGuidance.handsFreeInstruction else {
            throw failure("Dictation surface must distinguish configured and hands-free shortcuts")
        }
        guard let homeDictationButton = findView(
            in: compactHomeView,
            identifier: "kiki.workbench.home.dictation"
        ) as? KikiActionButton,
              homeDictationButton.title == "Try Dictation" else {
            throw failure("Incomplete setup must offer a working practice dictation")
        }
        guard let homeArtwork = findView(
            in: compactHomeView,
            identifier: "kiki.workbench.home.hero"
        ) as? KikiDecorativeImageView,
              !homeArtwork.isAccessibilityElement() else {
            throw failure("Home hero artwork must be decorative")
        }
        var homeRouteChecks: [String] = []
        compactHomeView.onOpenCheckup = { homeRouteChecks.append("checkup") }
        compactHomeView.onOpenModels = { homeRouteChecks.append("models") }
        compactHomeView.onStartDictation = { homeRouteChecks.append("dictation") }
        let readinessActionChecks = [
            ("kiki.workbench.home.readiness.shortcut.action", "checkup"),
            ("kiki.workbench.home.readiness.model.action", "models"),
        ]
        for (identifier, expectedRoute) in readinessActionChecks {
            guard let action = findView(in: compactHomeView, identifier: identifier) as? KikiActionButton else {
                throw failure("Home readiness action \(identifier)")
            }
            action.performClick(nil)
            guard homeRouteChecks.last == expectedRoute else {
                throw failure("Home readiness action \(identifier) must open \(expectedRoute)")
            }
        }
        let readinessActionIDs = [
            "kiki.workbench.home.readiness.microphone.action",
            "kiki.workbench.home.readiness.accessibility.action",
            "kiki.workbench.home.readiness.model.action",
            "kiki.workbench.home.readiness.shortcut.action",
        ]
        compactHomeView.layoutSubtreeIfNeeded()
        let readinessActions = readinessActionIDs.compactMap {
            findView(in: compactHomeView, identifier: $0) as? KikiActionButton
        }
        let actionMinX = readinessActions.map(\.frame.minX)
        let actionWidths = readinessActions.map(\.frame.width)
        let actionHeights = readinessActions.map(\.frame.height)
        guard readinessActions.count == readinessActionIDs.count,
              let minimumActionX = actionMinX.min(),
              let maximumActionX = actionMinX.max(),
              maximumActionX - minimumActionX <= 1,
              actionWidths.allSatisfy({ abs($0 - 104) <= 1 }),
              actionHeights.allSatisfy({ abs($0 - 30) <= 1 }) else {
            throw failure("Home readiness actions must share one aligned column x=\(actionMinX) widths=\(actionWidths) heights=\(actionHeights)")
        }
        guard let firstDictationAction = findView(
            in: compactHomeView,
            identifier: "kiki.workbench.home.readiness.first-dictation.action"
        ) as? KikiActionButton,
              firstDictationAction.isHidden else {
            throw failure("First dictation must use the single hero action")
        }
        homeDictationButton.performClick(nil)
        guard homeRouteChecks.last == "dictation" else {
            throw failure("Home Try Dictation must open guided dictation")
        }
        compactHomeView.update(snapshot: KikiCheckupSnapshot(
            microphoneAuthorized: true,
            inputResponding: true,
            accessibilityAuthorized: true,
            modelStatus: .ready(model: .parakeetEnglish),
            shortcutVerified: true,
            firstDictationCompleted: true
        ))
        let readinessActionsWhenReady = [
            "kiki.workbench.home.readiness.microphone.action",
            "kiki.workbench.home.readiness.accessibility.action",
            "kiki.workbench.home.readiness.model.action",
            "kiki.workbench.home.readiness.shortcut.action",
            "kiki.workbench.home.readiness.first-dictation.action",
        ].compactMap { findView(in: compactHomeView, identifier: $0) as? KikiActionButton }
        let visibleTryDictationButtons = descendants(of: compactHomeView)
            .compactMap { $0 as? NSButton }
            .filter { !$0.isHidden && $0.title == "Try Dictation" }
        guard homeTitle.stringValue == "Kiki is ready.",
              microphoneValue.stringValue == "Ready",
              accessibilityValue.stringValue == "Ready",
              shortcutHelp.stringValue.contains(Settings.dictationShortcut.displayString),
              homeDictationButton.title == "Try Dictation",
              readinessActionsWhenReady.count == 5,
              readinessActionsWhenReady.allSatisfy(\.isHidden),
              visibleTryDictationButtons.count == 1,
              visibleTryDictationButtons.first === homeDictationButton else {
            throw failure("Ready Home must have one dictation action and status-only setup checks")
        }
        let homeActionButtons = homeActionIDs.compactMap {
            findView(in: compactHomeView, identifier: $0) as? KikiActionButton
        }
        let homeActionHeights = homeActionButtons.map(\.frame.height)
        let homeActionWidths = homeActionButtons.map(\.frame.width)
        let homeActionMinY = homeActionButtons.map(\.frame.minY)
        let homeActionFontSizes = homeActionButtons.compactMap { $0.font?.pointSize }
        let homeActionFontNames = homeActionButtons.compactMap { $0.font?.fontName }
        let homeActionRenderedFontSizes = homeActionButtons.compactMap {
            $0.attributedTitle.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        }.map(\.pointSize)
        let homeActionRenderedFontNames = homeActionButtons.compactMap {
            $0.attributedTitle.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        }.map(\.fontName)
        guard homeActionButtons.count == homeActionIDs.count,
              let minimumHomeActionHeight = homeActionHeights.min(),
              let maximumHomeActionHeight = homeActionHeights.max(),
              maximumHomeActionHeight - minimumHomeActionHeight <= 0.5,
              let minimumHomeActionWidth = homeActionWidths.min(),
              let maximumHomeActionWidth = homeActionWidths.max(),
              maximumHomeActionWidth - minimumHomeActionWidth <= 0.5,
              let minimumHomeActionMinY = homeActionMinY.min(),
              let maximumHomeActionMinY = homeActionMinY.max(),
              maximumHomeActionMinY - minimumHomeActionMinY <= 0.5,
              Set(homeActionFontSizes).count == 1,
              Set(homeActionFontNames).count == 1,
              Set(homeActionRenderedFontSizes).count == 1,
              Set(homeActionRenderedFontNames).count == 1,
              homeActionRenderedFontSizes.allSatisfy({ abs($0 - 13) < 0.1 }) else {
            throw failure(
                "Home actions must share one geometry and label treatment widths=\(homeActionWidths) heights=\(homeActionHeights) y=\(homeActionMinY) fonts=\(homeActionFontNames) sizes=\(homeActionFontSizes) renderedFonts=\(homeActionRenderedFontNames) renderedSizes=\(homeActionRenderedFontSizes)"
            )
        }

        let adaptivePage = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 620))
        controller.onRouteChange = { _ in
            GuidedWorkbenchSurface(view: adaptivePage, sizing: .scroll(NSSize(width: 900, height: 620)))
        }
        controller.window?.setContentSize(NSSize(width: 1_300, height: 820))
        controller.select(GuidedWorkbenchRoute(section: .library))
        content.layoutSubtreeIfNeeded()
        controller.windowDidResize(Notification(name: NSWindow.didResizeNotification))
        content.layoutSubtreeIfNeeded()
        guard adaptivePage.frame.width > 900,
              adaptivePage.frame.width <= 1_215.5,
              adaptivePage.frame.height >= 620 else {
            throw failure("Workbench hosted pages must resize within a readable measure")
        }

        let settingsController = SettingsWindowController()
        let personalizationController = PersonalizationWindowController()
        let embeddedSettings = settingsController.workbenchPage(0)
        let embeddedPersonalization = personalizationController.workbenchPage(context: nil, page: 0)
        guard descendants(of: embeddedSettings).allSatisfy({ !($0 is KikiNavButton) }),
              descendants(of: embeddedPersonalization).allSatisfy({ !($0 is KikiNavButton) }) else {
            throw failure("Workbench content must not embed legacy sidebars")
        }

        let narrowPersonalizationHost = NSView(frame: NSRect(x: 0, y: 0, width: 960, height: 900))
        embeddedPersonalization.translatesAutoresizingMaskIntoConstraints = false
        narrowPersonalizationHost.addSubview(embeddedPersonalization)
        NSLayoutConstraint.activate([
            embeddedPersonalization.leadingAnchor.constraint(equalTo: narrowPersonalizationHost.leadingAnchor),
            embeddedPersonalization.trailingAnchor.constraint(equalTo: narrowPersonalizationHost.trailingAnchor),
            embeddedPersonalization.topAnchor.constraint(equalTo: narrowPersonalizationHost.topAnchor),
            embeddedPersonalization.bottomAnchor.constraint(equalTo: narrowPersonalizationHost.bottomAnchor),
        ])
        narrowPersonalizationHost.layoutSubtreeIfNeeded()
        guard let guidedReview = findView(
            in: embeddedPersonalization,
            identifier: "kiki.personalization.guided-review"
        ) else {
            throw failure("Personalization guided review surface")
        }
        let guidedReviewFrame = guidedReview.convert(guidedReview.bounds, to: embeddedPersonalization)
        guard guidedReviewFrame.width >= embeddedPersonalization.bounds.width - 1,
              guidedReviewFrame.minX >= -0.5,
              guidedReviewFrame.maxX <= embeddedPersonalization.bounds.maxX + 0.5,
              guidedReviewFrame.minY >= -0.5,
              guidedReviewFrame.maxY <= embeddedPersonalization.bounds.maxY + 0.5,
              guidedReviewFrame.height >= guidedReview.fittingSize.height - 1 else {
            throw failure(
                "Personalization guided review must stack at narrow widths frame=\(guidedReviewFrame) page=\(embeddedPersonalization.bounds)"
            )
        }

        let dictationSettings = settingsController.workbenchPage(1)
        let narrowSettingsHost = NSView(frame: NSRect(x: 0, y: 0, width: 960, height: 900))
        dictationSettings.translatesAutoresizingMaskIntoConstraints = false
        narrowSettingsHost.addSubview(dictationSettings)
        NSLayoutConstraint.activate([
            dictationSettings.leadingAnchor.constraint(equalTo: narrowSettingsHost.leadingAnchor),
            dictationSettings.trailingAnchor.constraint(equalTo: narrowSettingsHost.trailingAnchor),
            dictationSettings.topAnchor.constraint(equalTo: narrowSettingsHost.topAnchor),
            dictationSettings.bottomAnchor.constraint(equalTo: narrowSettingsHost.bottomAnchor),
        ])
        narrowSettingsHost.layoutSubtreeIfNeeded()
        guard let positionRow = findView(
            in: dictationSettings,
            identifier: "kiki.settings.listening-position-row"
        ),
              let positionLabel = descendants(of: positionRow).compactMap({ $0 as? NSTextField }).first,
              let positionPopup = findView(
                in: positionRow,
                identifier: "kiki.listening-display-position"
              ) else {
            throw failure("Listening display position row")
        }
        let positionLabelFrame = positionLabel.convert(positionLabel.bounds, to: positionRow)
        let positionPopupFrame = positionPopup.convert(positionPopup.bounds, to: positionRow)
        guard positionPopupFrame.minX - positionLabelFrame.maxX <= 18 else {
            throw failure(
                "Listening display label and menu must stay grouped gap=\(positionPopupFrame.minX - positionLabelFrame.maxX)"
            )
        }

        let narrowGeneralSettingsHost = NSView(frame: NSRect(x: 0, y: 0, width: 960, height: 900))
        embeddedSettings.translatesAutoresizingMaskIntoConstraints = false
        narrowGeneralSettingsHost.addSubview(embeddedSettings)
        NSLayoutConstraint.activate([
            embeddedSettings.leadingAnchor.constraint(equalTo: narrowGeneralSettingsHost.leadingAnchor),
            embeddedSettings.trailingAnchor.constraint(equalTo: narrowGeneralSettingsHost.trailingAnchor),
            embeddedSettings.topAnchor.constraint(equalTo: narrowGeneralSettingsHost.topAnchor),
            embeddedSettings.bottomAnchor.constraint(equalTo: narrowGeneralSettingsHost.bottomAnchor),
        ])
        narrowGeneralSettingsHost.layoutSubtreeIfNeeded()
        let groupedSettingsControls: [(page: NSView, rowID: String, controlID: String)] = [
            (embeddedSettings, "kiki.settings.sound-row", "kiki.sound-style"),
            (embeddedSettings, "kiki.settings.microphone-row", "kiki.settings.microphone"),
            (dictationSettings, "kiki.settings.shortcut-row", "kiki.dictation-shortcut"),
            (dictationSettings, "kiki.settings.behavior-row", "kiki.activation-mode"),
            (dictationSettings, "kiki.settings.speech-profile-row", "kiki.speech-profile"),
        ]
        for groupedControl in groupedSettingsControls {
            guard let row = findView(in: groupedControl.page, identifier: groupedControl.rowID),
                  let label = descendants(of: row).compactMap({ $0 as? NSTextField }).first,
                  let control = findView(in: row, identifier: groupedControl.controlID) else {
                throw failure("Grouped settings control \(groupedControl.rowID)")
            }
            let labelFrame = label.convert(label.bounds, to: row)
            let controlFrame = control.convert(control.bounds, to: row)
            guard controlFrame.minX - labelFrame.maxX <= 18 else {
                throw failure(
                    "Settings label and control must stay grouped row=\(groupedControl.rowID) gap=\(controlFrame.minX - labelFrame.maxX)"
                )
            }
        }
    }

    static func benchmarkPostProcessing(iterations: Int = 100) -> TimeInterval {
        let store = ContextVocabularyStore(fileURL: temporaryFile("benchmark-context.json"))
        let syntheticTerms = (0..<2_000).map { "ProjectTerm\($0)" } + ["Northwind", "Kubernetes"]
        store.add(values: syntheticTerms, source: .project)
        let sample = "Alex Northwimd will review Kubernetez with the team tomorrow morning."
        let started = ProcessInfo.processInfo.systemUptime
        for _ in 0..<iterations {
            _ = store.apply(to: sample, bundleIdentifier: nil)
        }
        return (ProcessInfo.processInfo.systemUptime - started) / Double(iterations)
    }

    static func checkSplashArtwork(referenceURL: URL) throws {
        guard let referenceImage = NSImage(contentsOf: referenceURL),
              let referenceData = referenceImage.tiffRepresentation else {
            throw failure("splash artwork reference")
        }

        let controller = WhatsNewWindowController()
        guard let contentView = controller.window?.contentView,
              let artworkView = findView(
                  in: contentView,
                  identifier: "kiki.whats-new.splash-artwork"
              ) as? NSImageView,
              let copyView = findView(
                  in: contentView,
                  identifier: "kiki.whats-new.copy"
              ),
              let renderedData = artworkView.image?.tiffRepresentation,
              renderedData == referenceData else {
            throw failure("splash artwork")
        }

        contentView.layoutSubtreeIfNeeded()
        let artworkFrame = artworkView.convert(artworkView.bounds, to: contentView)
        let copyFrame = copyView.convert(copyView.bounds, to: contentView)
        guard artworkFrame.width >= 300,
              artworkFrame.maxX < copyFrame.minX else {
            throw failure("splash artwork layout")
        }
    }

    static func checkVoiceEnrollment(fullScriptReferenceURL: URL) throws {
        let expected = try String(contentsOf: fullScriptReferenceURL, encoding: .utf8)
            .trimmingCharacters(in: .newlines)
        guard VoiceProfileStore.fullEnrollmentScript == expected,
              VoiceEnrollmentMode.quick.script == VoiceProfileStore.quickEnrollmentScript,
              VoiceEnrollmentMode.full.script == expected,
              VoiceEnrollmentMode.full.minimumDuration > VoiceEnrollmentMode.quick.maximumDuration,
              VoiceProfileStore.quickEnrollmentScript == "This is my voice, recorded for my private Kiki voice model. On a bright morning, I might speak quickly with excitement. Later, I may slow down to explain a thoughtful idea." else {
            throw failure("full voice enrollment script")
        }

        let compatibleProfile = KikiVoiceProfile(
            name: "Test Voice",
            transcript: VoiceProfileStore.quickEnrollmentScript,
            duration: 14,
            createdAt: Date(),
            consentVersion: 1,
            enrollmentMode: .quick
        )
        let incompatibleProfile = KikiVoiceProfile(
            name: "Legacy Voice",
            transcript: VoiceProfileStore.fullEnrollmentScript,
            duration: 360,
            createdAt: Date(),
            consentVersion: 1,
            enrollmentMode: .full
        )
        guard compatibleProfile.isGenerationCompatible,
              !incompatibleProfile.isGenerationCompatible else {
            throw failure("voice generation compatibility")
        }
        let normalScript = String(repeating: "A natural sentence should remain in one continuous take. ", count: 16)
        let longScript = String(repeating: "A much longer script still needs safe processing sections. ", count: 50)
        guard normalScript.count > 800,
              LocalVoiceSynthesisEngine.sectionCountForDiagnostics(normalScript) == 1,
              LocalVoiceSynthesisEngine.sectionCountForDiagnostics(longScript) >= 2 else {
            throw failure("voice generation section continuity")
        }

        let controller = VoiceStudioWindowController()
        guard let contentView = controller.window?.contentView,
              findView(in: contentView, identifier: "kiki.voice.enrollment-mode") == nil,
              findView(in: contentView, identifier: "kiki.voice.enrollment-explanation") is NSTextField,
              findView(in: contentView, identifier: "kiki.voice.enrollment-script") is NSTextView,
              findView(in: contentView, identifier: "kiki.voice.enrollment-panel") is KikiInsetPanelView,
              let consent = findView(in: contentView, identifier: "kiki.voice.consent") as? NSButton,
              let deleteVoice = findButton(in: contentView, title: "Delete Voice"),
              deleteVoice.layer?.borderWidth == 1,
              !consent.title.localizedCaseInsensitiveContains("consent"),
              consent.title.localizedCaseInsensitiveContains("my own voice"),
              consent.title.localizedCaseInsensitiveContains("private on this Mac") else {
            throw failure("voice enrollment mode interface")
        }
    }

    static func checkWaveformAudio(referenceURL: URL) throws {
        let samples = try AudioFileLoader.load16kMono(url: referenceURL)
        let chunkSize = 341
        var waveformModel = VoiceWaveformModel(barCount: KikiWaveformView.barCount)
        var renderedLevels: [CGFloat] = []
        let levels = stride(from: 0, through: max(0, samples.count - chunkSize), by: chunkSize)
            .map { start -> CGFloat in
                let chunk = Array(samples[start..<(start + chunkSize)])
                waveformModel.ingest(samples: chunk)
                waveformModel.advanceFrame()
                renderedLevels.append(waveformModel.bars.last ?? 0)
                return VoiceLevelMeter.normalizedLevel(for: chunk)
            }
            .filter { $0 > 0 }
            .sorted()
        guard !levels.isEmpty else { throw failure("waveform audio fixture") }
        let p90 = levels[Int(Double(levels.count - 1) * 0.90)]
        let sortedRenderedLevels = renderedLevels.sorted()
        let renderedP90 = sortedRenderedLevels[Int(Double(sortedRenderedLevels.count - 1) * 0.90)]
        guard p90 < 0.60,
              levels.last ?? 1 < 0.80,
              renderedP90 < 0.55,
              sortedRenderedLevels.last ?? 1 < 0.70,
              renderedLevels.allSatisfy({ $0 < 0.80 })
        else { throw failure("waveform real-voice headroom") }
    }

    static func checkVoiceStudioHero(referenceURL: URL) throws {
        guard let referenceImage = NSImage(contentsOf: referenceURL),
              let referenceData = referenceImage.tiffRepresentation else {
            throw failure("voice studio hero reference")
        }

        let controller = VoiceStudioWindowController()
        guard let contentView = controller.window?.contentView,
              let heroView = findView(in: contentView, identifier: "kiki.voice.studio-hero"),
              let artworkView = findView(
                  in: contentView,
                  identifier: "kiki.voice.studio-hero-artwork"
              ) as? KikiDecorativeImageView,
              !artworkView.isAccessibilityElement(),
              let copyView = findView(in: contentView, identifier: "kiki.voice.studio-hero-copy"),
              let renderedData = artworkView.image?.tiffRepresentation,
              renderedData == referenceData else {
            throw failure("voice studio hero artwork")
        }

        contentView.layoutSubtreeIfNeeded()
        let heroFrame = heroView.convert(heroView.bounds, to: contentView)
        let artworkFrame = artworkView.convert(artworkView.bounds, to: contentView)
        let copyFrame = copyView.convert(copyView.bounds, to: contentView)
        let artworkRatio = referenceImage.size.width / referenceImage.size.height
        guard heroFrame.width >= 1_000,
              heroFrame.height >= 225,
              artworkRatio >= 2.5,
              artworkFrame.width >= 610,
              artworkFrame.height >= 225,
              copyFrame.minX >= heroFrame.minX,
              copyFrame.maxX <= heroFrame.midX else {
            throw failure("voice studio hero layout")
        }
    }

    private static func checkCorrectionMemory() throws {
        let store = CorrectionMemoryStore(fileURL: temporaryFile("learning.json"))
        store.suggest(heard: "Northwimd", replacement: "Northwind", bundleIdentifier: "com.apple.mail")
        guard let suggestion = store.suggestions.first else { throw failure("correction suggestion") }
        store.approve(suggestion, scopeToApp: true)
        guard store.apply(to: "Alex Northwimd", bundleIdentifier: "com.apple.mail") == "Alex Northwind",
              store.apply(to: "Alex Northwimd", bundleIdentifier: "com.apple.TextEdit") == "Alex Northwimd"
        else { throw failure("correction scoping") }
    }

    private static func checkVoiceSnippets() throws {
        let store = VoiceSnippetStore(fileURL: temporaryFile("snippets.json"))
        store.add(trigger: "insert status", template: "Status: complete")
        guard let snippet = store.snippets.first else { throw failure("voice snippet creation") }
        store.update(id: snippet.id, trigger: "insert project status", template: "Project status: shipped")
        guard store.expansion(for: "Insert status.") == nil,
              store.expansion(for: "Insert project status.") == "Project status: shipped",
              store.snippets.first?.id == snippet.id,
              store.expansion(for: "Please insert status here") == nil
        else { throw failure("voice snippet matching and editing") }
    }

    private static func checkContextVocabulary() throws {
        let previous = Settings.useContextVocabulary
        Settings.useContextVocabulary = true
        defer { Settings.useContextVocabulary = previous }
        let store = ContextVocabularyStore(fileURL: temporaryFile("context.json"))
        store.add(values: ["Northwind", "Kubernetes"], source: .manual)
        guard store.apply(to: "Northwimd uses Kubernetez", bundleIdentifier: nil) == "Northwind uses Kubernetes",
              store.apply(to: "This is ordinary prose", bundleIdentifier: nil) == "This is ordinary prose"
        else { throw failure("context vocabulary") }
    }

    private static func checkMeetingExports() throws {
        let permissionError = MeetingCaptureStartError.systemAudioPermissionRequired
        let segments = [
            MeetingTranscriptSegment(startTime: 0, endTime: 5, speaker: "You", text: "I will send the proposal."),
            MeetingTranscriptSegment(startTime: 6, endTime: 12, speaker: "Speaker 1", text: "Please schedule the review."),
        ]
        let liveMeetingSegments = [
            MeetingTranscriptSegment(startTime: 77, endTime: 81, speaker: "Speaker 1", text: "Do we just need to wait?"),
            MeetingTranscriptSegment(startTime: 77, endTime: 81, speaker: "You", text: "Do we just need to wait?"),
            MeetingTranscriptSegment(startTime: 385, endTime: 389, speaker: "You", text: "I'll continue."),
            MeetingTranscriptSegment(startTime: 390, endTime: 399, speaker: "You", text: "Continue planning, organizing structurally what we want."),
            MeetingTranscriptSegment(startTime: 465, endTime: 470, speaker: "Speaker 1", text: "It's something I need to figure out because my"),
            MeetingTranscriptSegment(startTime: 576, endTime: 577, speaker: "You", text: "I'll definitely put some together for you."),
            MeetingTranscriptSegment(startTime: 577, endTime: 579, speaker: "You", text: "I'll send you a few examples."),
            MeetingTranscriptSegment(startTime: 610, endTime: 614, speaker: "Speaker 1", text: "Could you email me the final options?"),
        ]
        let refinedMeetingSegments = MeetingTranscript.deduplicatingSourceOverlap(liveMeetingSegments)
        let contextualActions = MeetingTranscript.actionItems(from: refinedMeetingSegments)
        let meeting = MeetingTranscript(
            title: "Planning",
            createdAt: Date(timeIntervalSince1970: 0),
            duration: 12,
            segments: segments,
            actionItems: MeetingTranscript.actionItems(from: segments)
        )
        let renamed = meeting.renamingSpeaker(from: "Speaker 1", to: "Alex")
        let assigned = renamed.assigningSpeaker(
            "Jordan",
            to: Set(segments.filter { $0.speaker == "You" }.map(\.id))
        )
        let sentenceRows = MeetingTranscriptSegment.sentenceSegments(
            startTime: 0,
            endTime: 12,
            speaker: "Speaker 1",
            text: "First person speaking. Second person answering!"
        )
        guard refinedMeetingSegments.filter({ $0.text == "Do we just need to wait?" }).count == 1 else {
            throw failure("meeting cross-track echo removal")
        }
        guard !contextualActions.contains(where: { $0.localizedCaseInsensitiveContains("need to wait") }),
              contextualActions.contains(where: {
                  $0.contains("You —")
                      && $0.localizedCaseInsensitiveContains("continue planning")
                      && $0.contains("00:06:25")
              }),
              contextualActions.filter({ $0.localizedCaseInsensitiveContains("examples") }).count == 1 else {
            throw failure("meeting contextual action items")
        }
        guard contextualActions.contains(where: {
            $0.contains("You —")
                && $0.localizedCaseInsensitiveContains("email me the final options")
                && $0.contains("requested by Speaker 1")
        }) else {
            throw failure("meeting action request ownership")
        }
        guard meeting.markdown.contains("## Action items"),
              meeting.srt.contains("00:00:00,000 --> 00:00:05,000"),
              meeting.vtt.hasPrefix("WEBVTT"),
              meeting.actionItems.count == 2,
              !renamed.markdown.contains("Speaker 1"),
              renamed.markdown.contains("Alex"),
              renamed.srt.contains("Alex:"),
              renamed.vtt.contains("<v Alex>"),
              assigned.speakerNames == ["Jordan", "Alex"],
              sentenceRows.count == 2,
              sentenceRows[0].endTime == sentenceRows[1].startTime,
              permissionError.requiresScreenRecordingSettings,
              permissionError.localizedDescription.contains("Zoom"),
              !MeetingCaptureStartError.microphoneUnavailable("test").requiresScreenRecordingSettings
        else { throw failure("meeting exports") }
    }

    private static func checkFileTranscriptExports() throws {
        let richText = try FileTranscriptExportFormat.richText.data(text: "Hello", sourceName: "Interview")
        let pdf = try FileTranscriptExportFormat.pdf.data(text: String(repeating: "A complete local transcript. ", count: 500), sourceName: "Interview")
        guard FileTranscriptExportFormat.allCases == [.plainText, .markdown, .richText, .pdf],
              FileTranscriptExportFormat.allCases.map(\.fileExtension) == ["txt", "md", "rtf", "pdf"],
              String(data: try FileTranscriptExportFormat.markdown.data(text: "Hello", sourceName: "Interview"), encoding: .utf8) == "# Interview\n\nHello\n",
              richText.count > 100,
              pdf.starts(with: Data("%PDF".utf8)),
              pdf.count > 1_000
        else { throw failure("file transcript export formats") }
    }

    private static func checkDictationMenuCopy() throws {
        let holdInstruction = ActivationMode.hold.configuredInstruction(for: .rightOption)
        let toggleInstruction = ActivationMode.toggle.configuredInstruction(for: .rightOption)
        guard holdInstruction == "Hold Right ⌥ to dictate; release to stop and insert.",
              toggleInstruction == "Press Right ⌥ to start; press it again to stop and insert.",
              ActivationMode.hold.shortcutTestInstruction(for: .rightOption)
                == "Hold Right ⌥ briefly, then release.",
              ActivationMode.toggle.shortcutTestInstruction(for: .rightOption)
                == "Press Right ⌥ once.",
              DictationShortcutGuidance.handsFreeInstruction
                == "Hands-free toggle: press ⌃⌥D to start; press it again to stop and insert.",
              DictationMenuCopy.start == "Start Hands-Free Dictation (⌃⌥D)",
              DictationMenuCopy.stop == "Stop Hands-Free Dictation & Insert (⌃⌥D)",
              DictationMenuCopy.idleStatus.contains("Configured shortcut:"),
              DictationMenuCopy.recordingStatus.contains("hands-free action below") else {
            throw failure("self-explanatory dictation menu copy")
        }
    }

    private static func checkKikiCheckup() throws {
        let microphones = [
            AudioInputDeviceDescriptor(name: "Desk Mic", uniqueID: "desk"),
            AudioInputDeviceDescriptor(name: "Studio Mic", uniqueID: "studio"),
        ]
        let blocked = KikiCheckupSnapshot(
            microphoneAuthorized: false,
            inputResponding: true,
            accessibilityAuthorized: true,
            modelStatus: .ready(model: .parakeetEnglish),
            shortcutVerified: true,
            firstDictationCompleted: true
        )
        let ready = KikiCheckupSnapshot(
            microphoneAuthorized: true,
            inputResponding: true,
            accessibilityAuthorized: true,
            modelStatus: .ready(model: .parakeetEnglish),
            shortcutVerified: true,
            firstDictationCompleted: true
        )
        let downloading = KikiCheckupSnapshot(
            microphoneAuthorized: true,
            inputResponding: true,
            accessibilityAuthorized: true,
            modelStatus: .downloading(model: .whisperBaseEnglish, fraction: 0.42),
            shortcutVerified: true,
            firstDictationCompleted: true
        )
        let loading = ModelPreparationStatus.loading(model: .whisperBaseEnglish)
        guard !blocked.isReady,
              ready.isReady,
              !downloading.isReady,
              downloading.modelStatus.compactTitle == "Downloading Whisper Base — English · 42%",
              downloading.modelStatus.checkupDetail == "Downloading · 42%",
              downloading.modelStatus.downloadFraction == 0.42,
              loading.compactTitle == "Loading Whisper Base — English…",
              loading.checkupDetail == "Loading into memory",
              loading.downloadFraction == nil,
              AudioInputDevice.selected(from: microphones, preferredID: "studio")?.uniqueID == "studio",
              AudioInputDevice.selected(from: microphones, preferredID: "missing")?.uniqueID == "desk" else {
            throw failure("Kiki Checkup readiness contract")
        }
    }

    private static func checkUndoAndRetry() throws {
        let value = "Opening sentence. Kiki inserted this."
        let caret = NSRange(location: (value as NSString).length, length: 0)
        let expected = NSRange(
            location: ("Opening sentence. " as NSString).length,
            length: ("Kiki inserted this." as NSString).length
        )
        guard ExactInsertionUndoPlanner.range(
            insertedText: "Kiki inserted this.",
            currentValue: value,
            selection: caret
        ) == expected,
        ExactInsertionUndoPlanner.range(
            insertedText: "Different text",
            currentValue: value,
            selection: caret
        ) == nil,
        ExactInsertionUndoPlanner.range(
            insertedText: "Kiki inserted this.",
            currentValue: value + " User edit",
            selection: NSRange(location: ((value + " User edit") as NSString).length, length: 0)
        ) == nil else {
            throw failure("exact last insertion undo contract")
        }
    }

    private static func checkDictationTransientRecovery() throws {
        let controller = DictationController()
        guard controller.state == .loadingModel else {
            throw failure("dictation model preparation initial state")
        }
        controller.startRecording()
        controller.resolveTransientPresentationAfterDelay()
        guard controller.state == .loadingModel,
              controller.modelPreparationStatus == .loading(model: Settings.transcriptionModel) else {
            throw failure("temporary dictation message must preserve model preparation state")
        }
    }

    private static func checkShortRecordingRecovery() throws {
        guard DictationController.stateAfterRecordingEnds(
            processingJob: false,
            pendingJobCount: 0
        ) == .idle else {
            throw failure("short dictation must return to idle")
        }
        guard DictationController.stateAfterRecordingEnds(
            processingJob: true,
            pendingJobCount: 0
        ) == .transcribing,
        DictationController.stateAfterRecordingEnds(
            processingJob: false,
            pendingJobCount: 1
        ) == .transcribing else {
            throw failure("short zero-wait dictation must resume earlier transcription")
        }
    }

    private static func checkShortcutReleaseRecovery() throws {
        let manager = HotkeyManager()
        manager.dictationShortcut = DictationShortcut(
            keyCode: 2,
            modifiersRawValue: NSEvent.ModifierFlags.control.rawValue
        )
        manager.activationMode = .hold
        guard let keyDown = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.control],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "d",
            charactersIgnoringModifiers: "d",
            isARepeat: false,
            keyCode: 2
        ), let keyUpAfterModifierRelease = NSEvent.keyEvent(
            with: .keyUp,
            location: .zero,
            modifierFlags: [],
            timestamp: 0.1,
            windowNumber: 0,
            context: nil,
            characters: "d",
            charactersIgnoringModifiers: "d",
            isARepeat: false,
            keyCode: 2
        ) else {
            throw failure("shortcut event fixtures")
        }
        manager.processEventForDiagnostics(keyDown)
        guard manager.diagnosticTriggerDown else {
            throw failure("modified shortcut press")
        }
        manager.processEventForDiagnostics(keyUpAfterModifierRelease)
        guard !manager.diagnosticTriggerDown else {
            throw failure("modified shortcut must recover when its modifier is released first")
        }
    }

    private static func checkPrivateSession() throws {
        let normal = PrivateSessionPolicy.resolved(privateSessionActive: false, privateContext: false)
        let session = PrivateSessionPolicy.resolved(privateSessionActive: true, privateContext: false)
        let privateApp = PrivateSessionPolicy.resolved(privateSessionActive: false, privateContext: true)
        guard normal.historyEnabled,
              normal.learningEnabled,
              normal.confidenceVerificationEnabled,
              normal.pawprintsEnabled,
              session == PrivateSessionPolicy(
                historyEnabled: false,
                learningEnabled: false,
                confidenceVerificationEnabled: false,
                pawprintsEnabled: false
              ),
              privateApp == session else {
            throw failure("Private Session policy")
        }
    }

    private static func checkMeetingCapturePrivacy() throws {
        let originalHistory = ["existing meeting"]

        var startedPrivate = MeetingCapturePrivacy()
        startedPrivate.begin(privateSessionActive: true)
        startedPrivate.privateSessionDidChange(isActive: false)
        var history = originalHistory
        startedPrivate.persistHistoryIfAllowed {
            history.append("must not persist")
        }
        guard history == originalHistory else {
            throw failure("meeting started in Private Session must not enter history")
        }

        var becamePrivate = MeetingCapturePrivacy()
        becamePrivate.begin(privateSessionActive: false)
        becamePrivate.privateSessionDidChange(isActive: true)
        becamePrivate.privateSessionDidChange(isActive: false)
        history = originalHistory
        becamePrivate.persistHistoryIfAllowed {
            history.append("must not persist")
        }
        guard history == originalHistory else {
            throw failure("meeting made private while recording must not enter history")
        }

        becamePrivate.end()
        becamePrivate.begin(privateSessionActive: false)
        history = originalHistory
        becamePrivate.persistHistoryIfAllowed {
            history.append("normal meeting")
        }
        guard history.count == originalHistory.count + 1 else {
            throw failure("normal meeting history persistence")
        }
    }

    private static func checkSupportBundle() throws {
        let data = SupportBundleBuilder.diagnosticJSONForTesting()
        guard let text = String(data: data, encoding: .utf8) else {
            throw failure("support bundle encoding")
        }
        let lowered = text.lowercased()
        let forbiddenKeys: Set<String> = [
            "transcript", "transcripttext", "clipboard", "audio", "recording",
            "dictionary", "contact", "name", "filepath",
        ]
        let reportObject = try JSONSerialization.jsonObject(with: data)
        let reportKeys = jsonKeys(in: reportObject)
        let archive = temporaryFile("Kiki-Support-Diagnostic.zip")
        try? FileManager.default.removeItem(at: archive)
        try SupportBundleBuilder.createArchive(at: archive, modelReady: true)
        let archiveSize = (try? archive.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let extracted = temporaryFile("support-extracted")
        try FileManager.default.createDirectory(at: extracted, withIntermediateDirectories: true)
        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        unzip.arguments = ["-x", "-k", archive.path, extracted.path]
        try unzip.run()
        unzip.waitUntilExit()
        let extractedFiles = Set(
            (try? FileManager.default.contentsOfDirectory(atPath: extracted.path)) ?? []
        )
        let extractedJSON = (try? String(
            contentsOf: extracted.appendingPathComponent("diagnostics.json"),
            encoding: .utf8
        ))?.lowercased() ?? ""
        let extractedObject = try JSONSerialization.jsonObject(
            with: Data(extractedJSON.utf8)
        )
        let extractedKeys = jsonKeys(in: extractedObject)
        defer {
            try? FileManager.default.removeItem(at: archive)
            try? FileManager.default.removeItem(at: extracted)
        }
        guard reportKeys.isDisjoint(with: forbiddenKeys),
              extractedKeys.isDisjoint(with: forbiddenKeys),
              lowered.contains("appversion"),
              lowered.contains("osversion"),
              lowered.contains("permissionstatus"),
              lowered.contains("selectedmodel"),
              archiveSize > 100,
              unzip.terminationStatus == 0,
              extractedFiles == ["README.txt", "diagnostics.json"] else {
            throw failure(
                "support bundle allowlist files=\(extractedFiles.sorted()) archive=\(archiveSize) unzip=\(unzip.terminationStatus) forbidden=\(extractedKeys.intersection(forbiddenKeys).sorted())"
            )
        }
    }

    private static func checkPawprints() throws {
        let url = temporaryFile("pawprints.json")
        try? FileManager.default.removeItem(at: url)
        var enabled = false
        let store = PawprintsStore(fileURL: url, isEnabled: { enabled })
        guard !store.record(text: "This must never be stored", duration: 4, isPrivate: false),
              store.summary == .empty else { throw failure("Pawprints opt-in") }
        enabled = true
        guard !store.record(text: "five private words stay completely hidden", duration: 5, isPrivate: true),
              store.summary == .empty else { throw failure("Pawprints Private Session exclusion") }
        let day = Date(timeIntervalSince1970: 1_722_470_400)
        guard store.record(text: "Five useful aggregate words", duration: 6, isPrivate: false, now: day),
              store.record(text: "Three more words", duration: 4, isPrivate: false, now: day) else {
            throw failure("Pawprints aggregate persistence")
        }
        let summary = store.summary
        let diskText = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        guard summary.dictations == 2,
              summary.words == 7,
              summary.speakingSeconds == 10,
              summary.activeDays == 1,
              !diskText.contains("useful"),
              !diskText.contains("aggregate") else {
            throw failure("Pawprints aggregate-only storage")
        }
        guard store.reset(),
              store.summary == .empty,
              !FileManager.default.fileExists(atPath: url.path) else {
            throw failure("Pawprints complete reset")
        }
    }

    private static func checkPhraseBoundaries() throws {
        guard WholePhraseReplacer.replace("Ann", with: "Anne", in: "Ann met Annabelle") == "Anne met Annabelle"
        else { throw failure("phrase boundaries") }

        let silentLevel = VoiceLevelMeter.normalizedLevel(for: [Float](repeating: 0, count: 128))
        let quietLevel = VoiceLevelMeter.normalizedLevel(for: [Float](repeating: 0.006, count: 128))
        let conversationalLevel = VoiceLevelMeter.normalizedLevel(for: [Float](repeating: 0.03, count: 128))
        let speakingLevel = VoiceLevelMeter.normalizedLevel(for: [Float](repeating: 0.12, count: 128))
        let normalSpeech = (0..<760).map { index in
            Float(0.08 * sin(Double(index) * 0.31))
        }
        let forcefulSpeech = (0..<760).map { index in
            Float(0.55 * sin(Double(index) * 0.31))
        }
        let normalSpeechLevel = VoiceLevelMeter.normalizedLevel(for: normalSpeech)
        let forcefulSpeechLevel = VoiceLevelMeter.normalizedLevel(for: forcefulSpeech)
        var waveformModel = VoiceWaveformModel(barCount: KikiWaveformView.barCount)
        waveformModel.ingest(samples: normalSpeech)
        waveformModel.advanceFrame()
        let firstHistoryFrame = waveformModel.bars
        waveformModel.ingest(samples: forcefulSpeech)
        waveformModel.advanceFrame()
        let secondHistoryFrame = waveformModel.bars
        let visible = NSRect(x: 100, y: 200, width: 1_200, height: 800)
        let topRight = HUDPanel.fixedFrame(position: .topRight, visibleFrame: visible, width: 400, height: 60)
        let bottomLeft = HUDPanel.fixedFrame(position: .bottomLeft, visibleFrame: visible, width: 400, height: 60)
        guard ListeningDisplayMode.allCases == [.fullTranscript, .waveform, .hidden],
              ListeningDisplayPosition.allCases == [.bottom, .top, .topLeft, .topRight, .bottomLeft, .bottomRight, .nearTargetWindow],
              topRight.origin == NSPoint(x: 876, y: 908),
              bottomLeft.origin == NSPoint(x: 124, y: 232),
              silentLevel == 0,
              quietLevel > 0,
              conversationalLevel > quietLevel,
              speakingLevel > conversationalLevel,
              firstHistoryFrame.dropLast().allSatisfy({ $0 == 0 }),
              firstHistoryFrame.last ?? 0 > 0,
              secondHistoryFrame[KikiWaveformView.barCount - 2] == firstHistoryFrame.last,
              secondHistoryFrame.last ?? 0 > firstHistoryFrame.last ?? 0,
              AudioRecorder.captureInterval(inputSampleRate: 48_000) <= 1.0 / 30.0,
              VoiceWaveformModel.frameRate == 30,
              normalSpeechLevel < 0.40,
              forcefulSpeechLevel > 0.65,
              forcefulSpeechLevel < 0.85,
              HUDPanel.waveformUsesClearSurface,
              KikiWaveformView.barCount == 38,
              KikiWaveformView.usesAdaptiveOutline,
              KikiWaveformView.preferredSize == NSSize(width: 220, height: 34)
        else { throw failure("listening display modes") }
    }

    private static func checkVoiceStudio() throws {
        let selectionController = VoiceStudioWindowController()
        selectionController.prefillForDiagnostics("Read this selection")
        guard let selectionContent = selectionController.window?.contentView,
              let selectionEditor = findView(
                in: selectionContent,
                identifier: "kiki.voice.generation-editor"
              ) as? NSTextView,
              selectionEditor.string == "Read this selection",
              let consent = findView(
                in: selectionContent,
                identifier: "kiki.voice.consent"
              ) as? NSButton,
              consent.contentTintColor?.isEqual(KikiPalette.accentText) == true else {
            throw failure("Read Selection Voice Studio prefill")
        }
        let sampleCount = Int(21 * AudioRecorder.sampleRate)
        let clean = VoiceProfileStore.recordingQuality(samples: [Float](repeating: 0.08, count: sampleCount))
        let quiet = VoiceProfileStore.recordingQuality(samples: [Float](repeating: 0.001, count: sampleCount))
        let mouseDownSelector = #selector(NSResponder.mouseDown(with:))
        var methodCount: UInt32 = 0
        let methods = class_copyMethodList(KikiActionButton.self, &methodCount)
        let overridesMouseDown = methods.map { methods in
            UnsafeBufferPointer(start: methods, count: Int(methodCount)).contains {
                method_getName($0) == mouseDownSelector
            }
        } ?? false
        guard clean.canSave, !quiet.canSave, quiet.isTooQuiet else {
            throw failure("voice studio recording quality")
        }
        guard VoiceProfileStore.enrollmentScript.count < 200,
              !VoiceProfileStore.quickEnrollmentScript.contains("I consent"),
              VoiceProfileStore.quickEnrollmentScript.contains("private Kiki voice model"),
              VoiceProfileStore.fullEnrollmentScript.count > VoiceProfileStore.quickEnrollmentScript.count * 8,
              VoiceModelStore.manifestSize == VoiceModelStore.downloadSize else {
            throw failure("voice studio enrollment and model manifest")
        }
        guard !overridesMouseDown else {
            throw failure("action buttons must use native AppKit mouse tracking")
        }
    }

    private static func checkWindowInteractions() throws {
        guard WorkbenchTabTraversal.direction(for: []) == .forward,
              WorkbenchTabTraversal.direction(for: [.option]) == .forward,
              WorkbenchTabTraversal.direction(for: [.shift]) == .reverse,
              WorkbenchTabTraversal.direction(for: [.shift, .option]) == .reverse,
              WorkbenchTabTraversal.direction(for: [.control]) == nil,
              WorkbenchTabTraversal.direction(for: [.command]) == nil else {
            throw failure("Workbench must honor standard and all-controls Tab traversal")
        }
        let compositeScroll = NSScrollView()
        let compositeText = NSTextView()
        let compositeTable = NSTableView()
        let compositeScroller = NSScroller()
        guard !WorkbenchTabTraversal.isRouteKeyView(compositeScroll),
              WorkbenchTabTraversal.isRouteKeyView(compositeText),
              WorkbenchTabTraversal.isRouteKeyView(compositeTable),
              WorkbenchTabTraversal.isRouteKeyView(compositeScroller) else {
            throw failure("Workbench route traversal must register document controls, not composite containers")
        }
        let traversalWindow = WorkbenchWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let traversalRoot = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
        let traversalSidebar = KikiActionButton("Home", kind: .hardware, target: nil, action: nil)
        let traversalFirst = KikiActionButton("First", kind: .primary, target: nil, action: nil)
        let traversalSecond = KikiActionButton("Second", kind: .hardware, target: nil, action: nil)
        let traversalThird = KikiActionButton("Third", kind: .hardware, target: nil, action: nil)
        [traversalSidebar, traversalFirst, traversalSecond, traversalThird].enumerated().forEach { index, view in
            view.frame = NSRect(x: 20 + CGFloat(index) * 110, y: 120, width: 100, height: 40)
            traversalRoot.addSubview(view)
        }
        traversalWindow.contentView = traversalRoot
        traversalWindow.setRouteKeyViewBoundary(
            sidebarNavigation: [traversalSidebar],
            routeKeyViews: [traversalFirst, traversalSecond, traversalThird],
            defaultSidebarOrigin: traversalSidebar
        )
        traversalWindow.setPendingSidebarOrigin(traversalSidebar, isMouseNavigation: true)
        guard traversalWindow.performRouteTraversal(.forward),
              traversalWindow.firstResponder === traversalFirst,
              traversalWindow.performRouteTraversal(.forward),
              traversalWindow.firstResponder === traversalSecond,
              traversalWindow.performRouteTraversal(.forward),
              traversalWindow.firstResponder === traversalThird,
              traversalWindow.performRouteTraversal(.forward),
              traversalWindow.firstResponder === traversalSidebar,
              traversalWindow.performRouteTraversal(.forward),
              traversalWindow.firstResponder === traversalFirst,
              traversalWindow.performRouteTraversal(.reverse),
              traversalWindow.firstResponder === traversalSidebar else {
            throw failure("Workbench route-aware key loop must traverse, wrap, and restore its sidebar origin")
        }
        traversalWindow.setPendingSidebarOrigin(traversalSidebar, isMouseNavigation: true)
        guard traversalWindow.performRouteTraversal(.reverse),
              traversalWindow.firstResponder === traversalThird,
              traversalWindow.performRouteTraversal(.reverse),
              traversalWindow.firstResponder === traversalSecond else {
            throw failure("Workbench reverse traversal must enter the route from its sidebar origin")
        }
        let mouseDownSelector = #selector(NSResponder.mouseDown(with:))
        var methodCount: UInt32 = 0
        let methods = class_copyMethodList(KikiNavButton.self, &methodCount)
        let overridesMouseDown = methods.map { methods in
            UnsafeBufferPointer(start: methods, count: Int(methodCount)).contains {
                method_getName($0) == mouseDownSelector
            }
        } ?? false
        let diagnosticMeeting = MeetingTranscript(
            title: "Diagnostic Meeting",
            createdAt: Date(timeIntervalSince1970: 0),
            duration: 12,
            segments: [
                MeetingTranscriptSegment(startTime: 0, endTime: 5, speaker: "You", text: "Opening note."),
                MeetingTranscriptSegment(startTime: 6, endTime: 12, speaker: "Speaker 1", text: "Second note."),
            ],
            actionItems: []
        )
        let diagnosticSettings = SettingsWindowController()
        diagnosticSettings.prepareForDiagnostics(page: 2)
        let checkboxSettings = SettingsWindowController()
        checkboxSettings.prepareForDiagnostics(page: 0)
        guard let checkboxSettingsContent = checkboxSettings.window?.contentView,
              let launchAtLogin = findButton(in: checkboxSettingsContent, title: "Launch Kiki at login"),
              launchAtLogin.contentTintColor?.isEqual(KikiPalette.accentText) == true else {
            throw failure("checkbox labels must use the readable accent text token")
        }
        let checkup = KikiCheckupWindowController()
        guard let checkupContent = checkup.window?.contentView else {
            throw failure("Kiki Checkup content")
        }
        checkupContent.layoutSubtreeIfNeeded()
        guard
              findView(in: checkupContent, identifier: "kiki.checkup.microphone") is NSPopUpButton,
              findView(in: checkupContent, identifier: "kiki.checkup.input-meter") != nil,
              let inlineShortcutAction = findView(
                  in: checkupContent,
                  identifier: "kiki.checkup.readiness.shortcut.action"
              ) as? KikiActionButton,
              inlineShortcutAction.title == "Test shortcut",
              let shortcutGuidance = findView(
                  in: checkupContent,
                  identifier: "kiki.checkup.readiness.shortcut.guidance"
              ) as? NSTextField,
              shortcutGuidance.stringValue.contains("Click Test shortcut"),
              shortcutGuidance.stringValue.contains(Settings.dictationShortcut.displayString),
              findButton(in: checkupContent, title: "Try Dictation") != nil,
              findButton(in: checkupContent, title: "Refresh Checks") != nil,
              findView(in: checkupContent, identifier: "kiki.checkup.readiness") is NSTextField,
              let checkupEyebrow = findView(
                in: checkupContent,
                identifier: "kiki.checkup.eyebrow"
              ) as? NSTextField,
              checkupEyebrow.textColor?.isEqual(KikiPalette.accentText) == true else {
            throw failure("Kiki Checkup controls")
        }
        guard let shortcutStatusRow = findView(
                  in: checkupContent,
                  identifier: "kiki.checkup.readiness.shortcut"
              ),
              let shortcutDetail = findView(
                  in: checkupContent,
                  identifier: "kiki.checkup.readiness.shortcut.detail"
              ) as? NSTextField else {
            throw failure("Kiki Checkup shortcut row geometry")
        }
        for width in [850.0, 1_000.0, 1_240.0] {
            checkup.window?.setContentSize(NSSize(width: width, height: 700))
            checkupContent.layoutSubtreeIfNeeded()
            let guidanceFrame = shortcutGuidance.convert(shortcutGuidance.bounds, to: shortcutStatusRow)
            let detailFrame = shortcutDetail.convert(shortcutDetail.bounds, to: shortcutStatusRow)
            let actionFrame = inlineShortcutAction.convert(inlineShortcutAction.bounds, to: shortcutStatusRow)
            guard guidanceFrame.width >= 160,
                  guidanceFrame.height <= 60,
                  detailFrame.width >= 80,
                  detailFrame.height <= 22,
                  abs(actionFrame.width - 128) <= 1,
                  actionFrame.minX >= -0.5,
                  actionFrame.maxX <= shortcutStatusRow.bounds.maxX + 0.5,
                  actionFrame.maxY <= shortcutStatusRow.bounds.maxY + 0.5 else {
                throw failure(
                    "Kiki Checkup shortcut row must resist compression at width \(width) guidance=\(guidanceFrame) detail=\(detailFrame) action=\(actionFrame) row=\(shortcutStatusRow.bounds)"
                )
            }
        }
        var didRequestShortcutTest = false
        checkup.onTestShortcut = { didRequestShortcutTest = true }
        inlineShortcutAction.performClick(nil)
        guard didRequestShortcutTest else {
            throw failure("Kiki Checkup shortcut recovery must be actionable from its unresolved row")
        }
        checkup.armShortcutTest()
        guard shortcutGuidance.stringValue.contains(
                  Settings.activationMode.shortcutTestInstruction(for: Settings.dictationShortcut)
              ),
              inlineShortcutAction.isHidden else {
            throw failure("Kiki Checkup shortcut test must explain the next physical step")
        }
        checkup.update(snapshot: KikiCheckupSnapshot(
            microphoneAuthorized: true,
            inputResponding: true,
            accessibilityAuthorized: true,
            modelStatus: .downloading(model: .whisperBaseEnglish, fraction: 0.42),
            shortcutVerified: true,
            firstDictationCompleted: true
        ))
        checkupContent.layoutSubtreeIfNeeded()
        guard let checkupModelProgress = findView(
            in: checkupContent,
            identifier: "kiki.checkup.model-progress"
        ) as? NSProgressIndicator,
              !checkupModelProgress.isHidden,
              abs(checkupModelProgress.doubleValue - 0.42) < 0.001 else {
            throw failure("Kiki Checkup model download progress")
        }
        checkup.update(snapshot: KikiCheckupSnapshot(
            microphoneAuthorized: true,
            inputResponding: true,
            accessibilityAuthorized: true,
            modelStatus: .loading(model: .whisperBaseEnglish),
            shortcutVerified: true,
            firstDictationCompleted: true
        ))
        guard checkupModelProgress.isHidden else {
            throw failure("Kiki Checkup must hide download progress while loading")
        }
        guard let inCardPracticeButton = findView(
            in: checkupContent,
            identifier: "kiki.checkup.practice"
        ) as? KikiActionButton else {
            throw failure("Kiki Checkup in-card practice control")
        }
        checkup.updateDictationState(.recording)
        guard inCardPracticeButton.title == "Stop & Insert",
              inCardPracticeButton.isEnabled else {
            throw failure("Kiki Checkup must keep Stop & Insert beside the practice field")
        }
        checkup.updateDictationState(.idle)
        guard inCardPracticeButton.title == "Try Dictation",
              inCardPracticeButton.isEnabled else {
            throw failure("Kiki Checkup practice control must return to Try Dictation")
        }
        guard let refreshButton = findView(
                  in: checkupContent,
                  identifier: "kiki.checkup.footer.refresh"
              ) as? KikiActionButton,
              abs(refreshButton.frame.width - 140) <= 1,
              abs(refreshButton.frame.height - 36) <= 1,
              let practiceButton = findView(in: checkupContent, identifier: "kiki.checkup.practice"),
              practiceButton.frame.width > refreshButton.frame.width,
              abs(practiceButton.frame.height - 40) <= 1 else {
            throw failure("Kiki Checkup action hierarchy")
        }
        guard let checkupBody = findView(
            in: checkupContent,
            identifier: "kiki.checkup.body"
        ) as? NSStackView else {
            throw failure("Kiki Checkup responsive body")
        }
        checkup.window?.setContentSize(NSSize(width: 700, height: 650))
        checkupContent.layoutSubtreeIfNeeded()
        guard checkupBody.orientation == .vertical else {
            throw failure("Kiki Checkup must stack readiness and practice at narrow widths")
        }
        checkup.window?.setContentSize(NSSize(width: 1_000, height: 650))
        checkupContent.layoutSubtreeIfNeeded()
        guard checkupBody.orientation == .horizontal else {
            throw failure("Kiki Checkup must restore two columns when space is available")
        }
        let pawprints = PawprintsWindowController()
        guard let pawprintsContent = pawprints.window?.contentView,
              let pawprintsToggle = findView(
                in: pawprintsContent,
                identifier: "kiki.pawprints.enable"
              ) as? NSButton,
              pawprintsToggle.contentTintColor?.isEqual(KikiPalette.accentText) == true,
              let pawprintsEyebrow = findView(
                in: pawprintsContent,
                identifier: "kiki.pawprints.eyebrow"
              ) as? NSTextField,
              pawprintsEyebrow.textColor?.isEqual(KikiPalette.accentText) == true,
              findView(in: pawprintsContent, identifier: "kiki.pawprints.summary") != nil,
              findButton(in: pawprintsContent, title: "Reset Pawprints") != nil else {
            throw failure("Pawprints controls")
        }
        let meetingWindow = MeetingWindowController()
        meetingWindow.window?.contentView?.layoutSubtreeIfNeeded()
        guard let meetingContent = meetingWindow.window?.contentView,
              let identifySpeakers = findButton(in: meetingContent, title: "Identify Speakers…") as? KikiActionButton,
              let meetingExport = findView(in: meetingContent, identifier: "kiki.meeting.export") as? KikiActionButton,
              let meetingCopy = findView(in: meetingContent, identifier: "kiki.meeting.copy") as? KikiActionButton,
              findView(in: meetingContent, identifier: "kiki.meeting.empty") is KikiEmptyStateView,
              !identifySpeakers.isEnabled,
              !meetingExport.isEnabled,
              !meetingCopy.isEnabled,
              abs(meetingExport.frame.width - meetingCopy.frame.width) < 0.5,
              abs(meetingExport.frame.height - meetingCopy.frame.height) < 0.5,
              abs(meetingExport.frame.height - 42) < 0.5,
              identifySpeakers.contentTintColor?.isEqual(
                  KikiPalette.hardwareControlText.withAlphaComponent(0.88)
              ) == true else {
            throw failure("disabled Meeting Hardware button contrast")
        }

        let personalization = PersonalizationWindowController()
        personalization.prepareForDiagnostics(page: 0)
        let guidedStep = KikiGuidedStepView(
            number: 1,
            title: "Choose what changed",
            detail: "Select a suggestion to review."
        )
        guidedStep.frame = NSRect(x: 0, y: 0, width: 400, height: 90)
        guidedStep.layoutSubtreeIfNeeded()
        guard let personalizationContent = personalization.window?.contentView,
              let approveSuggestion = findView(
                in: personalizationContent,
                identifier: "kiki.personalization.approve"
              ) as? KikiActionButton,
              let ignoreSuggestion = findView(
                in: personalizationContent,
                identifier: "kiki.personalization.ignore"
              ) as? KikiActionButton,
              abs(approveSuggestion.frame.width - ignoreSuggestion.frame.width) < 0.5,
              abs(approveSuggestion.frame.height - ignoreSuggestion.frame.height) < 0.5,
              abs(approveSuggestion.frame.height - 42) < 0.5,
              findView(
                in: personalizationContent,
                identifier: "kiki.personalization.suggestions.surface"
              ) is KikiDataSurfaceView,
              let learningLayout = findView(
                in: personalizationContent,
                identifier: "kiki.personalization.learning-layout"
              ),
              let suggestionsSection = findView(
                in: personalizationContent,
                identifier: "kiki.personalization.suggestions-section"
              ),
              let suggestionsTable = findView(
                in: personalizationContent,
                identifier: "kiki.personalization.suggestions"
              ) as? NSTableView,
              let suggestionAppColumn = suggestionsTable.tableColumn(
                withIdentifier: NSUserInterfaceItemIdentifier("scope")
              ),
              let guidedBadge = findView(
                in: guidedStep,
                identifier: "kiki.guided-step.badge"
              ),
              let guidedNumber = findView(
                in: guidedStep,
                identifier: "kiki.guided-step.number"
              ),
              !approveSuggestion.isEnabled,
              !ignoreSuggestion.isEnabled else {
            throw failure("Personalization guided review state")
        }
        guard abs(learningLayout.bounds.width - suggestionsSection.bounds.width) < 1,
              suggestionsSection.bounds.width > 800,
              suggestionAppColumn.width > 300 else {
            throw failure(
                "full-width suggestions layout=\(learningLayout.bounds.width) section=\(suggestionsSection.bounds.width) app=\(suggestionAppColumn.width)"
            )
        }
        let guidedBadgeCenter = guidedBadge.convert(
            NSPoint(x: guidedBadge.bounds.midX, y: guidedBadge.bounds.midY),
            to: guidedStep
        )
        let guidedNumberCenter = guidedNumber.convert(
            NSPoint(x: guidedNumber.bounds.midX, y: guidedNumber.bounds.midY),
            to: guidedStep
        )
        guard abs(guidedBadgeCenter.x - guidedNumberCenter.x) <= 0.5,
              abs(guidedBadgeCenter.y - guidedNumberCenter.y) <= 0.5,
              guidedNumber.bounds.height < guidedBadge.bounds.height else {
            throw failure(
                "centered step number badge=\(guidedBadgeCenter) number=\(guidedNumberCenter) heights=\(guidedBadge.bounds.height)/\(guidedNumber.bounds.height)"
            )
        }

        let snippetPersonalization = PersonalizationWindowController()
        snippetPersonalization.prepareForDiagnostics(page: 2)
        let privateAppsPersonalization = PersonalizationWindowController()
        privateAppsPersonalization.prepareForDiagnostics(page: 3)
        let confidencePersonalization = PersonalizationWindowController()
        confidencePersonalization.prepareForDiagnostics(page: 4)
        guard let snippetContent = snippetPersonalization.window?.contentView,
              let snippetActions = findView(
                in: snippetContent,
                identifier: "kiki.personalization.snippets.actions"
              ) as? NSStackView,
              symmetricActionRow(snippetActions, count: 2),
              let privateAppsContent = privateAppsPersonalization.window?.contentView,
              let privateAppActions = findView(
                in: privateAppsContent,
                identifier: "kiki.personalization.private-apps.actions"
              ) as? NSStackView,
              symmetricActionRow(privateAppActions, count: 2),
              let confidenceContent = confidencePersonalization.window?.contentView,
              let confidenceActions = findView(
                in: confidenceContent,
                identifier: "kiki.personalization.confidence.actions"
              ) as? NSStackView,
              symmetricActionRow(confidenceActions, count: 3),
              let clearReviews = findView(
                in: confidenceContent,
                identifier: "kiki.personalization.clear-reviews"
              ) as? KikiActionButton,
              clearReviews.layer?.borderWidth == 1 else {
            throw failure("Personalization action-row symmetry")
        }

        let fileTranscription = FileTranscriptionWindowController()
        guard let fileContent = fileTranscription.window?.contentView,
              let fileExport = findView(
                in: fileContent,
                identifier: "kiki.file-transcript.export"
              ) as? KikiActionButton,
              findView(in: fileContent, identifier: "kiki.file-transcript.empty") is KikiEmptyStateView,
              !fileExport.isEnabled else {
            throw failure("File transcription guided empty state")
        }

        let history = HistoryWindowController()
        history.window?.contentView?.layoutSubtreeIfNeeded()
        guard let historyContent = history.window?.contentView,
              let historyCopy = findView(in: historyContent, identifier: "kiki.history.copy") as? KikiActionButton,
              let historyDelete = findView(in: historyContent, identifier: "kiki.history.delete") as? KikiActionButton,
              findView(in: historyContent, identifier: "kiki.history.table.surface") is KikiDataSurfaceView,
              let historyTable = findView(in: historyContent, identifier: "kiki.history.table") as? NSTableView,
              historyTable.columnAutoresizingStyle == .lastColumnOnlyAutoresizingStyle,
              abs(historyTable.rowHeight - 34) < 0.5,
              abs(historyCopy.frame.width - historyDelete.frame.width) < 0.5,
              abs(historyCopy.frame.height - historyDelete.frame.height) < 0.5,
              abs(historyCopy.frame.height - 42) < 0.5,
              !historyCopy.isEnabled,
              !historyDelete.isEnabled else {
            let copyFrame = (history.window?.contentView.flatMap {
                findView(in: $0, identifier: "kiki.history.copy")
            })?.frame ?? .zero
            let deleteFrame = (history.window?.contentView.flatMap {
                findView(in: $0, identifier: "kiki.history.delete")
            })?.frame ?? .zero
            throw failure("History selection-aware actions copy=\(copyFrame) delete=\(deleteFrame)")
        }

        let dictionary = CustomDictionaryWindowController()
        guard let dictionaryContent = dictionary.window?.contentView,
              let dictionaryAdd = findView(in: dictionaryContent, identifier: "kiki.dictionary.add") as? KikiActionButton,
              let dictionaryDelete = findView(in: dictionaryContent, identifier: "kiki.dictionary.delete") as? KikiActionButton,
              findView(in: dictionaryContent, identifier: "kiki.dictionary.table.surface") is KikiDataSurfaceView,
              !dictionaryAdd.isEnabled,
              !dictionaryDelete.isEnabled else {
            throw failure("Dictionary validation and empty state")
        }

        let speakerEditor = MeetingSpeakerEditorWindowController(transcript: diagnosticMeeting)
        guard let speakerContent = speakerEditor.window?.contentView,
              let renameSpeaker = findView(
                in: speakerContent,
                identifier: "kiki.meeting-speakers.rename"
              ) as? KikiActionButton,
              let assignSpeaker = findView(
                in: speakerContent,
                identifier: "kiki.meeting-speakers.assign"
              ) as? KikiActionButton,
              !renameSpeaker.isEnabled,
              !assignSpeaker.isEnabled else {
            throw failure("Meeting speaker guided workflow state")
        }
        let interactiveWindows: [NSWindowController] = [
            diagnosticSettings,
            checkboxSettings,
            checkup,
            pawprints,
            WhatsNewWindowController(),
            VoiceStudioWindowController(),
            meetingWindow,
            speakerEditor,
            personalization,
            snippetPersonalization,
            privateAppsPersonalization,
            confidencePersonalization,
            fileTranscription,
            history,
            dictionary,
        ]
        guard interactiveWindows.allSatisfy({ $0.window?.isMovableByWindowBackground == false }),
              !overridesMouseDown else {
            throw failure("interactive windows must use native AppKit mouse tracking")
        }

        var hitTestFailures: [String] = []
        for controller in interactiveWindows {
            guard let contentView = controller.window?.contentView else {
                throw failure("interactive window content")
            }
            contentView.layoutSubtreeIfNeeded()
            let controls = descendants(of: contentView).compactMap { $0 as? NSControl }
                .filter { !($0 is NSScroller) }
                .filter { !$0.isHidden && $0.alphaValue > 0.01 && $0.isEnabled && $0.action != nil }
            for control in controls {
                let center = NSPoint(x: control.bounds.midX, y: control.bounds.midY)
                let pointInContent = control.convert(center, to: contentView)
                let hit = contentView.hitTest(pointInContent)
                guard let hit, hit === control || hit.isDescendant(of: control) else {
                    let buttonTitle = (control as? NSButton)?.title ?? ""
                    let label = (!buttonTitle.isEmpty ? buttonTitle : control.toolTip)
                        ?? control.identifier?.rawValue
                        ?? String(describing: type(of: control))
                    hitTestFailures.append(
                        "\(controller.window?.title ?? "interactive window"): \(label) hit \(hit.map { String(describing: type(of: $0)) } ?? "nothing")"
                    )
                    continue
                }
            }
        }
        guard hitTestFailures.isEmpty else {
            throw failure("control hit testing [\(hitTestFailures.joined(separator: "; "))]")
        }

        guard let settingsContent = diagnosticSettings.window?.contentView,
              abs(settingsContent.bounds.width - 682) < 1,
              abs(settingsContent.bounds.height - 802) < 1,
              let modelsScroll = findView(in: settingsContent, identifier: "kiki.models.scroll") as? NSScrollView,
              let selectedCard = findView(in: settingsContent, identifier: "kiki.model.card.parakeetEnglish"),
              let controlBay = findView(in: selectedCard, identifier: "kiki.model.control-bay"),
              let divider = findView(in: selectedCard, identifier: "kiki.model.divider"),
              let dial = findView(in: selectedCard, identifier: "kiki.model.dial"),
              let analogMeter = findView(in: selectedCard, identifier: "kiki.model.analog-meter"),
              let modelAction = findView(in: selectedCard, identifier: "kiki.model.action") as? KikiActionButton,
              abs(selectedCard.bounds.width - 440) < 1,
              abs(selectedCard.bounds.height - 109) < 1,
              abs(controlBay.bounds.width - 72) < 1,
              abs(divider.bounds.width - 1) < 1,
              abs(dial.bounds.width - 42) < 1,
              abs(dial.bounds.height - 42) < 1,
              abs(analogMeter.bounds.width - 100) < 1,
              abs(analogMeter.bounds.height - 34) < 1,
              abs(modelAction.bounds.width - 65) < 1,
              !modelAction.isEnabled,
              modelAction.contentTintColor?.isEqual(
                  KikiPalette.hardwareControlText.withAlphaComponent(0.88)
              ) == true,
              !analogMeter.isHidden,
              modelsScroll.scrollerStyle == .overlay,
              modelsScroll.autohidesScrollers else {
            throw failure("Models must preserve the approved compact Studio Hardware layout")
        }

        let hardwareCard = KikiCardView()
        hardwareCard.frame = NSRect(x: 0, y: 0, width: 240, height: 100)
        hardwareCard.layoutSubtreeIfNeeded()
        let depthLayerNames = Set((hardwareCard.layer?.sublayers ?? []).compactMap(\.name))
        let hardwareButton = KikiActionButton("Use Model", kind: .hardware, target: nil, action: nil)
        let disabledHardwareButton = KikiActionButton("Identify Speakers…", kind: .hardware, target: nil, action: nil)
        disabledHardwareButton.isEnabled = false
        guard depthLayerNames.isSuperset(of: [
                  "kiki.card.matte-depth",
                  "kiki.card.inner-border",
              ]),
              !depthLayerNames.contains("kiki.card.radial-depth"),
              !depthLayerNames.contains("kiki.card.texture"),
              hardwareButton.intrinsicContentSize.height < 40,
              abs((hardwareButton.font?.pointSize ?? 0) - 11.5) < 0.1,
              hardwareButton.layer?.borderWidth == 1,
              hardwareButton.contentTintColor?.isEqual(KikiPalette.hardwareControlText) == true,
              disabledHardwareButton.contentTintColor?.isEqual(
                  KikiPalette.hardwareControlText.withAlphaComponent(0.88)
              ) == true else {
            throw failure("Studio Hardware matte depth treatment and compact controls")
        }

        let focusProbe = KikiActionButton("Focus Probe", target: nil, action: nil)
        guard focusProbe.focusRingType == .none else {
            throw failure("custom action buttons must not draw the system blue focus ring")
        }

        guard let mainMenu = NSApp.mainMenu,
              menuItem(in: mainMenu, action: #selector(NSText.selectAll(_:)), keyEquivalent: "a") != nil else {
            throw failure("Command-A must route Select All through the application Edit menu")
        }
    }

    private static func temporaryFile(_ name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("KikiDiagnostics-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent(name)
    }

    private static func findView(in root: NSView, identifier: String) -> NSView? {
        if root.identifier?.rawValue == identifier { return root }
        for subview in root.subviews {
            if let match = findView(in: subview, identifier: identifier) { return match }
        }
        return nil
    }

    private static func findButton(in root: NSView, title: String) -> NSButton? {
        if let button = root as? NSButton, button.title == title { return button }
        for subview in root.subviews {
            if let match = findButton(in: subview, title: title) { return match }
        }
        return nil
    }

    private static func descendants(of root: NSView) -> [NSView] {
        root.subviews.flatMap { [$0] + descendants(of: $0) }
    }

    private static func symmetricActionRow(_ row: NSStackView, count: Int) -> Bool {
        row.layoutSubtreeIfNeeded()
        guard row.arrangedSubviews.count == count,
              let first = row.arrangedSubviews.first else { return false }
        return abs(first.bounds.height - 42) < 1
            && row.arrangedSubviews.allSatisfy {
                abs($0.bounds.width - first.bounds.width) < 1
                    && abs($0.bounds.height - first.bounds.height) < 1
            }
    }

    private static func jsonKeys(in value: Any) -> Set<String> {
        if let dictionary = value as? [String: Any] {
            return dictionary.reduce(into: Set(dictionary.keys.map { $0.lowercased() })) { result, pair in
                result.formUnion(jsonKeys(in: pair.value))
            }
        }
        if let array = value as? [Any] {
            return array.reduce(into: Set<String>()) { result, item in
                result.formUnion(jsonKeys(in: item))
            }
        }
        return []
    }

    private static func menuItem(in menu: NSMenu, action: Selector, keyEquivalent: String) -> NSMenuItem? {
        for item in menu.items {
            if item.action == action, item.keyEquivalent == keyEquivalent { return item }
            if let submenu = item.submenu,
               let match = menuItem(in: submenu, action: action, keyEquivalent: keyEquivalent) {
                return match
            }
        }
        return nil
    }

    private static func failure(_ name: String) -> KikiError {
        KikiError("Feature diagnostic failed: \(name)")
    }
}
