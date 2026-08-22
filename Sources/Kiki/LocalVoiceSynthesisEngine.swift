import AVFoundation
import Foundation
import MLX
import MLXAudioCore
import MLXAudioTTS

struct VoiceSynthesisProgress: Sendable {
    let completedChunks: Int
    let totalChunks: Int
    let generatedTokens: Int

    var fraction: Double {
        guard totalChunks > 0 else { return 0 }
        return min(0.98, Double(completedChunks) / Double(totalChunks))
    }
}

actor LocalVoiceSynthesisEngine {
    private static let maximumCharactersPerGeneration = 1_200
    private var model: Qwen3TTSModel?
    private var conditioning: Qwen3TTSModel.Qwen3TTSReferenceConditioning?
    private var conditionedProfileDate: Date?

    func synthesize(
        text: String,
        profile: KikiVoiceProfile,
        progress: @MainActor @escaping (VoiceSynthesisProgress) -> Void
    ) async throws -> URL {
        guard profile.isGenerationCompatible else {
            throw KikiError("Record the new short voice sample before generating audio. Older recordings can repeat the enrollment script.")
        }
        guard VoiceModelStore.isInstalled else {
            throw KikiError("Download the local voice model before generating speech.")
        }
        guard FileManager.default.fileExists(atPath: VoiceProfileStore.referenceAudioURL.path) else {
            throw KikiError("Create your voice before generating speech.")
        }

        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw KikiError("Type something for Kiki to say.") }
        guard cleaned.count <= 20_000 else {
            throw KikiError("Voice Studio supports up to 20,000 characters at a time.")
        }

        let loadedModel = try await loadModelIfNeeded()
        let preparedConditioning = try prepareConditioningIfNeeded(model: loadedModel, profile: profile)
        let chunks = Self.chunk(cleaned, maximumCharacters: Self.maximumCharactersPerGeneration)
        let outputURL = try VoiceProfileStore.newGeneratedURL()
        let writer = try StreamingVoiceWAVWriter(url: outputURL, sampleRate: loadedModel.sampleRate)

        do {
            for (index, chunk) in chunks.enumerated() {
                try Task.checkCancellation()
                var parameters = loadedModel.defaultGenerationParameters
                parameters.maxTokens = max(320, min(1_600, chunk.count * 5))
                parameters.temperature = 0.75
                parameters.topP = 0.9
                parameters.repetitionPenalty = 1.12
                var sectionSamples: [Float] = []
                var tokens = 0
                let stream = loadedModel.generateStream(
                    text: chunk,
                    conditioning: preparedConditioning,
                    generationParameters: parameters,
                    streamingInterval: 0.45
                )
                for try await event in stream {
                    try Task.checkCancellation()
                    switch event {
                    case .token:
                        tokens += 1
                        if tokens.isMultiple(of: 12) {
                            await progress(.init(
                                completedChunks: index,
                                totalChunks: chunks.count,
                                generatedTokens: tokens
                            ))
                        }
                    case .audio(let audio):
                        sectionSamples.append(contentsOf: audio.asArray(Float.self))
                    case .progress:
                        break
                    case .info:
                        break
                    }
                }
                try writer.writeSection(sectionSamples)
                await progress(.init(
                    completedChunks: index + 1,
                    totalChunks: chunks.count,
                    generatedTokens: tokens
                ))
            }
            try writer.finish()
            guard writer.framesWritten > 0 else {
                throw KikiError("The local voice model did not generate audio. Please try again.")
            }
            return outputURL
        } catch {
            writer.cancel()
            throw error
        }
    }

    func unload() {
        model = nil
        conditioning = nil
        conditionedProfileDate = nil
        Memory.clearCache()
    }

    private func loadModelIfNeeded() async throws -> Qwen3TTSModel {
        if let model { return model }
        let loaded = try await Qwen3TTSModel.fromModelDirectory(VoiceModelStore.directory)
        model = loaded
        return loaded
    }

    private func prepareConditioningIfNeeded(
        model: Qwen3TTSModel,
        profile: KikiVoiceProfile
    ) throws -> Qwen3TTSModel.Qwen3TTSReferenceConditioning {
        if conditionedProfileDate == profile.createdAt, let conditioning { return conditioning }
        let (_, referenceAudio) = try loadAudioArray(
            from: VoiceProfileStore.referenceAudioURL,
            sampleRate: model.sampleRate
        )
        let prepared = try model.prepareReferenceConditioning(
            refAudio: referenceAudio,
            refText: profile.transcript,
            language: "English"
        )
        conditioning = prepared
        conditionedProfileDate = profile.createdAt
        return prepared
    }

    static func sectionCountForDiagnostics(_ text: String) -> Int {
        chunk(text, maximumCharacters: maximumCharactersPerGeneration).count
    }

    private static func chunk(_ text: String, maximumCharacters: Int) -> [String] {
        var sentences: [String] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .bySentences) { substring, _, _, _ in
            if let value = substring?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                sentences.append(value)
            }
        }
        if sentences.isEmpty { sentences = [text] }

        var chunks: [String] = []
        var current = ""
        for sentence in sentences {
            if sentence.count > maximumCharacters {
                if !current.isEmpty {
                    chunks.append(current)
                    current = ""
                }
                var remaining = sentence
                while remaining.count > maximumCharacters {
                    let split = remaining.index(remaining.startIndex, offsetBy: maximumCharacters)
                    var candidate = String(remaining[..<split])
                    if let whitespace = candidate.lastIndex(where: { $0.isWhitespace }),
                       candidate.distance(from: whitespace, to: candidate.endIndex) < 80 {
                        candidate = String(candidate[...whitespace])
                    }
                    let consumed = candidate.count
                    chunks.append(candidate.trimmingCharacters(in: .whitespacesAndNewlines))
                    remaining = String(remaining.dropFirst(consumed)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if !remaining.isEmpty { current = remaining }
            } else if current.isEmpty {
                current = sentence
            } else if current.count + sentence.count + 1 <= maximumCharacters {
                current += " " + sentence
            } else {
                chunks.append(current)
                current = sentence
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks.filter { !$0.isEmpty }
    }
}

final class VoiceSectionJoiner {
    private let crossfadeSampleCount: Int
    private let edgePaddingSampleCount: Int
    private let rampSampleCount: Int
    private var targetRMS: Float?
    private var pendingTail: [Float] = []

    init(sampleRate: Int) {
        crossfadeSampleCount = max(1, Int(Double(sampleRate) * 0.12))
        edgePaddingSampleCount = max(1, Int(Double(sampleRate) * 0.025))
        rampSampleCount = max(1, Int(Double(sampleRate) * 0.005))
    }

    func consume(_ section: [Float]) -> [Float] {
        var prepared = trimEdgeSilence(section)
        guard !prepared.isEmpty else { return [] }

        let sectionRMS = rms(prepared)
        if let targetRMS, sectionRMS > 0.000_001 {
            let gain = min(3, max(0.3, targetRMS / sectionRMS))
            prepared = prepared.map { $0 * gain }
        } else if sectionRMS > 0.000_001 {
            targetRMS = sectionRMS
        }
        if let peak = prepared.map({ abs($0) }).max(), peak > 0.98 {
            let limiterGain = 0.98 / peak
            prepared = prepared.map { $0 * limiterGain }
        }

        if pendingTail.isEmpty {
            applyFadeIn(to: &prepared)
            return holdTail(from: prepared)
        }

        let overlapCount = min(crossfadeSampleCount, pendingTail.count, prepared.count)
        var output = Array(pendingTail.dropLast(overlapCount))
        if overlapCount > 0 {
            let pendingStart = pendingTail.count - overlapCount
            output.reserveCapacity(output.count + overlapCount + prepared.count)
            for index in 0..<overlapCount {
                let fraction = Float(index + 1) / Float(overlapCount + 1)
                output.append(
                    pendingTail[pendingStart + index] * (1 - fraction)
                        + prepared[index] * fraction
                )
            }
        }
        output.append(contentsOf: holdTail(from: Array(prepared.dropFirst(overlapCount))))
        return output
    }

    func finish() -> [Float] {
        var output = pendingTail
        pendingTail = []
        let fadeCount = min(rampSampleCount, output.count)
        guard fadeCount > 0 else { return output }
        for offset in 0..<fadeCount {
            let index = output.count - fadeCount + offset
            output[index] *= Float(fadeCount - offset - 1) / Float(fadeCount)
        }
        return output
    }

    static func joinForDiagnostics(_ sections: [[Float]], sampleRate: Int) -> [Float] {
        let joiner = VoiceSectionJoiner(sampleRate: sampleRate)
        var output: [Float] = []
        for section in sections {
            output.append(contentsOf: joiner.consume(section))
        }
        output.append(contentsOf: joiner.finish())
        return output
    }

    private func holdTail(from samples: [Float]) -> [Float] {
        guard samples.count > crossfadeSampleCount else {
            pendingTail = samples
            return []
        }
        let split = samples.count - crossfadeSampleCount
        pendingTail = Array(samples[split...])
        return Array(samples[..<split])
    }

    private func trimEdgeSilence(_ samples: [Float]) -> [Float] {
        guard !samples.isEmpty else { return [] }
        let threshold = max(0.001, min(0.02, rms(samples) * 0.08))
        guard let firstSignal = samples.firstIndex(where: { abs($0) >= threshold }),
              let lastSignal = samples.lastIndex(where: { abs($0) >= threshold }) else {
            return []
        }
        let start = max(0, firstSignal - edgePaddingSampleCount)
        let end = min(samples.count - 1, lastSignal + edgePaddingSampleCount)
        return Array(samples[start...end])
    }

    private func applyFadeIn(to samples: inout [Float]) {
        let fadeCount = min(rampSampleCount, samples.count)
        guard fadeCount > 0 else { return }
        for index in 0..<fadeCount {
            samples[index] *= Float(index + 1) / Float(fadeCount)
        }
    }

    private func rms(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        return sqrt(samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count))
    }
}

private final class StreamingVoiceWAVWriter {
    private let url: URL
    private let format: AVAudioFormat
    private let file: AVAudioFile
    private(set) var framesWritten: Int64 = 0
    private var isFinished = false
    private let sectionJoiner: VoiceSectionJoiner

    init(url: URL, sampleRate: Int) throws {
        self.url = url
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(sampleRate),
            channels: 1,
            interleaved: false
        ) else { throw KikiError("Kiki could not prepare the generated audio file.") }
        self.format = format
        self.sectionJoiner = VoiceSectionJoiner(sampleRate: sampleRate)
        try? FileManager.default.removeItem(at: url)
        self.file = try AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
    }

    func writeSection(_ samples: [Float]) throws {
        try write(sectionJoiner.consume(samples))
    }

    private func write(_ samples: [Float]) throws {
        guard !isFinished, !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(samples.count)
              ), let channel = buffer.floatChannelData?[0]
        else { return }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            channel.update(from: source.baseAddress!, count: samples.count)
        }
        try file.write(from: buffer)
        framesWritten += Int64(samples.count)
    }

    func finish() throws {
        try write(sectionJoiner.finish())
        isFinished = true
    }

    func cancel() {
        isFinished = true
        try? FileManager.default.removeItem(at: url)
    }
}
