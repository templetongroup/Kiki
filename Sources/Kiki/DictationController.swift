import AppKit
import AVFoundation

enum DictationState: Equatable {
    case noModel
    case loadingModel
    case idle
    case recording
    case transcribing
}

struct MeetingCapturePrivacy {
    private(set) var isActive = false
    private(set) var wasPrivate = false

    mutating func begin(privateSessionActive: Bool) {
        if !isActive {
            wasPrivate = privateSessionActive
        } else if privateSessionActive {
            wasPrivate = true
        }
        isActive = true
    }

    mutating func privateSessionDidChange(isActive: Bool) {
        guard self.isActive, isActive else { return }
        wasPrivate = true
    }

    mutating func end() {
        isActive = false
        wasPrivate = false
    }

    func persistHistoryIfAllowed(_ persist: () -> Void) {
        guard PrivateSessionPolicy.resolved(
            privateSessionActive: wasPrivate,
            privateContext: false
        ).historyEnabled else { return }
        persist()
    }
}

/// Owns the record → transcribe → insert pipeline. Recording remains a tiny,
/// latency-sensitive path. Finished recordings become ordered jobs so another
/// recording can begin while the previous job is transcribing.
@MainActor
final class DictationController {
    var onStateChange: ((DictationState) -> Void)?
    var onModelPreparationChange: ((ModelPreparationStatus) -> Void)?
    var onSuccessfulInsertion: ((String, AppContextSnapshot) -> Void)?
    var onLastDictationActionsChange: ((Bool, Bool) -> Void)?

    private var transientMessageID = UUID()
    private(set) var state: DictationState = .loadingModel {
        didSet {
            // Returning to idle is the normal final step after a paste fallback.
            // Keep that message's dismissal token alive so its HUD cannot stick.
            if state != .idle {
                transientMessageID = UUID()
            }
            onStateChange?(state)
        }
    }
    private(set) var modelPreparationStatus = ModelPreparationStatus.loading(
        model: Settings.transcriptionModel
    ) {
        didSet { onModelPreparationChange?(modelPreparationStatus) }
    }

    private struct DictationJob {
        let sequence: Int
        let samples: [Float]
        let duration: TimeInterval
        let context: AppContextSnapshot
        let liveTranscript: String?
        let finishedAt: Date
        let livePreviewCleanup: Task<Void, Never>
    }

    private struct LastInsertion {
        let processIdentifier: pid_t
        let text: String
        let jobFinishedAt: Date
        let samples: [Float]
        let duration: TimeInterval
        let context: AppContextSnapshot
    }

    private let recorder = AudioRecorder()
    private let systemAudioSilencer = SystemAudioSilencer()
    private let soundPlayer = DictationSoundPlayer()
    private let confidenceVerifier = BackgroundConfidenceVerifier()
    private var whisperTranscriber: WhisperTranscriber?
    private var parakeetTranscriber: ParakeetTranscriber?
    private let transcribeQueue = DispatchQueue(label: "kiki.transcribe", qos: .userInitiated)
    private let hud = HUDPanel()
    private var preparationID = UUID()
    private var preparationTask: Task<Void, Never>?
    private var livePreviewID = UUID()
    private var liveAudioFeed: AudioSampleFeed?
    private var livePreviewSession: ParakeetLiveSession?
    private var lastLiveTranscript: String?
    private var recordingContext: AppContextSnapshot?
    private var pendingJobs: [DictationJob] = []
    private var processingJob = false
    private var nextSequence = 0
    private var lastInsertion: LastInsertion?
    private var lastInsertionIsPresent = false
    private var meetingCapturePrivacy = MeetingCapturePrivacy()

    var activeModelName: String? {
        Settings.transcriptionModel.displayName
    }

    var isModelReady: Bool {
        modelPreparationStatus.isReady
    }

    var canUndoLastDictation: Bool { lastInsertion != nil && lastInsertionIsPresent }
    var canRetryLastDictation: Bool { lastInsertion != nil }

