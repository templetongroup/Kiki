import AppKit
import AVFoundation
import MLX
import MLXAudioCore
import MLXAudioTTS

MetalResources.configure()

// CLI modes for testing the transcription pipeline without the mic:
//   Kiki --transcribe-file /path/to/audio.(wav|aiff|m4a|mp3)
//   Kiki --transcribe-live-file /path/to/audio.(wav|aiff|m4a|mp3)
let args = CommandLine.arguments
MainActor.assumeIsolated {
    _ = NSApplication.shared
    ApplicationMenu.install()
}

if args.count >= 5, args[1] == "--analyze-voice-consistency" {
    let audioURL = URL(fileURLWithPath: args[2])
    let boundaries = args[3...].compactMap(Double.init)
    Task {
        do {
            let model = try await Qwen3TTSModel.fromModelDirectory(VoiceModelStore.directory)
            let (_, audio) = try loadAudioArray(from: audioURL, sampleRate: model.sampleRate)
            let totalFrames = audio.dim(0)
            let frameBoundaries = [0]
                + boundaries.map { min(totalFrames, max(0, Int($0 * Double(model.sampleRate)))) }
                + [totalFrames]
            var embeddings: [[Float]] = []
            var levels: [Double] = []
            for index in 0..<(frameBoundaries.count - 1) {
                let section = audio[frameBoundaries[index]..<frameBoundaries[index + 1]]
                let samples = section.asArray(Float.self)
                let meanSquare = samples.reduce(0.0) { $0 + Double($1 * $1) } / Double(max(1, samples.count))
                levels.append(20 * log10(max(1e-12, sqrt(meanSquare))))
                let conditioning = try model.prepareReferenceConditioning(
                    refAudio: section,
                    refText: "Voice consistency diagnostic.",
                    language: "English"
                )
                guard let embedding = conditioning.speakerEmbedding else {
                    throw KikiError("The voice model did not produce a speaker embedding.")
                }
                embeddings.append(embedding.asArray(Float.self))
            }
            func cosine(_ lhs: [Float], _ rhs: [Float]) -> Double {
                let dot = zip(lhs, rhs).reduce(0.0) { $0 + Double($1.0 * $1.1) }
                let leftNorm = sqrt(lhs.reduce(0.0) { $0 + Double($1 * $1) })
                let rightNorm = sqrt(rhs.reduce(0.0) { $0 + Double($1 * $1) })
                return dot / max(1e-12, leftNorm * rightNorm)
            }
            for index in levels.indices {
                print("section \(index + 1): \(String(format: "%.2f", levels[index])) dBFS")
            }
            var similarities: [Double] = []
            for index in 0..<(embeddings.count - 1) {
                let value = cosine(embeddings[index], embeddings[index + 1])
                similarities.append(value)
                print("voice \(index + 1)-\(index + 2): \(String(format: "%.4f", value))")
            }
            let levelSpread = (levels.max() ?? 0) - (levels.min() ?? 0)
            let minimumSimilarity = similarities.min() ?? 1
            print("level spread: \(String(format: "%.2f", levelSpread)) dB")
            if levelSpread > 1 || minimumSimilarity < 0.95 {
                fputs("FAIL: generated sections are acoustically inconsistent\n", stderr)
                exit(1)
            }
            print("PASS: generated sections are acoustically consistent")
            exit(0)
        } catch {
            fputs("Error: \(error)\n", stderr)
            exit(1)
        }
    }
    RunLoop.main.run()
}
if args.count >= 2, args[1] == "--preview-ready-home" {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.finishLaunching()
        AppearanceController.apply()
        let home = GuidedWorkbenchHomeView()
        home.update(snapshot: KikiCheckupSnapshot(
            microphoneAuthorized: true,
            inputResponding: true,
            accessibilityAuthorized: true,
            modelStatus: .ready(model: .parakeetEnglish),
            shortcutVerified: true,
            firstDictationCompleted: true
        ))
        let controller = GuidedWorkbenchWindowController()
        controller.onRouteChange = { route in
            route.section == .home
                ? GuidedWorkbenchSurface(view: home, sizing: .fill)
                : nil
        }
        controller.select(GuidedWorkbenchRoute(section: .home))
        controller.window?.setContentSize(NSSize(width: 1_240, height: 840))
        controller.window?.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}

