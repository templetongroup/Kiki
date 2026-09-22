import Foundation

enum MeetingAudioChunks {
    /// Prefer the end of a quiet run in the last six seconds of each window.
    /// Ranges partition the recording: no audio is dropped or duplicated.
    /// Continuous speech still requires a hard boundary at the maximum length.
    static func ranges(_ samples: [Float], sampleRate: Int = 16_000) -> [Range<Int>] {
        precondition(sampleRate > 0)
        let maximum = sampleRate * 30
        let searchLength = sampleRate * 6
        let pauseLength = max(1, sampleRate / 5)
        var result: [Range<Int>] = []
        var start = 0
        while start < samples.count {
            let limit = min(start + maximum, samples.count)
            var end = limit
            if limit < samples.count {
                var quietCount = 0
                var pauseEnd: Int?
                for i in max(start, limit - searchLength)..<limit {
                    if abs(samples[i]) <= 0.002 {
                        quietCount += 1
                        if quietCount >= pauseLength { pauseEnd = i + 1 }
                    } else {
                        quietCount = 0
                    }
                }
                if let pauseEnd { end = pauseEnd }
            }
            result.append(start..<end)
            start = end
        }
        return result
    }
}

/// Preview-only rolling audio. The recorder independently retains the complete
/// recording for final transcription. Slow inference replaces queued previews,
/// never chunks of the authoritative recording.
final class MeetingPreviewFeed: @unchecked Sendable {
    let stream: AsyncStream<[Float]>
    private let continuation: AsyncStream<[Float]>.Continuation
    private let lock = NSLock()
    private let capacity: Int
    private let cadence: Int
    private var ring: [Float]
    private var cursor = 0
    private var count = 0
    private var sinceEmission = 0
    private var finished = false

    init(sampleRate: Int = 16_000) {
        precondition(sampleRate > 0)
        capacity = sampleRate * 12
        cadence = sampleRate * 3
        ring = Array(repeating: 0, count: capacity)
        (stream, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
    }

    func yield(_ samples: [Float]) {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return }
        for sample in samples {
            ring[cursor] = sample
            cursor = (cursor + 1) % capacity
            count = min(count + 1, capacity)
            sinceEmission += 1
            if sinceEmission >= cadence {
                continuation.yield(snapshot())
                sinceEmission = 0
            }
        }
    }

    func finish() {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return }
        finished = true
        if sinceEmission > 0 { continuation.yield(snapshot()) }
        continuation.finish()
    }

    private func snapshot() -> [Float] {
        if count < capacity { return Array(ring.prefix(count)) }
        return Array(ring[cursor...]) + Array(ring[..<cursor])
    }
}
