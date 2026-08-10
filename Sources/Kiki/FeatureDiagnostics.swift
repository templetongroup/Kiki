import AppKit
import Foundation
import ObjectiveC.runtime

@MainActor
enum FeatureDiagnostics {
    static func run() throws {
        try checkCorrectionMemory()
        try checkVoiceSnippets()
        try checkContextVocabulary()
        try checkMeetingExports()
        try checkFileTranscriptExports()
        try checkPhraseBoundaries()
        try checkWindowInteractions()
        try checkVoiceStudio()
    }

    static func benchmarkPostProcessing(iterations: Int = 100) -> TimeInterval {
        let store = ContextVocabularyStore(fileURL: temporaryFile("benchmark-context.json"))
        let syntheticTerms = (0..<2_000).map { "ProjectTerm\($0)" } + ["Ricciardi", "Kubernetes"]
        store.add(values: syntheticTerms, source: .project)
        let sample = "Tony Ricciardl will review Kubernetez with the team tomorrow morning."
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
              VoiceEnrollmentMode.full.explanation.contains("better accuracy") else {
            throw failure("full voice enrollment script")
        }

        let controller = VoiceStudioWindowController()
        guard let contentView = controller.window?.contentView,
              findView(in: contentView, identifier: "kiki.voice.enrollment-mode") is NSSegmentedControl,
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
              ) as? NSImageView,
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
        store.suggest(heard: "Riccardi", replacement: "Ricciardi", bundleIdentifier: "com.apple.mail")
        guard let suggestion = store.suggestions.first else { throw failure("correction suggestion") }
        store.approve(suggestion, scopeToApp: true)
        guard store.apply(to: "Tony Riccardi", bundleIdentifier: "com.apple.mail") == "Tony Ricciardi",
              store.apply(to: "Tony Riccardi", bundleIdentifier: "com.apple.TextEdit") == "Tony Riccardi"
        else { throw failure("correction scoping") }
    }

    private static func checkVoiceSnippets() throws {
        let store = VoiceSnippetStore(fileURL: temporaryFile("snippets.json"))
        store.add(trigger: "insert status", template: "Status: complete")
        guard store.expansion(for: "Insert status.") == "Status: complete",
              store.expansion(for: "Please insert status here") == nil
        else { throw failure("voice snippet matching") }
    }

    private static func checkContextVocabulary() throws {
        let previous = Settings.useContextVocabulary
        Settings.useContextVocabulary = true
        defer { Settings.useContextVocabulary = previous }
        let store = ContextVocabularyStore(fileURL: temporaryFile("context.json"))
        store.add(values: ["Ricciardi", "Kubernetes"], source: .manual)
        guard store.apply(to: "Ricciardl uses Kubernetez", bundleIdentifier: nil) == "Ricciardi uses Kubernetes",
              store.apply(to: "This is ordinary prose", bundleIdentifier: nil) == "This is ordinary prose"
        else { throw failure("context vocabulary") }
    }

    private static func checkMeetingExports() throws {
        let permissionError = MeetingCaptureStartError.systemAudioPermissionRequired
        let segments = [
            MeetingTranscriptSegment(startTime: 0, endTime: 5, speaker: "You", text: "I will send the proposal."),
            MeetingTranscriptSegment(startTime: 6, endTime: 12, speaker: "Speaker 1", text: "Please schedule the review."),
        ]
        let meeting = MeetingTranscript(
            title: "Planning",
            createdAt: Date(timeIntervalSince1970: 0),
            duration: 12,
            segments: segments,
            actionItems: MeetingTranscript.actionItems(from: segments)
        )
        let renamed = meeting.renamingSpeaker(from: "Speaker 1", to: "Tony")
        let assigned = renamed.assigningSpeaker("Anna", to: [segments[0].id])
        let sentenceRows = MeetingTranscriptSegment.sentenceSegments(
            startTime: 0,
            endTime: 12,
            speaker: "Speaker 1",
            text: "First person speaking. Second person answering!"
        )
        guard meeting.markdown.contains("Possible action items"),
              meeting.srt.contains("00:00:00,000 --> 00:00:05,000"),
              meeting.vtt.hasPrefix("WEBVTT"),
              meeting.actionItems.count == 2,
              !renamed.markdown.contains("Speaker 1"),
              renamed.markdown.contains("Tony"),
              renamed.srt.contains("Tony:"),
              renamed.vtt.contains("<v Tony>"),
              assigned.speakerNames == ["Anna", "Tony"],
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
        guard VoiceProfileStore.enrollmentScript.count > 250,
              !VoiceProfileStore.quickEnrollmentScript.contains("I consent"),
              VoiceProfileStore.quickEnrollmentScript.contains("keep this recording private on my Mac"),
              VoiceProfileStore.fullEnrollmentScript.count > VoiceProfileStore.quickEnrollmentScript.count * 8,
              VoiceModelStore.manifestSize == VoiceModelStore.downloadSize else {
            throw failure("voice studio enrollment and model manifest")
        }
        guard !overridesMouseDown else {
            throw failure("action buttons must use native AppKit mouse tracking")
        }
    }

    private static func checkWindowInteractions() throws {
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
        let interactiveWindows: [NSWindowController] = [
            diagnosticSettings,
            VoiceStudioWindowController(),
            MeetingWindowController(),
            MeetingSpeakerEditorWindowController(transcript: diagnosticMeeting),
            PersonalizationWindowController(),
            FileTranscriptionWindowController(),
            HistoryWindowController(),
            CustomDictionaryWindowController(),
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
              let modelAction = findView(in: selectedCard, identifier: "kiki.model.action"),
              abs(selectedCard.bounds.width - 440) < 1,
              abs(selectedCard.bounds.height - 109) < 1,
              abs(controlBay.bounds.width - 72) < 1,
              abs(divider.bounds.width - 1) < 1,
              abs(dial.bounds.width - 42) < 1,
              abs(dial.bounds.height - 42) < 1,
              abs(analogMeter.bounds.width - 100) < 1,
              abs(analogMeter.bounds.height - 34) < 1,
              abs(modelAction.bounds.width - 65) < 1,
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
        guard depthLayerNames.isSuperset(of: [
                  "kiki.card.matte-depth",
                  "kiki.card.inner-border",
              ]),
              !depthLayerNames.contains("kiki.card.radial-depth"),
              !depthLayerNames.contains("kiki.card.texture"),
              hardwareButton.intrinsicContentSize.height < 40,
              abs((hardwareButton.font?.pointSize ?? 0) - 11.5) < 0.1,
              hardwareButton.layer?.borderWidth == 1 else {
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