if args.count >= 2, args[1] == "--preview-dictation" || args[1] == "--preview-dictation-listening" {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.finishLaunching()
        AppearanceController.apply()
        let dictation = GuidedWorkbenchDictationView()
        dictation.update(
            state: args[1] == "--preview-dictation-listening" ? .recording : .idle,
            canUndo: false,
            canRetry: false
        )
        let controller = GuidedWorkbenchWindowController()
        controller.onRouteChange = { route in
            route.section == .dictation
                ? GuidedWorkbenchSurface(view: dictation, sizing: .fill)
                : nil
        }
        controller.select(GuidedWorkbenchRoute(section: .dictation))
        controller.window?.setContentSize(NSSize(width: 1_240, height: 840))
        controller.window?.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}

if args.count >= 2, args[1] == "--preview-voice-studio" {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.finishLaunching()
        AppearanceController.apply()
        let controller = VoiceStudioWindowController()
        controller.show()
        app.run()
    }
}

if args.count >= 2, args[1] == "--preview-file-transcription" {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.finishLaunching()
        AppearanceController.apply()
        let controller = FileTranscriptionWindowController()
        controller.showPreview(
            transcription: "Alex welcomed Jordan to the meeting and reviewed the launch plan.",
            sourceURL: URL(fileURLWithPath: "/tmp/Launch Interview.m4a")
        )
        app.run()
    }
}

if args.count >= 2, args[1] == "--preview-file-transcription-empty" {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.finishLaunching()
        AppearanceController.apply()
        let controller = FileTranscriptionWindowController()
        controller.show()
        app.run()
    }
}

if args.count >= 2, args[1] == "--preview-meeting" {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.finishLaunching()
        AppearanceController.apply()
        let segments = [
            MeetingTranscriptSegment(startTime: 0, endTime: 8, speaker: "Alex", text: "The purpose today is to finalize the launch plan."),
            MeetingTranscriptSegment(startTime: 9, endTime: 18, speaker: "Jordan", text: "We agreed to launch on September fifteenth and use the final blue artwork."),
            MeetingTranscriptSegment(startTime: 19, endTime: 28, speaker: "Alex", text: "I’ll send the final artwork this afternoon."),
            MeetingTranscriptSegment(startTime: 29, endTime: 38, speaker: "Jordan", text: "Could you schedule the final review with the web team?"),
        ]
        let meeting = MeetingTranscript(
            title: "Launch Planning",
            createdAt: Date(),
            duration: 38,
            segments: segments,
            actionItems: MeetingTranscript.actionItems(from: segments)
        )
        let controller = MeetingWindowController()
        controller.showPreview(transcript: meeting)
        app.run()
    }
}

if args.count >= 2, args[1] == "--preview-meeting-speakers" {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.finishLaunching()
        AppearanceController.apply()
        let segments = [
            MeetingTranscriptSegment(startTime: 0, endTime: 8, speaker: "You", text: "Let’s review the launch plan."),
            MeetingTranscriptSegment(startTime: 9, endTime: 18, speaker: "Speaker 1", text: "I’ll send the final artwork this afternoon."),
            MeetingTranscriptSegment(startTime: 19, endTime: 28, speaker: "Speaker 1", text: "The production schedule is ready."),
        ]
        let meeting = MeetingTranscript(
            title: "Launch Planning",
            createdAt: Date(),
            duration: 28,
            segments: segments,
            actionItems: MeetingTranscript.actionItems(from: segments)
        )
        let controller = MeetingSpeakerEditorWindowController(transcript: meeting)
        controller.showWindow(nil)
        controller.window?.center()
        controller.window?.makeKeyAndOrderFront(nil)
        app.run()
    }
}

