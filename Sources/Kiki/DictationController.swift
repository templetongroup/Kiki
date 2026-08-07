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
    private let soundPlayer = DictationSoundPlayer()
    private var whisperTranscriber: WhisperTranscriber?
    private var parakeetTranscriber: ParakeetTranscriber?
    private let transcribeQueue = DispatchQueue(label: "kiki.transcribe", qos: .userInitiated)
    private let hud = HUDPanel()
    private var recordingStartedAt: Date?
    private var preparationID = UUID()
    private var livePreviewID = UUID()
    private var liveAudioFeed: AudioSampleFeed?
    private var livePreviewSession: ParakeetLiveSession?
    private var lastLiveTranscript: String?
    private var lastRecordingDuration: TimeInterval = 0
    private var recordingContext: String?

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

    func transcribeFile(at url: URL) async throws -> String {
        guard state == .idle else { throw KikiError("Kiki is busy with another transcription.") }
        state = .transcribing
        defer { state = .idle }

        let samples = try await Task.detached(priority: .userInitiated) {
            try AudioFileLoader.load16kMono(url: url)
        }.value
        let duration = Double(samples.count) / AudioRecorder.sampleRate
        guard duration >= 0.3 else { throw KikiError("The selected file contains too little audio.") }

        let rawText: String
        if let parakeetTranscriber {
            rawText = await parakeetTranscriber.transcribe(samples)
        } else if let whisperTranscriber {
            rawText = await withCheckedContinuation { continuation in
                transcribeQueue.async {
                    continuation.resume(returning: whisperTranscriber.transcribe(samples))
                }
            }
        } else {
            throw KikiError("The selected transcription model is not ready.")
        }

        let text = CustomDictionaryStore.shared.apply(to: rawText)
        TranscriptionHistoryStore.shared.add(
            text: text,
            duration: duration,
            modelName: Settings.transcriptionModel.displayName,
            source: .file,
            context: url.lastPathComponent
        )
        return text
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

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            startAuthorizedRecording()
        case .notDetermined:
            hud.show("Allow Microphone Access…")
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.startAuthorizedRecording()
                    } else {
                        self.showTransientMessage("Microphone access is required")
                    }
                }
            }
        case .denied, .restricted:
            showTransientMessage("Enable Microphone Access in System Settings")
        @unknown default:
            showTransientMessage("Microphone access is unavailable")
        }
    }

    private func startAuthorizedRecording() {
        guard state == .idle else { return }
        soundPlayer.playRecordingStarted()
        if Settings.silenceSystemAudioWhileRecording {
            systemAudioSilencer.silence()
        }
        do {
            beginLivePreviewIfAvailable()
            try recorder.start()
            recordingStartedAt = Date()
            recordingContext = NSWorkspace.shared.frontmostApplication?.localizedName
            state = .recording
            hud.showListening()
        } catch {
            stopLivePreview()
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
        recorder.setSamplesHandler(nil)
        let livePreviewCleanup = stopLivePreview()
        systemAudioSilencer.restore()
        let duration = Double(samples.count) / AudioRecorder.sampleRate
        lastRecordingDuration = duration
        recordingStartedAt = nil

        // A sub-0.3s press is almost certainly accidental.
        guard duration >= 0.3 else {
            hud.hide()
            state = .idle
            return
        }

        state = .transcribing
        hud.showTranscribing(transcript: lastLiveTranscript)
        if let parakeetTranscriber {
            Task { [weak self] in
                await livePreviewCleanup.value
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

    private func beginLivePreviewIfAvailable() {
        lastLiveTranscript = nil
        guard Settings.showLiveTranscription, let parakeetTranscriber else {
            recorder.setSamplesHandler(nil)
            return
        }

        livePreviewID = UUID()
        let currentID = livePreviewID
        let feed = AudioSampleFeed()
        liveAudioFeed = feed
        recorder.setSamplesHandler { samples in feed.yield(samples) }
        livePreviewSession = parakeetTranscriber.makeLiveSession(audio: feed.stream) { [weak self] text in
            guard let self,
                  self.state == .recording,
                  self.livePreviewID == currentID
            else { return }
            self.lastLiveTranscript = text
            self.hud.showListening(transcript: text)
        }
    }

    @discardableResult
    private func stopLivePreview() -> Task<Void, Never> {
        livePreviewID = UUID()
        liveAudioFeed?.finish()
        liveAudioFeed = nil
        let session = livePreviewSession
        livePreviewSession = nil
        return Task {
            await session?.stop()
        }
    }

    private func completeTranscription(_ text: String) {
        if text.isEmpty {
            showTransientMessage("No speech detected")
        } else {
            let finalText = CustomDictionaryStore.shared.apply(to: text)
            TranscriptionHistoryStore.shared.add(
                text: finalText,
                duration: lastRecordingDuration,
                modelName: Settings.transcriptionModel.displayName,
                source: .dictation,
                context: recordingContext
            )
            soundPlayer.playTranscriptionCompleted()
            switch TextInserter.insert(finalText) {
            case .inserted:
                hud.hide()
            case .copiedNeedsAccessibility:
                showTransientMessage("Copied — enable Accessibility to paste")
            case .failed:
                showTransientMessage("Paste failed — text left on clipboard")
            }
        }
        lastRecordingDuration = 0
        recordingContext = nil
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
        recorder.setSamplesHandler(nil)
        stopLivePreview()
        systemAudioSilencer.restore()
    }
}
