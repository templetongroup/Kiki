import FluidAudio
import Foundation
import OSLog

final class ParakeetTranscriber {
    private let manager: AsrManager
    private let models: AsrModels

    private init(models: AsrModels) {
        self.models = models
        self.manager = AsrManager(models: models)
    }

    static func load(model: TranscriptionModelID) async throws -> ParakeetTranscriber {
        try await load(model: model) { _ in }
    }

    static func isInstalled(model: TranscriptionModelID) -> Bool {
        let version: AsrModelVersion = model == .parakeetMultilingual ? .v3 : .v2
        let directory = AsrModels.defaultCacheDirectory(for: version)
        return AsrModels.modelsExist(at: directory, version: version)
    }

    static func load(
        model: TranscriptionModelID,
        onPreparationChange: @MainActor @escaping (ModelPreparationStatus) -> Void
    ) async throws -> ParakeetTranscriber {
        let version: AsrModelVersion = model == .parakeetMultilingual ? .v3 : .v2
        let progressMapper = ParakeetDownloadProgressMapper(
            model: model,
            operationCount: version == .v3 ? 3 : 4
        )
        let directory = try await AsrModels.download(version: version) { progress in
            guard let status = progressMapper.status(for: progress) else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    onPreparationChange(status)
                }
            }
        }
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    onPreparationChange(.loading(model: model))
                }
                continuation.resume()
            }
        }
        let models = try await AsrModels.load(from: directory, version: version)
        return ParakeetTranscriber(models: models)
    }

    func transcribe(_ samples: [Float]) async -> String {
        do {
            var decoderState = TdtDecoderState.make()
            let result = try await manager.transcribe(samples, decoderState: &decoderState)
            return WhisperTranscriber.cleaned(result.text)
        } catch {
            return ""
        }
    }

    /// Creates a low-latency preview session. The preview uses short windows;
    /// Kiki still runs the normal batch pass afterward for final accuracy.
    func makeLiveSession(
        audio: AsyncStream<[Float]>,
        onUpdate: @escaping @MainActor (String) -> Void
    ) -> ParakeetLiveSession {
        let session = ParakeetLiveSession(manager: AsrManager(models: models))
        session.start(audio: audio, onUpdate: onUpdate)
        return session
    }
}

private final class ParakeetDownloadProgressMapper: @unchecked Sendable {
    private let lock = NSLock()
    private let model: TranscriptionModelID
    private let operationCount: Int
    private var operationIndex = -1

    init(model: TranscriptionModelID, operationCount: Int) {
        self.model = model
        self.operationCount = max(1, operationCount)
    }

    func status(for progress: DownloadProgress) -> ModelPreparationStatus? {
        lock.lock()
        defer { lock.unlock() }
        switch progress.phase {
        case .listing:
            operationIndex = min(operationIndex + 1, operationCount - 1)
            return nil
        case let .downloading(_, totalFiles):
            guard totalFiles > 0 else { return nil }
            let downloadFraction = min(1, max(0, progress.fractionCompleted * 2))
            let completedOperations = max(0, operationIndex)
            let overallFraction = (Double(completedOperations) + downloadFraction)
                / Double(operationCount)
            return .downloading(model: model, fraction: overallFraction)
        case .compiling:
            return .loading(model: model)
        }
    }
}

/// Thread-safe bridge between AVAudioEngine's callback and the async preview.
final class AudioSampleFeed: @unchecked Sendable {
    let stream: AsyncStream<[Float]>
    private let continuation: AsyncStream<[Float]>.Continuation

    init() {
        (stream, continuation) = AsyncStream<[Float]>.makeStream(bufferingPolicy: .unbounded)
    }

    func yield(_ samples: [Float]) { continuation.yield(samples) }
    func finish() { continuation.finish() }
}

/// Owns the streaming bridge used by long-running surfaces such as Meeting Mode.
/// Final transcription still uses the complete recording for maximum accuracy.
final class MeetingLiveTranscription: @unchecked Sendable {
    private let feed: AudioSampleFeed
    private let session: ParakeetLiveSession

    init(feed: AudioSampleFeed, session: ParakeetLiveSession) {
        self.feed = feed
        self.session = session
    }

    func yield(_ samples: [Float]) { feed.yield(samples) }

    func stop() async {
        feed.finish()
        await session.stop()
    }
}

final class ParakeetLiveSession: @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.tonyricciardi.kiki", category: "LiveTranscription")
    private let manager: AsrManager
    private var previewTask: Task<Void, Never>?

    init(manager: AsrManager) {
        self.manager = manager
    }

    func start(
        audio: AsyncStream<[Float]>,
        onUpdate: @escaping @MainActor (String) -> Void
    ) {
        previewTask = Task { [manager] in
            var accumulated: [Float] = []
            // A normal dictation is often only one or two seconds long. Waiting
            // more than a second before starting inference means the user can
            // release the shortcut before the first preview is ready.
            var nextPreviewAt = Int(AudioRecorder.sampleRate * 0.5)

            for await chunk in audio {
                guard !Task.isCancelled else { return }
                accumulated.append(contentsOf: chunk)
                guard accumulated.count >= nextPreviewAt else { continue }

                // Refresh quickly at the start so short dictations get visible
                // text, then back off for longer passages to limit inference work.
                let duration = Double(accumulated.count) / AudioRecorder.sampleRate
                let interval = duration < 8 ? 0.65 : (duration < 20 ? 1.0 : (duration < 40 ? 2.0 : 3.0))
                nextPreviewAt = accumulated.count + Int(AudioRecorder.sampleRate * interval)

                do {
                    var decoderState = TdtDecoderState.make(
                        decoderLayers: await manager.decoderLayerCount
                    )
                    let result = try await manager.transcribe(
                        accumulated,
                        decoderState: &decoderState
                    )
                    guard !Task.isCancelled else { return }
                    let text = WhisperTranscriber.cleaned(result.text)
                    if !text.isEmpty { await onUpdate(text) }
                } catch is CancellationError {
                    return
                } catch {
                    Self.logger.error("Live preview failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    func stop() async {
        previewTask?.cancel()
        _ = await previewTask?.result
        await manager.cleanup()
    }

    /// Waits for a finite audio stream to drain. Used by Kiki's CLI diagnostic.
    func finish() async {
        _ = await previewTask?.result
        await manager.cleanup()
    }
}
