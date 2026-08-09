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
        try checkPhraseBoundaries()
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
              findView(in: contentView, identifier: "kiki.voice.enrollment-script") is NSTextView else {
            throw failure("voice enrollment mode interface")
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
            MeetingTranscriptSegment(startTime: 6, endTime: 12, speaker: "Others", text: "Please schedule the review."),
        ]
        let meeting = MeetingTranscript(
            title: "Planning",
            createdAt: Date(timeIntervalSince1970: 0),
            duration: 12,
            segments: segments,
            actionItems: MeetingTranscript.actionItems(from: segments)
        )
        guard meeting.markdown.contains("Possible action items"),
              meeting.srt.contains("00:00:00,000 --> 00:00:05,000"),
              meeting.vtt.hasPrefix("WEBVTT"),
              meeting.actionItems.count == 2,
              permissionError.requiresScreenRecordingSettings,
              permissionError.localizedDescription.contains("Zoom"),
              !MeetingCaptureStartError.microphoneUnavailable("test").requiresScreenRecordingSettings
        else { throw failure("meeting exports") }
    }

    private static func checkPhraseBoundaries() throws {
        guard WholePhraseReplacer.replace("Ann", with: "Anne", in: "Ann met Annabelle") == "Anne met Annabelle"
        else { throw failure("phrase boundaries") }

        let silentLevel = VoiceLevelMeter.normalizedLevel(for: [Float](repeating: 0, count: 128))
        let speakingLevel = VoiceLevelMeter.normalizedLevel(for: [Float](repeating: 0.12, count: 128))
        guard ListeningDisplayMode.allCases == [.fullTranscript, .waveform, .hidden],
              silentLevel == 0,
              speakingLevel > 0.5
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

    private static func failure(_ name: String) -> KikiError {
        KikiError("Feature diagnostic failed: \(name)")
    }
}
