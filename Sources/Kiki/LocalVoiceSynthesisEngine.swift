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
                        try writer.write(audio.asArray(Float.self))
                    case .progress:
                        break
                    case .info:
                        break
                    }
                }
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

private final class StreamingVoiceWAVWriter {
    private let url: URL
    private let format: AVAudioFormat
    private let file: AVAudioFile
    private(set) var framesWritten: Int64 = 0
    private var isFinished = false

    init(url: URL, sampleRate: Int) throws {
        self.url = url
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(sampleRate),
            channels: 1,
            interleaved: false
        ) else { throw KikiError("Kiki could not prepare the generated audio file.") }
        self.format = format
        try? FileManager.default.removeItem(at: url)
        self.file = try AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
    }

    func write(_ samples: [Float]) throws {
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
        isFinished = true
    }

    func cancel() {
        isFinished = true
        try? FileManager.default.removeItem(at: url)
    }
}