if args.count >= 2, args[1] == "--preview-personalization" {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.finishLaunching()
        AppearanceController.apply()
        let controller = PersonalizationWindowController()
        let previewPage = args.count >= 3 ? Int(args[2]) ?? 0 : 0
        controller.show(page: previewPage)
        app.run()
    }
}

if args.count >= 2, args[1] == "--preview-history" {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.finishLaunching()
        AppearanceController.apply()
        let controller = HistoryWindowController()
        controller.show()
        app.run()
    }
}

if args.count >= 2, args[1] == "--preview-dictionary" {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.finishLaunching()
        AppearanceController.apply()
        let controller = CustomDictionaryWindowController()
        controller.show()
        app.run()
    }
}

if args.count >= 3, args[1] == "--self-test-splash-artwork" {
    MainActor.assumeIsolated {
        do {
            _ = NSApplication.shared
            try FeatureDiagnostics.checkSplashArtwork(
                referenceURL: URL(fileURLWithPath: args[2])
            )
            print("Kiki splash artwork diagnostic passed")
            exit(0)
        } catch {
            fputs("Error: \(error)\n", stderr)
            exit(1)
        }
    }
}

if args.count >= 3, args[1] == "--self-test-voice-studio-hero" {
    MainActor.assumeIsolated {
        do {
            _ = NSApplication.shared
            try FeatureDiagnostics.checkVoiceStudioHero(
                referenceURL: URL(fileURLWithPath: args[2])
            )
            print("Kiki Voice Studio hero diagnostic passed")
            exit(0)
        } catch {
            fputs("Error: \(error)\n", stderr)
            exit(1)
        }
    }
}

if args.count >= 3, args[1] == "--self-test-voice-enrollment" {
    MainActor.assumeIsolated {
        do {
            _ = NSApplication.shared
            try FeatureDiagnostics.checkVoiceEnrollment(
                fullScriptReferenceURL: URL(fileURLWithPath: args[2])
            )
            print("Kiki voice enrollment diagnostic passed")
            exit(0)
        } catch {
            fputs("Error: \(error)\n", stderr)
            exit(1)
        }
    }
}

if args.count >= 3, args[1] == "--self-test-waveform-audio" {
    MainActor.assumeIsolated {
        do {
            try FeatureDiagnostics.checkWaveformAudio(
                referenceURL: URL(fileURLWithPath: args[2])
            )
            print("Kiki real-voice waveform diagnostic passed")
            exit(0)
        } catch {
            fputs("Error: \(error)\n", stderr)
            exit(1)
        }
    }
}

if args.count >= 3, args[1] == "--create-local-voice-profile" {
    do {
        let source = URL(fileURLWithPath: args[2])
        let samples = try AudioFileLoader.load16kMono(url: source)
        let quality = VoiceProfileStore.recordingQuality(samples: samples)
        guard quality.canSave else { throw KikiError(quality.message) }
        let profile = try VoiceProfileStore.save(samples: samples, name: args.count >= 4 ? args[3] : "My Voice")
        print("Saved \(profile.name) at \(VoiceProfileStore.referenceAudioURL.path)")
        exit(0)
    } catch {
        fputs("Error: \(error)\n", stderr)
        exit(1)
    }
}

if args.count >= 2, args[1] == "--download-local-voice-model" {
    Task { @MainActor in
        do {
            var lastPercent = -1
            try await VoiceModelStore.download { progress in
                let percent = Int((progress.fraction * 100).rounded())
                if percent >= lastPercent + 5 || (percent == 100 && lastPercent != 100) {
                    lastPercent = percent
                    print("Local voice model: \(percent)%")
                }
            }
            print("Local voice model ready at \(VoiceModelStore.directory.path)")
            exit(0)
        } catch {
            fputs("Error: \(error)\n", stderr)
            exit(1)
        }
    }
    RunLoop.main.run()
}

