import AppKit
import AVFoundation

MetalResources.configure()

// CLI modes for testing the transcription pipeline without the mic:
//   Kiki --transcribe-file /path/to/audio.(wav|aiff|m4a|mp3)
//   Kiki --transcribe-live-file /path/to/audio.(wav|aiff|m4a|mp3)
let args = CommandLine.arguments
MainActor.assumeIsolated {
    _ = NSApplication.shared
    ApplicationMenu.install()
}
if args.count >= 2, args[1] == "--preview-voice-studio" {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.finishLaunching()
        AppearanceController.apply()
        if ProcessInfo.processInfo.environment["KIKI_PREVIEW_APPEARANCE"] == "dark" {
            app.appearance = NSAppearance(named: .darkAqua)
        } else if ProcessInfo.processInfo.environment["KIKI_PREVIEW_APPEARANCE"] == "light" {
            app.appearance = NSAppearance(named: .aqua)
        }
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
            transcription: "Tony welcomed Anna to the meeting and reviewed the launch plan.",
            sourceURL: URL(fileURLWithPath: "/tmp/Launch Interview.m4a")
        )
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
            print("Kiki feature diagnostics passed: learning, snippets, context, meetings, boundaries, voice studio")
            exit(0)
        } catch {
            fputs("Error: \(error)\n", stderr)
            exit(1)
        }
    }
}

if args.count >= 2, args[1] == "--self-test-hud" {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let hud = HUDPanel()
        hud.showListening(transcript: "Live transcription window test")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard hud.isVisibleOnScreen else {
                fputs("Error: Kiki full transcription window is not visible on any screen.\n", stderr)
                exit(1)
            }
            hud.showWaveform(level: 0.8)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                guard hud.isVisibleOnScreen else {
                    fputs("Error: Kiki waveform is not visible on any screen.\n", stderr)
                    exit(1)
                }
                hud.hide()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    guard !hud.isVisibleOnScreen else {
                        fputs("Error: Kiki listening display did not hide.\n", stderr)
                        exit(1)
                    }
                    print("Kiki listening displays passed: full transcript, waveform, hidden")
                    exit(0)
                }
            }
        }
        app.run()
    }
}

if args.count >= 2, args[1] == "--preview-settings" {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        AppearanceController.apply()
        if ProcessInfo.processInfo.environment["KIKI_PREVIEW_APPEARANCE"] == "dark" {
            app.appearance = NSAppearance(named: .darkAqua)
        } else if ProcessInfo.processInfo.environment["KIKI_PREVIEW_APPEARANCE"] == "light" {
            app.appearance = NSAppearance(named: .aqua)
        }
        let controller = SettingsWindowController()
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
            let semaphore = DispatchSemaphore(value: 0)
            var transcription = ""
            var loadError: Error?
            Task {
                do {
                    let transcriber = try await ParakeetTranscriber.load(model: selectedModel)
                    transcription = await transcriber.transcribe(samples)
                } catch {
                    loadError = error
                }
                semaphore.signal()
            }
            semaphore.wait()
            if let loadError { throw loadError }
            print(transcription)
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
