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
@MainActor
final class DictationController {
    var onStateChange: ((DictationState) -> Void)?

    private(set) var state: DictationState = .loadingModel {
        didSet { onStateChange?(state) }
    }

    private let recorder = AudioRecorder()
    private let systemAudioSilencer = SystemAudioSilencer()
    private var whisperTranscriber: WhisperTranscriber?
    private var parakeetTranscriber: ParakeetTranscriber?
    private let transcribeQueue = DispatchQueue(label: "kiki.transcribe", qos: .userInitiated)
    private let hud = HUDPanel()
    private var recordingStartedAt: Date?
    private var preparationID = UUID()

    var activeModelName: String? {
        Settings.transcriptionModel.displayName
    }

    /// Loads the selected local model in the background. Parakeet downloads its
    /// Core ML bundle on first use; Whisper files are managed in Kiki's models folder.
    func prepare() {
        let selectedModel = Settings.transcriptionModel
        guard selectedModel.isCompatible else {
            state = .noModel
            return
        }
        preparationID = UUID()
        let currentPreparationID = preparationID
        whisperTranscriber = nil
        parakeetTranscriber = nil
        state = .loadingModel

        if selectedModel.isParakeet {
            hud.show("Downloading or loading \(selectedModel.displayName)…")
            Task { [weak self] in
                let loaded = try? await ParakeetTranscriber.load(model: selectedModel)
                guard let self, self.preparationID == currentPreparationID else { return }
                self.hud.hide()
                self.parakeetTranscriber = loaded
                self.state = loaded == nil ? .noModel : .idle
            }
            return
        }

        guard let modelURL = ModelStore.modelURL(for: selectedModel) else {
            state = .noModel
            return
        }
        let language = Settings.language
        transcribeQueue.async { [weak self] in
            let loaded = try? WhisperTranscriber(modelPath: modelURL.path, language: language)
            DispatchQueue.main.async {
                guard let self, self.preparationID == currentPreparationID else { return }
                self.whisperTranscriber = loaded
                self.state = loaded == nil ? .noModel : .idle
            }
        }
    }

    func selectModel(_ model: TranscriptionModelID) {
        guard model.isCompatible else { return }
        Settings.transcriptionModel = model
        prepare()
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

        if Settings.silenceSystemAudioWhileRecording {
            systemAudioSilencer.silence()
        }
        do {
            try recorder.start()
            recordingStartedAt = Date()
            state = .recording
            hud.show("● Listening…")
        } catch {
            systemAudioSilencer.restore()
            hud.show("Mic error: \(error.localizedDescription)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                self?.hud.hide()
            }
        }
    }

    func finishRecording() {
        guard state == .recording else { return }
        let samples = recorder.stop()
        systemAudioSilencer.restore()
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
        if let parakeetTranscriber {
            Task { [weak self] in
                let text = await parakeetTranscriber.transcribe(samples)
                self?.completeTranscription(text)
            }
        } else {
            let transcriber = whisperTranscriber
            transcribeQueue.async { [weak self] in
                let text = transcriber?.transcribe(samples) ?? ""
                DispatchQueue.main.async { self?.completeTranscription(text) }
            }
        }
    }

    private func completeTranscription(_ text: String) {
        if text.isEmpty {
            showTransientMessage("No speech detected")
        } else {
            switch TextInserter.insert(text) {
            case .inserted:
                hud.hide()
            case .copiedNeedsAccessibility:
                showTransientMessage("Copied — enable Accessibility to paste")
            case .failed:
                showTransientMessage("Paste failed — text left on clipboard")
            }
        }
        state = .idle
    }

    private func showTransientMessage(_ message: String) {
        hud.show(message)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard self?.state != .recording else { return }
            self?.hud.hide()
        }
    }

    func prepareForTermination() {
        if state == .recording {
            _ = recorder.stop()
        }
        systemAudioSilencer.restore()
    }
}