if args.count >= 3, args[1] == "--synthesize-local-voice" {
    Task { @MainActor in
        do {
            guard let profile = VoiceProfileStore.load() else {
                throw KikiError("No local Kiki voice profile is installed.")
            }
            let engine = LocalVoiceSynthesisEngine()
            let output = try await engine.synthesize(text: args[2], profile: profile) { progress in
                print("Generated section \(progress.completedChunks)/\(progress.totalChunks)")
            }
            print(output.path)
            exit(0)
        } catch {
            fputs("Error: \(error)\n", stderr)
            exit(1)
        }
    }
    RunLoop.main.run()
}

if args.count >= 2, args[1] == "--self-test-features" {
    MainActor.assumeIsolated {
        do {
            try FeatureDiagnostics.run()
            print("Kiki feature diagnostics passed: checkup, undo/retry, privacy, support, Pawprints, selection, learning, meetings, voice halo, signal meter, and Voice Studio")
            exit(0)
        } catch {
            fputs("Error: \(error)\n", stderr)
            exit(1)
        }
    }
}

if args.count >= 2, args[1] == "--preview-waveform" {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        AppearanceController.apply()
        let hud = HUDPanel()
        let previewLevels: [CGFloat] = [0.10, 0.28, 0.62, 0.88, 0.46, 0.74, 0.22, 0.54]
        let previewSamples: (CGFloat) -> [Float] = { level in
            (0..<760).map { index in
                let carrier = sin(Float(index) * 0.31)
                let contour = 0.35 + 0.65 * abs(sin(Float(index) * 0.037))
                return Float(level) * carrier * contour
            }
        }
        var previewIndex = 0
        hud.showWaveform(samples: previewSamples(previewLevels[previewIndex]), reset: true)
        Timer.scheduledTimer(withTimeInterval: 0.11, repeats: true) { _ in
            MainActor.assumeIsolated {
                previewIndex = (previewIndex + 1) % previewLevels.count
                hud.showWaveform(samples: previewSamples(previewLevels[previewIndex]))
            }
        }
        app.run()
    }
}

if args.count >= 2, args[1] == "--preview-signal-meter" {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        AppearanceController.apply()
        let hud = HUDPanel()
        let previewLevels: [CGFloat] = [0.10, 0.28, 0.62, 0.88, 0.46, 0.74, 0.22, 0.54]
        let previewSamples: (CGFloat) -> [Float] = { level in
            (0..<760).map { index in
                let carrier = sin(Float(index) * 0.31)
                let contour = 0.35 + 0.65 * abs(sin(Float(index) * 0.037))
                return Float(level) * carrier * contour
            }
        }
        var previewIndex = 0
        hud.showSignalMeter(samples: previewSamples(previewLevels[previewIndex]), reset: true)
        Timer.scheduledTimer(withTimeInterval: 0.11, repeats: true) { _ in
            MainActor.assumeIsolated {
                previewIndex = (previewIndex + 1) % previewLevels.count
                hud.showSignalMeter(samples: previewSamples(previewLevels[previewIndex]))
            }
        }
        app.run()
    }
}

if args.count >= 2, args[1] == "--preview-full-transcript" {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        AppearanceController.apply()
        let hud = HUDPanel()
        let phrases = [
            "Kiki is listening locally.",
            "The live transcript follows your voice as you continue speaking.",
            "Older words move beyond the left edge instead of hiding what you just said.",
            "The newest words always remain visible here.",
        ]
        var transcript = ""
        var phraseIndex = 0
        hud.showListening()
        Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true) { _ in
            MainActor.assumeIsolated {
                transcript += (transcript.isEmpty ? "" : " ") + phrases[phraseIndex]
                phraseIndex = (phraseIndex + 1) % phrases.count
                hud.showListening(transcript: transcript)
            }
        }
        app.run()
    }
}

if args.count >= 2, args[1] == "--preview-model-preparation" {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        AppearanceController.apply()
        let hud = HUDPanel()
        if args.count >= 3, args[2] == "loading" {
            hud.showModelPreparation(.loading(model: .whisperBaseEnglish))
        } else {
            hud.showModelPreparation(.downloading(model: .whisperBaseEnglish, fraction: 0.42))
        }
        app.run()
    }
}

