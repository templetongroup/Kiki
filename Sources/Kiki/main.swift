import AppKit
import AVFoundation

MetalResources.configure()

// CLI mode for testing the transcription pipeline without the mic:
//   Kiki --transcribe-file /path/to/audio.(wav|aiff|m4a|mp3)
let args = CommandLine.arguments
if args.count >= 3, args[1] == "--transcribe-file" {
    do {
        guard let modelURL = ModelStore.activeModelURL() else {
            fputs("No Whisper model installed. Run scripts/download-model.sh first.\n", stderr)
            exit(1)
        }
        fputs("Loading model: \(modelURL.lastPathComponent)\n", stderr)
        let samples = try AudioFileLoader.load16kMono(url: URL(fileURLWithPath: args[2]))
        fputs("Audio: \(String(format: "%.1f", Double(samples.count) / 16000))s\n", stderr)
        let transcriber = try WhisperTranscriber(modelPath: modelURL.path, language: Settings.language)
        print(transcriber.transcribe(samples))
        exit(0)
    } catch {
        fputs("Error: \(error)\n", stderr)
        exit(1)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
