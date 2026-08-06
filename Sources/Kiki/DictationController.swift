import AppKit
import AVFoundation

enum DictationState {
    case noModel
    case loadingModel
    case idle
    case recording
    case transcribing
}

/// Owns the record → transcribe → insert pipeline. All entry points must be
/// called on the main thread; transcription runs on a background queue.
final class DictationController {
    var onStateChange: ((DictationState) -> Void)?

    private(set) var state: DictationState = .loadingModel {
        didSet { onStateChange?(state) }
    }

    private let recorder = AudioRecorder()
    private var transcriber: WhisperTranscriber?
    private let transcribeQueue = DispatchQueue(label: "kiki.transcribe", qos: .userInitiated)
    private let hud = HUDPanel()
    private var recordingStartedAt: Date?

    var activeModelName: String? {
        ModelStore.activeModelURL()?.lastPathComponent
    }

    /// Loads the Whisper model in the background.
    func prepare() {
        guard let modelURL = ModelStore.activeModelURL() else {
            state = .noModel
            return
        }
        state = .loadingModel
        let language = Settings.language
        transcribeQueue.async { [weak self] in
            let loaded = try? WhisperTranscriber(modelPath: modelURL.path, language: language)
            DispatchQueue.main.async {
                guard let self else { return }
                self.transcriber = loaded
                self.state = loaded == nil ? .noModel : .idle
            }
        }
    }

    func toggleRecording() {
        switch state {
        case .recording:
            finishRecording()
        default:
            startRecording()
        }
    }

    func startRecording() {
        switch state {
        case .noModel:
            hud.show("No model installed — see menu")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                if self?.state != .recording { self?.hud.hide() }
            }
            return
        case .loadingModel:
            hud.show("Loading model…")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                if self?.state != .recording { self?.hud.hide() }
            }
            return
        case .recording, .transcribing:
            return
        case .idle:
            break
        }

        do {
            try recorder.start()
            recordingStartedAt = Date()
            state = .recording
            hud.show("● Listening…")
        } catch {
            hud.show("Mic error: \(error.localizedDescription)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                self?.hud.hide()
            }
        }
    }

    func finishRecording() {
        guard state == .recording else { return }
        let samples = recorder.stop()
        let duration = Double(samples.count) / AudioRecorder.sampleRate
        recordingStartedAt = nil

        // A sub-0.3s press is almost certainly accidental.
        guard duration >= 0.3 else {
            hud.hide()
            state = .idle
            return
        }

        state = .transcribing
        hud.show("Transcribing…")
        let transcriber = transcriber
        transcribeQueue.async { [weak self] in
            let text = transcriber?.transcribe(samples) ?? ""
            DispatchQueue.main.async {
                guard let self else { return }
                self.hud.hide()
                if !text.isEmpty {
                    TextInserter.insert(text)
                }
                self.state = .idle
            }
        }
    }
}