    func prepare() {
        let selectedModel = Settings.transcriptionModel
        preparationTask?.cancel()
        guard selectedModel.isCompatible else {
            publishModelPreparation(.unavailable(model: selectedModel))
            state = .noModel
            return
        }
        preparationID = UUID()
        let currentPreparationID = preparationID
        whisperTranscriber = nil
        parakeetTranscriber = nil
        state = .loadingModel
        let modelIsLocal = selectedModel.isParakeet
            ? ParakeetTranscriber.isInstalled(model: selectedModel)
            : ModelStore.isWhisperModelInstalled(selectedModel)
        publishModelPreparation(modelIsLocal
            ? .loading(model: selectedModel)
            : .downloading(model: selectedModel, fraction: 0))

        preparationTask = Task { [weak self] in
            guard let self else { return }
            do {
                if selectedModel.isParakeet {
                    let loaded = try await ParakeetTranscriber.load(
                        model: selectedModel
                    ) { [weak self] status in
                        guard let self,
                              self.preparationID == currentPreparationID else { return }
                        self.publishModelPreparation(status)
                    }
                    try Task.checkCancellation()
                    guard self.preparationID == currentPreparationID else { return }
                    self.parakeetTranscriber = loaded
                } else {
                    try await ModelDownloadService.downloadWhisperModel(
                        selectedModel
                    ) { [weak self] progress in
                        guard let self,
                              self.preparationID == currentPreparationID else { return }
                        self.publishModelPreparation(.downloading(
                            model: selectedModel,
                            fraction: progress.fraction
                        ))
                    }
                    try Task.checkCancellation()
                    guard self.preparationID == currentPreparationID,
                          let modelURL = ModelStore.modelURL(for: selectedModel) else {
                        throw KikiError("The downloaded model could not be found.")
                    }
                    self.publishModelPreparation(.loading(model: selectedModel))
                    let language = Settings.language
                    let loaded: WhisperTranscriber? = await withCheckedContinuation { continuation in
                        self.transcribeQueue.async {
                            continuation.resume(returning: try? WhisperTranscriber(
                                modelPath: modelURL.path,
                                language: language
                            ))
                        }
                    }
                    try Task.checkCancellation()
                    guard self.preparationID == currentPreparationID, let loaded else {
                        throw KikiError("Kiki could not load the selected model into memory.")
                    }
                    self.whisperTranscriber = loaded
                }

                self.publishModelPreparation(.ready(model: selectedModel))
                self.state = .idle
            } catch is CancellationError {
                return
            } catch {
                guard self.preparationID == currentPreparationID else { return }
                self.publishModelPreparation(.failed(
                    model: selectedModel,
                    message: error.localizedDescription
                ))
                self.state = .noModel
            }
        }
    }

    private func publishModelPreparation(_ status: ModelPreparationStatus) {
        modelPreparationStatus = status
        switch status {
        case .downloading, .loading:
            hud.showModelPreparation(status)
        case .unavailable, .failed:
            hud.show(status.compactTitle)
        case .ready:
            hud.hide()
        }
    }

    func selectModel(_ model: TranscriptionModelID) {
        guard model.isCompatible,
              state != .recording,
              state != .transcribing,
              !processingJob,
              pendingJobs.isEmpty
        else {
            showTransientMessage("Finish current dictations before changing models")
            return
        }
        Settings.transcriptionModel = model
        prepare()
    }

    func undoLastDictation() {
        guard state == .idle,
              lastInsertionIsPresent,
              let insertion = lastInsertion else {
            showTransientMessage("The last Kiki insertion is no longer available")
            return
        }
        guard TextInserter.undoExact(insertion.text, processIdentifier: insertion.processIdentifier) else {
            showTransientMessage("Kiki left the text unchanged because it could not verify the exact insertion")
            return
        }
        lastInsertionIsPresent = false
        onLastDictationActionsChange?(false, true)
        showTransientMessage("Last Kiki dictation removed")
    }

    func markCurrentRecordingPrivate() {
        meetingCapturePrivacy.privateSessionDidChange(isActive: true)
        if state == .recording, let recordingContext {
            self.recordingContext = recordingContext.markingPrivateSessionActive()
        }
    }

