import AVFoundation
import Foundation

enum VoiceEnrollmentMode: String, Codable, CaseIterable, Sendable {
    case quick
    case full

    var displayName: String {
        switch self {
        case .quick: "Quick"
        case .full: "Full"
        }
    }

    var explanation: String {
        switch self {
        case .quick:
            "About 30–60 seconds. Faster setup that works well, but captures less of your vocal range."
        case .full:
            "About 7–10 minutes. Takes longer, but captures more sounds, pacing, and expression for better accuracy and naturalness."
        }
    }

    var script: String {
        switch self {
        case .quick: VoiceProfileStore.quickEnrollmentScript
        case .full: VoiceProfileStore.fullEnrollmentScript
        }
    }

    var minimumDuration: TimeInterval {
        switch self {
        case .quick: 20
        case .full: 300
        }
    }

    var maximumDuration: TimeInterval {
        switch self {
        case .quick: 90
        case .full: 1_200
        }
    }
}

struct KikiVoiceProfile: Codable, Sendable {
    let name: String
    let transcript: String
    let duration: TimeInterval
    let createdAt: Date
    let consentVersion: Int
    let enrollmentMode: VoiceEnrollmentMode?
}

enum VoiceProfileStore {
    static let quickEnrollmentScript = """
    This is my voice, recorded for my private Kiki voice model. On a bright morning, I might speak quickly with excitement; later, I may slow down to explain a thoughtful idea. Clear words, quiet pauses, and natural expression all belong here. Numbers like twenty-seven, dates like October fifth, and questions such as, “Where should we begin?” help capture the way I actually sound. I consent to Kiki using this recording only on this Mac to create speech in my voice.
    """

    static let fullEnrollmentScript = """
    Record the following verbatim in a quiet, non-reverberant room. Speak naturally and consistently—clear, but not exaggerated—and leave a brief pause between paragraphs.
    Good morning. I’m recording this sample so that my voice can be reproduced clearly, naturally, and consistently. I’ll speak at a comfortable pace, using the same tone and volume I normally use in conversation. Some sentences will be short. Others will be longer and more expressive, allowing the rhythm of my voice to rise, fall, pause, and continue in a natural way.
    Today feels calm and bright. The air is cool, the room is quiet, and everything is ready. I picked up a small blue notebook, placed it beside the window, and wrote down three simple ideas. First, be curious. Second, pay attention. Third, take your time. These ordinary phrases contain many of the sounds and transitions that appear in everyday speech.
    Please bring the fresh bread, green apples, yellow peppers, and a jar of sweet raspberry jam. Victor packed five boxes before breakfast, while Zoe quickly checked the shipping labels. Jack chose a crisp white shirt. George gently closed the garage door. The curious cat watched a bright red bird fly across the quiet garden.
    Thin threads twisted through thick cloth. Those smooth stones were gathered near the northern shore. She sells polished shells, but he prefers small silver coins. Which watch did William wear? Why would anyone whisper during a lively celebration? A cheerful child laughed, jumped, and waved from the wooden bridge.
    I can speak softly when the moment calls for it. I can also sound confident, focused, and direct. Sometimes I’m thoughtful: perhaps we should consider another approach. Sometimes I’m pleasantly surprised: oh, that worked better than I expected! And sometimes I need to be firm: stop, check the details, and make sure everything is correct.
    Are you ready? Did you remember the keys? Where should we meet, and when should we leave? I thought the appointment was on Thursday, but apparently it was moved to Friday. That’s fine—we can adjust. Would you rather arrive early, or take a little more time?
    Here is a longer thought. When people speak naturally, they do not give every word the same weight. Important words receive emphasis, familiar phrases move more quickly, and complicated ideas often include small pauses that help the listener follow along. A believable voice is not perfectly mechanical. It breathes, changes direction, and responds to the meaning of each sentence.
    Let’s practice a few practical details. The meeting begins at 9:30 in the morning on Tuesday, October 14, 2026. The reference number is 7,482. The temperature rose from 18 degrees to 27 degrees. The total cost was $42.95, including an 8 percent service charge. Call extension 305, or send a message to alex@example.com. The package weighs 2.6 kilograms and should arrive within three to five business days.
    I use abbreviations and names in ordinary conversation. Dr. Maya Chen met James O’Connor near Fifth Avenue. They discussed NASA, the FBI, artificial intelligence, and a new electric vehicle. The USB cable was connected to a Mac, while the Wi-Fi router restarted in the background. Later, Maya traveled from New York to San Francisco and then continued to São Paulo.
    Now I’ll vary the pacing. Slowly and carefully, I opened the old wooden box. Inside, beneath a folded piece of cloth, I found a tiny brass key. Then everything happened at once: the phone rang, the dog barked, someone knocked at the door, and a glass rolled across the kitchen floor. After a moment, the house became quiet again.
    Listen to the contrast between these ideas: light and dark, early and late, narrow and wide, rough and smooth, serious and playful. We may agree completely, disagree politely, or remain uncertain. “I know,” sounds different from, “I think I know,” and both are different from, “I really don’t know.”
    Not every day goes according to plan. A delayed train, a missing document, or an unexpected storm can change the schedule. When that happens, I take a breath, review the situation, and decide what to do next. Frustration is understandable, but a calm explanation usually works better than a rushed reaction.
    On better days, there is plenty to enjoy: music playing in another room, coffee brewing in the kitchen, friends telling familiar stories, and sunlight moving slowly across the floor. These moments may seem small, yet they often become the ones we remember most clearly.
    Before I finish, I’ll speak in my most natural conversational voice. If you’re listening to this later, I hope the result sounds like me—not merely the pitch of my voice, but its pace, warmth, pronunciation, and personality. The goal is a voice that remains clean and recognizable whether it is reading a short notification, explaining a difficult subject, asking a question, or telling a complete story.
    This is the end of the reference recording. I have spoken clearly, consistently, and naturally, with a useful range of sounds, sentence lengths, emotions, numbers, names, and speaking patterns. Thank you for listening.

    For best results, capture 10–20 minutes across several clips, not one giant recording. Keep the microphone position, room, gain, and vocal style unchanged; avoid music, noise reduction, reverb, and improvised words that differ from the transcript. A clean, perfectly matched transcript is usually more valuable than a dramatic performance.
    """

