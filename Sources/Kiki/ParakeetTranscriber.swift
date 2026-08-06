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
        let version: AsrModelVersion = model == .parakeetMultilingual ? .v3 : .v2
        let models = try await AsrModels.downloadAndLoad(version: version)
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
            var nextPreviewAt = Int(AudioRecorder.sampleRate * 1.2)

            for await chunk in audio {
                guard !Task.isCancelled else { return }
                accumulated.append(contentsOf: chunk)
                guard accumulated.count >= nextPreviewAt else { continue }

                // Update about once a second for short dictations. Back off for
                // longer passages so the preview never competes heavily with capture.
                let duration = Double(accumulated.count) / AudioRecorder.sampleRate
                let interval = duration < 15 ? 1.0 : (duration < 30 ? 2.0 : 3.0)
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