    func retryLastDictation() {
        guard state == .idle,
              !processingJob,
              pendingJobs.isEmpty,
              let insertion = lastInsertion else {
            showTransientMessage("No recent dictation is available to retry")
            return
        }
        if lastInsertionIsPresent {
            guard TextInserter.undoExact(insertion.text, processIdentifier: insertion.processIdentifier) else {
                showTransientMessage("Kiki left the text unchanged because it could not verify the exact insertion")
                return
            }
            lastInsertionIsPresent = false
        }
        lastInsertion = nil
        nextSequence += 1
        pendingJobs.append(
            DictationJob(
                sequence: nextSequence,
                samples: insertion.samples,
                duration: insertion.duration,
                context: insertion.context,
                liveTranscript: nil,
                finishedAt: Date(),
                livePreviewCleanup: Task { }
            )
        )
        onLastDictationActionsChange?(false, false)
        state = .transcribing
        showTranscribingPresentation()
        processNextJobIfNeeded()
    }

    func transcribeFile(at url: URL) async throws -> String {
        guard state == .idle, !processingJob, pendingJobs.isEmpty else {
            throw KikiError("Kiki is busy with another transcription.")
        }
        state = .transcribing
        defer { state = .idle }
        let privateSessionActive = PrivateSessionController.shared.isActive

        let loadedSamples = try await Task.detached(priority: .userInitiated) {
            try AudioFileLoader.load16kMono(url: url)
        }.value
        let duration = Double(loadedSamples.count) / AudioRecorder.sampleRate
        guard duration >= 0.3 else { throw KikiError("The selected file contains too little audio.") }
        let samples = AudioSignalProcessor.prepareForFinalTranscription(loadedSamples)

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

        let text = TranscriptPostProcessor.process(rawText, context: nil)
        if PrivateSessionPolicy.resolved(
            privateSessionActive: privateSessionActive,
            privateContext: false
        ).historyEnabled {
            TranscriptionHistoryStore.shared.add(
                text: text,
                duration: duration,
                modelName: Settings.transcriptionModel.displayName,
                source: .file,
                context: url.lastPathComponent
            )
        }
        return text
    }

    func setMeetingCaptureActive(_ active: Bool) {
        if active {
            meetingCapturePrivacy.begin(
                privateSessionActive: PrivateSessionController.shared.isActive
            )
        } else {
            meetingCapturePrivacy.end()
        }
    }

    func makeMeetingLiveTranscription(
        onUpdate: @escaping @MainActor (String) -> Void
    ) -> MeetingLiveTranscription? {
        guard let parakeetTranscriber else { return nil }
        let feed = AudioSampleFeed()
        let session = parakeetTranscriber.makeLiveSession(audio: feed.stream, onUpdate: onUpdate)
        return MeetingLiveTranscription(feed: feed, session: session)
    }

    func transcribeMeeting(
        microphoneSamples: [Float],
        systemSamples: [Float],
        duration: TimeInterval,
        title: String
    ) async throws -> MeetingTranscript {
        guard state == .idle, !processingJob, pendingJobs.isEmpty else {
            throw KikiError("Finish current dictations before processing the meeting.")
        }
        state = .transcribing
        meetingCapturePrivacy.privateSessionDidChange(
            isActive: PrivateSessionController.shared.isActive
        )
        let capturePrivacy = meetingCapturePrivacy
        defer {
            meetingCapturePrivacy.end()
            state = .idle
            hud.hide()
        }

        let microphoneSegments = try await transcribeMeetingTrack(
            AudioSignalProcessor.prepareForFinalTranscription(microphoneSamples),
            speaker: "You"
        )
        let systemSegments = try await transcribeMeetingTrack(
            systemSamples,
            speaker: "Speaker 1"
        )
        let segments = MeetingTranscript.deduplicatingSourceOverlap(
            microphoneSegments + systemSegments
        )
        let transcript = MeetingTranscript(
            title: title,
            createdAt: Date(),
            duration: duration,
            segments: segments,
            actionItems: MeetingTranscript.actionItems(from: segments)
        )
        capturePrivacy.persistHistoryIfAllowed {
            TranscriptionHistoryStore.shared.add(
                text: transcript.plainText,
                duration: duration,
                modelName: Settings.transcriptionModel.displayName,
                source: .meeting,
                context: title
            )
        }
        return transcript
    }