    static let enrollmentScript = quickEnrollmentScript

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

    static func save(
        samples: [Float],
        name: String,
        enrollmentMode: VoiceEnrollmentMode = .quick
    ) throws -> KikiVoiceProfile {
        try ensureDirectories()
        guard !samples.isEmpty else { throw KikiError("No voice audio was recorded.") }
        let tempAudio = directory.appendingPathComponent("my-voice-reference.tmp.wav")
        try? FileManager.default.removeItem(at: tempAudio)
        try writeMonoWAV(samples: samples, sampleRate: AudioRecorder.sampleRate, to: tempAudio)
        try? FileManager.default.removeItem(at: referenceAudioURL)
        try FileManager.default.moveItem(at: tempAudio, to: referenceAudioURL)

        let profile = KikiVoiceProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "My Voice" : name,
            transcript: enrollmentMode.script,
            duration: Double(samples.count) / AudioRecorder.sampleRate,
            createdAt: Date(),
            consentVersion: 1,
            enrollmentMode: enrollmentMode
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

    static func recordingQuality(
        samples: [Float],
        minimumDuration: TimeInterval = VoiceEnrollmentMode.quick.minimumDuration,
        maximumDuration: TimeInterval = VoiceEnrollmentMode.quick.maximumDuration
    ) -> VoiceRecordingQuality {
        guard !samples.isEmpty else {
            return .init(
                duration: 0,
                rms: 0,
                peak: 0,
                clippedFraction: 0,
                minimumDuration: minimumDuration,
                maximumDuration: maximumDuration
            )
        }
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
            clippedFraction: Double(clipped) / Double(samples.count),
            minimumDuration: minimumDuration,
            maximumDuration: maximumDuration
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
    let minimumDuration: TimeInterval
    let maximumDuration: TimeInterval

    var isLongEnough: Bool { duration >= minimumDuration }
    var isTooLong: Bool { duration > maximumDuration }
    var isTooQuiet: Bool { rms < 0.015 }
    var isClipping: Bool { clippedFraction > 0.0005 || peak >= 0.999 }

    var message: String {
        if !isLongEnough {
            let minimum = minimumDuration >= 60
                ? "\(Int(minimumDuration / 60)) minutes"
                : "\(Int(minimumDuration)) seconds"
            return "Keep reading—the recording needs at least \(minimum)."
        }
        if isTooLong { return "That is enough audio. You can save this voice now." }
        if isTooQuiet { return "The recording is too quiet. Move closer to your microphone and try again." }
        if isClipping { return "The recording clipped. Move slightly farther from the microphone and try again." }
        return "Clear recording • \(Int(duration.rounded())) seconds • ready to save"
    }

    var canSave: Bool { isLongEnough && !isTooQuiet && !isClipping }
}
