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
        try checkDictationMenuCopy()
        try checkKikiCheckup()
        try checkUndoAndRetry()
        try checkPrivateSession()
        try checkSupportBundle()
        try checkPawprints()
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

    private static func checkDictationMenuCopy() throws {
        guard DictationMenuCopy.start == "Start Dictation into Current App (⌃⌥D)",
              DictationMenuCopy.stop == "Stop, Transcribe, and Insert (⌃⌥D)",
              DictationMenuCopy.idleStatus.contains("inserts into the current app"),
              DictationMenuCopy.recordingStatus.contains("Click again to stop and insert") else {
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
            modelReady: true,
            shortcutVerified: true,
            firstDictationCompleted: true
        )
        let ready = KikiCheckupSnapshot(
            microphoneAuthorized: true,
            inputResponding: true,
            accessibilityAuthorized: true,
            modelReady: true,
            shortcutVerified: true,
            firstDictationCompleted: true
        )
        guard !blocked.isReady,
              ready.isReady,
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
              findButton(in: checkupContent, title: "Test Shortcut") != nil,
              findButton(in: checkupContent, title: "Begin Practice Dictation") != nil,
              findButton(in: checkupContent, title: "Refresh Checks") != nil,
              findView(in: checkupContent, identifier: "kiki.checkup.readiness") is NSTextField,
              let checkupEyebrow = findView(
                in: checkupContent,
                identifier: "kiki.checkup.eyebrow"
              ) as? NSTextField,
              checkupEyebrow.textColor?.isEqual(KikiPalette.accentText) == true else {
            throw failure("Kiki Checkup controls")
        }
        let footerButtonIDs = [
            "kiki.checkup.footer.microphone",
            "kiki.checkup.footer.accessibility",
            "kiki.checkup.footer.shortcut",
            "kiki.checkup.footer.refresh",
        ]
        let footerWidths = footerButtonIDs.compactMap {
            findView(in: checkupContent, identifier: $0)?.frame.width
        }
        let footerHeights = footerButtonIDs.compactMap {
            findView(in: checkupContent, identifier: $0)?.frame.height
        }
        guard footerWidths.count == footerButtonIDs.count,
              footerHeights.count == footerButtonIDs.count,
              let minimumFooterWidth = footerWidths.min(),
              let maximumFooterWidth = footerWidths.max(),
              let minimumFooterHeight = footerHeights.min(),
              let maximumFooterHeight = footerHeights.max(),
              maximumFooterWidth - minimumFooterWidth <= 1,
              maximumFooterHeight - minimumFooterHeight <= 1,
              abs(maximumFooterHeight - 40) <= 1,
              let practiceButton = findView(in: checkupContent, identifier: "kiki.checkup.practice"),
              practiceButton.frame.width > maximumFooterWidth,
              abs(practiceButton.frame.height - maximumFooterHeight) <= 1 else {
            throw failure("Kiki Checkup symmetric action layout")
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
        guard let meetingContent = meetingWindow.window?.contentView,
              let identifySpeakers = findButton(in: meetingContent, title: "Identify Speakers…") as? KikiActionButton,
              let meetingExport = findView(in: meetingContent, identifier: "kiki.meeting.export") as? KikiActionButton,
              let meetingCopy = findView(in: meetingContent, identifier: "kiki.meeting.copy") as? KikiActionButton,
              findView(in: meetingContent, identifier: "kiki.meeting.empty") is KikiEmptyStateView,
              !identifySpeakers.isEnabled,
              !meetingExport.isEnabled,
              !meetingCopy.isEnabled,
              identifySpeakers.contentTintColor?.isEqual(
                  KikiPalette.hardwareControlText.withAlphaComponent(0.88)
              ) == true else {
            throw failure("disabled Meeting Hardware button contrast")
        }

        let personalization = PersonalizationWindowController()
        personalization.prepareForDiagnostics(page: 0)
        guard let personalizationContent = personalization.window?.contentView,
              let approveSuggestion = findView(
                in: personalizationContent,
                identifier: "kiki.personalization.approve"
              ) as? KikiActionButton,
              let ignoreSuggestion = findView(
                in: personalizationContent,
                identifier: "kiki.personalization.ignore"
              ) as? KikiActionButton,
              findView(
                in: personalizationContent,
                identifier: "kiki.personalization.suggestions.surface"
              ) is KikiDataSurfaceView,
              !approveSuggestion.isEnabled,
              !ignoreSuggestion.isEnabled else {
            throw failure("Personalization guided review state")
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
        guard let historyContent = history.window?.contentView,
              let historyCopy = findView(in: historyContent, identifier: "kiki.history.copy") as? KikiActionButton,
              let historyDelete = findView(in: historyContent, identifier: "kiki.history.delete") as? KikiActionButton,
              findView(in: historyContent, identifier: "kiki.history.table.surface") is KikiDataSurfaceView,
              !historyCopy.isEnabled,
              !historyDelete.isEnabled else {
            throw failure("History selection-aware actions")
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