    private func transcribeMeetingTrack(
        _ samples: [Float],
        speaker: String
    ) async throws -> [MeetingTranscriptSegment] {
        guard !samples.isEmpty else { return [] }
        let chunkSize = Int(30 * AudioRecorder.sampleRate)
        var segments: [MeetingTranscriptSegment] = []
        var offset = 0
        let total = Int(ceil(Double(samples.count) / Double(chunkSize)))
        var index = 0
        while offset < samples.count {
            let end = min(samples.count, offset + chunkSize)
            let chunk = Array(samples[offset..<end])
            offset = end
            index += 1
            if state != .recording {
                hud.show("Transcribing meeting · \(speaker) · \(index)/\(total)")
            }
            let energy = chunk.reduce(0.0) { $0 + Double($1 * $1) } / Double(max(1, chunk.count))
            guard energy.squareRoot() > 0.002 else { continue }

            let raw: String
            if let parakeetTranscriber {
                raw = await parakeetTranscriber.transcribe(chunk)
            } else if let whisperTranscriber {
                raw = await withCheckedContinuation { continuation in
                    transcribeQueue.async {
                        continuation.resume(returning: whisperTranscriber.transcribe(chunk))
                    }
                }
            } else {
                throw KikiError("The selected transcription model is not ready.")
            }
            let text = TranscriptPostProcessor.process(raw, context: nil)
            guard !text.isEmpty else { continue }
            segments.append(contentsOf:
                MeetingTranscriptSegment.sentenceSegments(
                    startTime: Double(end - chunk.count) / AudioRecorder.sampleRate,
                    endTime: Double(end) / AudioRecorder.sampleRate,
                    speaker: speaker,
                    text: text
                )
            )
        }
        return segments
    }

    func toggleRecording() {
        if state == .recording {
            finishRecording()
        } else {
            startRecording()
        }
    }

