import AVFoundation
import Foundation

struct KikiVoiceProfile: Codable, Sendable {
    let name: String
    let transcript: String
    let duration: TimeInterval
    let createdAt: Date
    let consentVersion: Int
}

enum VoiceProfileStore {
    static let enrollmentScript = """
    This is my voice, recorded for my private Kiki voice model. On a bright morning, I might speak quickly with excitement; later, I may slow down to explain a thoughtful idea. Clear words, quiet pauses, and natural expression all belong here. Numbers like twenty-seven, dates like October fifth, and questions such as, “Where should we begin?” help capture the way I actually sound. I consent to Kiki using this recording only on this Mac to create speech in my voice.
    """

    static var directory: URL {
        if let override = ProcessInfo.processInfo.environment["KIKI_VOICE_PROFILE_ROOT"],
           !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Kiki/Voice Studio", isDirectory: true)
    }

    static var referenceAudioURL: URL {
        directory.appendingPathComponent("my-voice-reference.wav")
    }

    static var profileURL: URL {
        directory.appendingPathComponent("my-voice.json")
    }

    static var generatedDirectory: URL {
        directory.appendingPathComponent("Generated", isDirectory: true)
    }

    static func ensureDirectories() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: generatedDirectory, withIntermediateDirectories: true)
    }

    static func load() -> KikiVoiceProfile? {
        guard let data = try? Data(contentsOf: profileURL),
              let profile = try? JSONDecoder().decode(KikiVoiceProfile.self, from: data),
              FileManager.default.fileExists(atPath: referenceAudioURL.path)
        else { return nil }
        return profile
    }

    static func save(samples: [Float], name: String) throws -> KikiVoiceProfile {
        try ensureDirectories()
        guard !samples.isEmpty else { throw KikiError("No voice audio was recorded.") }
        let tempAudio = directory.appendingPathComponent("my-voice-reference.tmp.wav")
        try? FileManager.default.removeItem(at: tempAudio)
        try writeMonoWAV(samples: samples, sampleRate: AudioRecorder.sampleRate, to: tempAudio)
        try? FileManager.default.removeItem(at: referenceAudioURL)
        try FileManager.default.moveItem(at: tempAudio, to: referenceAudioURL)

        let profile = KikiVoiceProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "My Voice" : name,
            transcript: enrollmentScript,
            duration: Double(samples.count) / AudioRecorder.sampleRate,
            createdAt: Date(),
            consentVersion: 1
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(profile).write(to: profileURL, options: .atomic)
        return profile
    }

    static func delete() throws {
        if FileManager.default.fileExists(atPath: referenceAudioURL.path) {
            try FileManager.default.removeItem(at: referenceAudioURL)
        }
        if FileManager.default.fileExists(atPath: profileURL.path) {
            try FileManager.default.removeItem(at: profileURL)
        }
    }

    static func writePreview(samples: [Float]) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Kiki Voice Recording Preview.wav")
        try? FileManager.default.removeItem(at: url)
        try writeMonoWAV(samples: samples, sampleRate: AudioRecorder.sampleRate, to: url)
        return url
    }

    static func newGeneratedURL() throws -> URL {
        try ensureDirectories()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' h.mm.ss a"
        return generatedDirectory
            .appendingPathComponent("Kiki Voice — \(formatter.string(from: Date())).wav")
    }

    static func recordingQuality(samples: [Float]) -> VoiceRecordingQuality {
        guard !samples.isEmpty else { return .init(duration: 0, rms: 0, peak: 0, clippedFraction: 0) }
        var sumSquares: Double = 0
        var peak: Float = 0
        var clipped = 0
        for sample in samples {
            let absolute = abs(sample)
            peak = max(peak, absolute)
            sumSquares += Double(sample * sample)
            if absolute >= 0.98 { clipped += 1 }
        }
        return VoiceRecordingQuality(
            duration: Double(samples.count) / AudioRecorder.sampleRate,
            rms: Float(sqrt(sumSquares / Double(samples.count))),
            peak: peak,
            clippedFraction: Double(clipped) / Double(samples.count)
        )
    }

    private static func writeMonoWAV(samples: [Float], sampleRate: Double, to url: URL) throws {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ), let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(samples.count)
        ), let channel = buffer.floatChannelData?[0] else {
            throw KikiError("Kiki could not prepare the voice recording.")
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            channel.update(from: source.baseAddress!, count: samples.count)
        }
        let file = try AVAudioFile(
            forWriting: url,
            settings: format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        try file.write(from: buffer)
    }
}

struct VoiceRecordingQuality: Sendable {
    let duration: TimeInterval
    let rms: Float
    let peak: Float
    let clippedFraction: Double

    var isLongEnough: Bool { duration >= 20 }
    var isTooLong: Bool { duration > 90 }
    var isTooQuiet: Bool { rms < 0.015 }
    var isClipping: Bool { clippedFraction > 0.0005 || peak >= 0.999 }

    var message: String {
        if !isLongEnough { return "Keep reading—the recording needs at least 20 seconds." }
        if isTooLong { return "That is enough audio. You can save this voice now." }
        if isTooQuiet { return "The recording is too quiet. Move closer to your microphone and try again." }
        if isClipping { return "The recording clipped. Move slightly farther from the microphone and try again." }
        return "Clear recording • \(Int(duration.rounded())) seconds • ready to save"
    }

    var canSave: Bool { isLongEnough && !isTooQuiet && !isClipping }
}