if args.count >= 3, args[1] == "--self-test-voice-generation-routing" {
    let requestedText = args[2]
    Task {
        do {
            guard let profile = VoiceProfileStore.load() else {
                throw KikiError("No saved voice profile is available for the routing diagnostic.")
            }
            let engine = LocalVoiceSynthesisEngine()
            let startedAt = Date()
            let output = try await engine.synthesize(text: requestedText, profile: profile) { progress in
                fputs("Progress \(progress.completedChunks)/\(progress.totalChunks)\n", stderr)
            }
            fputs("Elapsed: \(Date().timeIntervalSince(startedAt))s\n", stderr)
            print(output.path)
            exit(0)
        } catch {
            fputs("Error: \(error)\n", stderr)
            exit(1)
        }
    }
    RunLoop.main.run()
}

if args.count >= 2, args[1] == "--preview-checkup-model-preparation" {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.finishLaunching()
        AppearanceController.apply()
        let controller = KikiCheckupWindowController()
        let status: ModelPreparationStatus = args.count >= 3 && args[2] == "loading"
            ? .loading(model: .whisperBaseEnglish)
            : .downloading(model: .whisperBaseEnglish, fraction: 0.42)
        controller.update(snapshot: KikiCheckupSnapshot(
            microphoneAuthorized: true,
            inputResponding: true,
            accessibilityAuthorized: true,
            modelStatus: status,
            shortcutVerified: true,
            firstDictationCompleted: true
        ))
        controller.show()
        app.run()
    }
}

if args.count >= 2, args[1] == "--self-test-hud" {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let hud = HUDPanel()
        hud.showModelPreparation(.downloading(model: .whisperBaseEnglish, fraction: 0.42))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard hud.isVisibleOnScreen,
                  hud.diagnosticModelStatusText == "Downloading Whisper Base — English · 42%",
                  abs((hud.diagnosticModelProgressValue ?? 0) - 0.42) < 0.001 else {
                fputs("Error: Kiki model download progress is not visible or accurate.\n", stderr)
                exit(1)
            }
            hud.showModelPreparation(.loading(model: .whisperBaseEnglish))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                guard hud.isVisibleOnScreen,
                      hud.diagnosticModelStatusText == "Loading Whisper Base — English…",
                      hud.diagnosticModelProgressValue == nil else {
                    fputs("Error: Kiki model loading state is ambiguous.\n", stderr)
                    exit(1)
                }
                hud.showListening()
                guard hud.diagnosticTranscriptText.contains("to stop and insert") else {
                    fputs("Error: Kiki listening state does not explain how to finish dictation.\n", stderr)
                    exit(1)
                }
                hud.showListening(transcript: "Live transcription window test")
                guard hud.isVisibleOnScreen else {
                    fputs("Error: Kiki full transcription window is not visible on any screen.\n", stderr)
                    exit(1)
                }
                let rollingTranscript = "Opening words that should leave the visible edge. "
                    + String(repeating: "Ongoing speech keeps moving forward. ", count: 12)
                    + "These are the newest words."
                hud.showListening(transcript: rollingTranscript)
                guard hud.diagnosticTranscriptText.hasPrefix("…"),
                      !hud.diagnosticTranscriptText.contains("Opening words"),
                      hud.diagnosticTranscriptText.hasSuffix("These are the newest words."),
                      hud.diagnosticTranscriptLineBreakMode == .byTruncatingHead else {
                    fputs("Error: Kiki full transcript does not keep the newest speech visible.\n", stderr)
                    exit(1)
                }
                hud.showWaveform(samples: [Float](repeating: 0.08, count: 760))
                hud.showSignalMeter(samples: [Float](repeating: 0.08, count: 760), reset: true)
                hud.hide()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    guard !hud.isVisibleOnScreen else {
                        fputs("Error: Kiki listening display did not hide.\n", stderr)
                        exit(1)
                    }
                    print("Kiki listening displays passed: model download, model loading, transcript, voice halo, signal meter, hidden")
                    exit(0)
                }
            }
        }
        app.run()
    }
}