    func startRecording(context preferredContext: AppContextSnapshot? = nil) {
        guard !meetingCapturePrivacy.isActive else {
            showTransientMessage("Meeting Mode is recording")
            return
        }
        switch state {
        case .noModel:
            hud.show(modelPreparationStatus.compactTitle)
            return
        case .loadingModel:
            hud.showModelPreparation(modelPreparationStatus)
            return
        case .recording:
            return
        case .transcribing where !Settings.enableZeroWaitChaining:
            return
        case .idle, .transcribing:
            break
        }

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            startAuthorizedRecording(context: preferredContext)
        case .notDetermined:
            hud.show("Allow Microphone Access…")
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.startAuthorizedRecording(context: preferredContext)
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

    private func startAuthorizedRecording(context preferredContext: AppContextSnapshot? = nil) {
        guard state == .idle || (state == .transcribing && Settings.enableZeroWaitChaining) else {
            return
        }
        recordingContext = preferredContext ?? AppContextSnapshot.capture()
        soundPlayer.playRecordingStarted()
        if Settings.silenceSystemAudioWhileRecording {
            systemAudioSilencer.silence()
        }
        do {
            beginLivePreviewIfAvailable()
            try recorder.start()
            state = .recording
            showListeningPresentation()
        } catch {
            _ = stopLivePreview()
            systemAudioSilencer.restore()
            showTransientMessage("Mic error: \(error.localizedDescription)")
        }
    }

    func finishRecording() {
        guard state == .recording else { return }
        let recordedSamples = recorder.stop()
        recorder.setSamplesHandler(nil)
        let livePreviewCleanup = stopLivePreview()
        systemAudioSilencer.restore()
        let duration = Double(recordedSamples.count) / AudioRecorder.sampleRate
        let context = recordingContext ?? AppContextSnapshot.capture()
        recordingContext = nil

        guard duration >= 0.3 else {
            livePreviewCleanup.cancel()
            settleAfterRecordingEnds()
            return
        }

        nextSequence += 1
        pendingJobs.append(
            DictationJob(
                sequence: nextSequence,
                samples: AudioSignalProcessor.prepareForFinalTranscription(recordedSamples),
                duration: duration,
                context: context,
                liveTranscript: lastLiveTranscript,
                finishedAt: Date(),
                livePreviewCleanup: livePreviewCleanup
            )
        )
        pendingJobs.sort { $0.sequence < $1.sequence }
        state = .transcribing
        showTranscribingPresentation(transcript: lastLiveTranscript)
        processNextJobIfNeeded()
    }

    func cancelRecording() {
        guard state == .recording else { return }
        _ = recorder.stop()
        recorder.setSamplesHandler(nil)
        _ = stopLivePreview()
        systemAudioSilencer.restore()
        recordingContext = nil
        lastLiveTranscript = nil
        settleAfterRecordingEnds()
    }

    static func stateAfterRecordingEnds(
        processingJob: Bool,
        pendingJobCount: Int
    ) -> DictationState {
        processingJob || pendingJobCount > 0 ? .transcribing : .idle
    }

    private func settleAfterRecordingEnds() {
        switch Self.stateAfterRecordingEnds(
            processingJob: processingJob,
            pendingJobCount: pendingJobs.count
        ) {
        case .transcribing:
            state = .transcribing
            showTranscribingPresentation()
        case .idle:
            state = .idle
            hud.hide()
        case .noModel, .loadingModel, .recording:
            assertionFailure("Post-recording state must be idle or transcribing")
        }
    }

    private func processNextJobIfNeeded() {
        guard !processingJob, !pendingJobs.isEmpty else {
            updateStateAfterProcessing()
            return
        }
        processingJob = true
        let job = pendingJobs.removeFirst()
        if state != .recording {
            state = .transcribing
            showTranscribingPresentation(transcript: job.liveTranscript)
        }

        if let parakeetTranscriber {
            Task { [weak self] in
                await job.livePreviewCleanup.value
                let text = await parakeetTranscriber.transcribe(job.samples)
                self?.complete(job: job, rawText: text)
            }
        } else {
            let transcriber = whisperTranscriber
            transcribeQueue.async { [weak self] in
                let text = transcriber?.transcribe(job.samples) ?? ""
                DispatchQueue.main.async { self?.complete(job: job, rawText: text) }
            }
        }
    }

    private func complete(job: DictationJob, rawText: String) {
        processingJob = false
        let finalText = TranscriptPostProcessor.process(rawText, context: job.context)
        if finalText.isEmpty {
            if state != .recording, pendingJobs.isEmpty {
                state = .idle
                showTransientMessage("No speech detected")
                return
            }
            processNextJobIfNeeded()
            return
        }

        if job.context.privacyPolicy.historyEnabled {
            TranscriptionHistoryStore.shared.add(
                text: finalText,
                duration: job.duration,
                modelName: Settings.transcriptionModel.displayName,
                source: .dictation,
                context: job.context.displayName
            )
        }
        confidenceVerifier.verify(
            samples: job.samples,
            primaryText: finalText,
            context: job.context
        )

        let textToInsert = textWithContinuation(finalText, for: job)
        let currentPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let result: TextInserter.Result
        if currentPID == job.context.processIdentifier || job.context.processIdentifier == 0 {
            result = TextInserter.insert(textToInsert, context: job.context)
        } else {
            TextInserter.copyOnly(textToInsert)
            result = .failed
        }

        switch result {
        case .inserted:
            lastInsertion = LastInsertion(
                processIdentifier: job.context.processIdentifier,
                text: textToInsert,
                jobFinishedAt: job.finishedAt,
                samples: job.samples,
                duration: job.duration,
                context: job.context
            )
            lastInsertionIsPresent = true
            onLastDictationActionsChange?(true, true)
            PawprintsStore.shared.record(
                text: textToInsert,
                duration: job.duration,
                isPrivate: !job.context.privacyPolicy.pawprintsEnabled
            )
            onSuccessfulInsertion?(textToInsert, job.context)
            if state != .recording { soundPlayer.playTranscriptionCompleted() }
        case .copiedNeedsAccessibility:
            if state != .recording { showTransientMessage("Copied — enable Accessibility to paste") }
        case .failed:
            if state != .recording { showTransientMessage("Copied — return to the original app to paste") }
        }
        if result != .inserted, state != .recording, pendingJobs.isEmpty {
            state = .idle
            return
        }
        processNextJobIfNeeded()
    }

    private func textWithContinuation(_ text: String, for job: DictationJob) -> String {
        guard Settings.enableVoiceContinuations,
              let previous = lastInsertion,
              previous.processIdentifier == job.context.processIdentifier,
              job.finishedAt.timeIntervalSince(previous.jobFinishedAt) <= Settings.continuationWindow,
              previous.text.last?.isWhitespace != true
        else { return text }
        return text.first.map({ $0.isPunctuation }) == true ? text : " " + text
    }

    private func beginLivePreviewIfAvailable() {
        lastLiveTranscript = nil
        let mode = Settings.listeningDisplayMode
        guard mode != .hidden else {
            recorder.setSamplesHandler(nil)
            return
        }

        livePreviewID = UUID()
        let currentID = livePreviewID

        if mode == .waveform {
            recorder.setSamplesHandler { [weak self] samples in
                DispatchQueue.main.async {
                    guard let self,
                          self.state == .recording,
                          self.livePreviewID == currentID
                    else { return }
                    self.hud.showWaveform(samples: samples)
                }
            }
            return
        }

        guard let parakeetTranscriber else {
            recorder.setSamplesHandler(nil)
            return
        }
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

    private func showListeningPresentation() {
        switch Settings.listeningDisplayMode {
        case .fullTranscript: hud.showListening()
        case .waveform: hud.showWaveform(samples: [], reset: true)
        case .hidden: hud.hide()
        }
    }

    private func showTranscribingPresentation(transcript: String? = nil) {
        switch Settings.listeningDisplayMode {
        case .fullTranscript: hud.showTranscribing(transcript: transcript)
        case .waveform: hud.showWaveform(samples: [], reset: true)
        case .hidden: hud.hide()
        }
    }

    @discardableResult
    private func stopLivePreview() -> Task<Void, Never> {
        livePreviewID = UUID()
        liveAudioFeed?.finish()
        liveAudioFeed = nil
        let session = livePreviewSession
        livePreviewSession = nil
        return Task { await session?.stop() }
    }

    private func updateStateAfterProcessing() {
        if state == .recording { return }
        if processingJob || !pendingJobs.isEmpty {
            state = .transcribing
        } else {
            state = .idle
            hud.hide()
        }
    }

    private func showTransientMessage(_ message: String) {
        transientMessageID = UUID()
        let currentMessageID = transientMessageID
        hud.show(message)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self,
                  self.transientMessageID == currentMessageID,
                  self.state != .recording else { return }
            self.resolveTransientPresentationAfterDelay()
        }
    }

    func resolveTransientPresentationAfterDelay() {
        switch state {
        case .noModel:
            hud.show(modelPreparationStatus.compactTitle)
        case .loadingModel:
            hud.showModelPreparation(modelPreparationStatus)
        case .idle:
            hud.hide()
        case .recording:
            showListeningPresentation()
        case .transcribing:
            showTranscribingPresentation()
        }
    }

    func showPasteFallbackForDiagnostics() {
        state = .transcribing
        showTransientMessage("Copied — return to the original app to paste")
        state = .idle
    }

    var isTransientHUDVisibleForDiagnostics: Bool {
        hud.isVisibleOnScreen
    }

    func prepareForTermination() {
        preparationTask?.cancel()
        if state == .recording { _ = recorder.stop() }
        recorder.setSamplesHandler(nil)
        _ = stopLivePreview()
        systemAudioSilencer.restore()
    }
}
