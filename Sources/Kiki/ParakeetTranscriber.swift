import FluidAudio
import AVFoundation
import Foundation

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
    ) async throws -> ParakeetLiveSession {
        let config = SlidingWindowAsrConfig(
            chunkSeconds: 1.8,
            hypothesisChunkSeconds: 0.9,
            leftContextSeconds: 1.5,
            rightContextSeconds: 0.25,
            minContextForConfirmation: 4.0,
            confirmationThreshold: 0.80,
            tdtConfig: TdtConfig(blankId: models.version.blankId)
        )
        let streamingManager = SlidingWindowAsrManager(config: config)
        try await streamingManager.loadModels(models)
        let updates = await streamingManager.transcriptionUpdates
        try await streamingManager.startStreaming(source: .microphone)

        let session = ParakeetLiveSession(manager: streamingManager)
        session.start(audio: audio, updates: updates, onUpdate: onUpdate)
        return session
    }
}

/// Thread-safe bridge between AVAudioEngine's callback and the async preview.
final class AudioSampleFeed: @unchecked Sendable {
    let stream: AsyncStream<[Float]>
    private let continuation: AsyncStream<[Float]>.Continuation

    init() {
        (stream, continuation) = AsyncStream<[Float]>.makeStream(
            bufferingPolicy: .bufferingNewest(160)
        )
    }

    func yield(_ samples: [Float]) { continuation.yield(samples) }
    func finish() { continuation.finish() }
}

final class ParakeetLiveSession: @unchecked Sendable {
    private let manager: SlidingWindowAsrManager
    private var feederTask: Task<Void, Never>?
    private var updateTask: Task<Void, Never>?

    init(manager: SlidingWindowAsrManager) {
        self.manager = manager
    }

    func start(
        audio: AsyncStream<[Float]>,
        updates: AsyncStream<SlidingWindowTranscriptionUpdate>,
        onUpdate: @escaping @MainActor (String) -> Void
    ) {
        feederTask = Task { [manager] in
            for await samples in audio {
                guard !Task.isCancelled, let buffer = Self.makeBuffer(samples) else { break }
                await manager.streamAudio(buffer)
            }
        }
        updateTask = Task { [manager] in
            for await _ in updates {
                guard !Task.isCancelled else { break }
                let confirmed = await manager.confirmedTranscript
                let volatile = await manager.volatileTranscript
                let text = WhisperTranscriber.cleaned(
                    [confirmed, volatile].filter { !$0.isEmpty }.joined(separator: " ")
                )
                guard !text.isEmpty else { continue }
                await onUpdate(text)
            }
        }
    }

    func stop() async {
        feederTask?.cancel()
        updateTask?.cancel()
        await manager.cancel()
        _ = await feederTask?.result
        _ = await updateTask?.result
    }

    private static func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty,
              let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: AudioRecorder.sampleRate,
                channels: 1,
                interleaved: false
              ),
              let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(samples.count)
              ),
              let channel = buffer.floatChannelData
        else { return nil }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            channel[0].update(from: source.baseAddress!, count: samples.count)
        }
        return buffer
    }
}