if args.count >= 2, args[1] == "--self-test-transient-hud" {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let controller = DictationController()
        controller.showPasteFallbackForDiagnostics()
        guard controller.isTransientHUDVisibleForDiagnostics else {
            fputs("Error: Kiki paste fallback HUD did not appear.\n", stderr)
            exit(1)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.25) {
            guard !controller.isTransientHUDVisibleForDiagnostics else {
                fputs("Error: Kiki paste fallback HUD remained visible after its dismissal deadline.\n", stderr)
                exit(1)
            }
            print("Kiki paste fallback HUD dismissed after its deadline")
            exit(0)
        }
        app.run()
    }
}

if args.count >= 2, args[1] == "--preview-settings" {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.finishLaunching()
        AppearanceController.apply()
        let controller = SettingsWindowController()
        controller.onModelChange = { model in
            Settings.transcriptionModel = model
        }
        let previewPage = args.count >= 3 ? Int(args[2]) : nil
        controller.show(page: previewPage)
        app.run()
    }
}

if args.count >= 2, args[1] == "--benchmark-postprocessing" {
    MainActor.assumeIsolated {
        let average = FeatureDiagnostics.benchmarkPostProcessing()
        print(String(format: "Average deterministic post-processing: %.2f ms (2,002 context terms)", average * 1_000))
        exit(average < 0.050 ? 0 : 1)
    }
}

if args.count >= 3, args[1] == "--transcribe-live-file" {
    let audioURL = URL(fileURLWithPath: args[2])
    Task { @MainActor in
        do {
            let samples = try AudioFileLoader.load16kMono(url: audioURL)
            let selectedModel = Settings.transcriptionModel
            guard selectedModel.isParakeet else {
                throw KikiError("Live preview diagnostics require a Parakeet model.")
            }

            fputs("Audio: \(String(format: "%.1f", Double(samples.count) / 16000))s\n", stderr)
            fputs("Loading model: \(selectedModel.displayName)\n", stderr)
            let transcriber = try await ParakeetTranscriber.load(model: selectedModel)
            let feed = AudioSampleFeed()
            let startedAt = Date()
            let session = transcriber.makeLiveSession(audio: feed.stream) { text in
                let elapsed = Date().timeIntervalSince(startedAt)
                print(String(format: "PARTIAL +%.2fs: %@", elapsed, text))
            }
            let chunkSize = 1600
            for start in stride(from: 0, to: samples.count, by: chunkSize) {
                feed.yield(Array(samples[start..<min(start + chunkSize, samples.count)]))
                try await Task.sleep(for: .milliseconds(100))
            }
            feed.finish()
            await session.finish()
            exit(0)
        } catch {
            fputs("Error: \(error)\n", stderr)
            exit(1)
        }
    }
    RunLoop.main.run()
}

if args.count >= 3, args[1] == "--transcribe-file" {
    do {
        let samples = try AudioFileLoader.load16kMono(url: URL(fileURLWithPath: args[2]))
        fputs("Audio: \(String(format: "%.1f", Double(samples.count) / 16000))s\n", stderr)

        let selectedModel = Settings.transcriptionModel
        fputs("Loading model: \(selectedModel.displayName)\n", stderr)
        if selectedModel.isParakeet {
            Task {
                do {
                    let transcriber = try await ParakeetTranscriber.load(model: selectedModel)
                    print(await transcriber.transcribe(samples))
                    exit(0)
                } catch {
                    fputs("Error: \(error)\n", stderr)
                    exit(1)
                }
            }
            RunLoop.main.run()
        } else {
            guard let modelURL = ModelStore.modelURL(for: selectedModel) else {
                throw KikiError("Selected Whisper model is not installed.")
            }
            let transcriber = try WhisperTranscriber(modelPath: modelURL.path, language: Settings.language)
            print(transcriber.transcribe(samples))
        }
        exit(0)
    } catch {
        fputs("Error: \(error)\n", stderr)
        exit(1)
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
