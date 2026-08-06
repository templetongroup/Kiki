import AppKit
import AVFoundation

MetalResources.configure()

// CLI modes for testing the transcription pipeline without the mic:
//   Kiki --transcribe-file /path/to/audio.(wav|aiff|m4a|mp3)
//   Kiki --transcribe-live-file /path/to/audio.(wav|aiff|m4a|mp3)
let args = CommandLine.arguments
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
            let session = transcriber.makeLiveSession(audio: feed.stream) { text in
                print("PARTIAL: \(text)")
            }
            let chunkSize = 1600
            for start in stride(from: 0, to: samples.count, by: chunkSize) {
                feed.yield(Array(samples[start..<min(start + chunkSize, samples.count)]))
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
