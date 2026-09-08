import Foundation

struct MeetingTranscriptSegment: Codable, Identifiable, Sendable {
    let id: UUID
    let startTime: TimeInterval
    let endTime: TimeInterval
    let speaker: String
    let text: String

    init(
        id: UUID = UUID(),
        startTime: TimeInterval,
        endTime: TimeInterval,
        speaker: String,
        text: String
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.speaker = speaker
        self.text = text
    }

    static func sentenceSegments(
        startTime: TimeInterval,
        endTime: TimeInterval,
        speaker: String,
        text: String
    ) -> [MeetingTranscriptSegment] {
        let pattern = "[^.!?]+[.!?]+|[^.!?]+$"
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let pieces = (try? NSRegularExpression(pattern: pattern))?
            .matches(in: text, range: range)
            .compactMap { Range($0.range, in: text).map { String(text[$0]).trimmingCharacters(in: .whitespacesAndNewlines) } }
            .filter { !$0.isEmpty } ?? [text]
        guard pieces.count > 1 else {
            return [MeetingTranscriptSegment(startTime: startTime, endTime: endTime, speaker: speaker, text: text)]
        }
        let duration = max(0.001, endTime - startTime)
        return pieces.enumerated().map { index, piece in
            let pieceStart = startTime + duration * Double(index) / Double(pieces.count)
            let pieceEnd = startTime + duration * Double(index + 1) / Double(pieces.count)
            return MeetingTranscriptSegment(startTime: pieceStart, endTime: pieceEnd, speaker: speaker, text: piece)
        }
    }
}

struct MeetingTranscript: Codable, Sendable {
    let title: String
    let createdAt: Date
    let duration: TimeInterval
    let segments: [MeetingTranscriptSegment]
    let actionItems: [String]

    var speakerNames: [String] {
        var seen = Set<String>()
        return segments.compactMap { seen.insert($0.speaker).inserted ? $0.speaker : nil }
    }

    func renamingSpeaker(from oldName: String, to newName: String) -> MeetingTranscript {
        let replacement = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !replacement.isEmpty else { return self }
        let revised = segments.map { segment in
            MeetingTranscriptSegment(
                id: segment.id,
                startTime: segment.startTime,
                endTime: segment.endTime,
                speaker: segment.speaker == oldName ? replacement : segment.speaker,
                text: segment.text
            )
        }
        return replacingSegments(revised)
    }

    func assigningSpeaker(_ speaker: String, to segmentIDs: Set<UUID>) -> MeetingTranscript {
        let revised = segments.map { segment in
            MeetingTranscriptSegment(
                id: segment.id,
                startTime: segment.startTime,
                endTime: segment.endTime,
                speaker: segmentIDs.contains(segment.id) ? speaker : segment.speaker,
                text: segment.text
            )
        }
        return replacingSegments(revised)
    }

    private func replacingSegments(_ revised: [MeetingTranscriptSegment]) -> MeetingTranscript {
        MeetingTranscript(
            title: title,
            createdAt: createdAt,
            duration: duration,
            segments: revised,
            actionItems: actionItems
        )
    }

    var plainText: String {
        segments.map { "[\(Self.timestamp($0.startTime))] \($0.speaker): \($0.text)" }
            .joined(separator: "\n\n")
    }

    var markdown: String {
        var result = "# \(title)\n\n"
        result += "- Date: \(DateFormatter.localizedString(from: createdAt, dateStyle: .medium, timeStyle: .short))\n"
        result += "- Duration: \(Self.timestamp(duration))\n"
        result += "- Processing: Fully local\n\n"

        result += "## Transcript\n\n"
        var lastChapter = -1
        for segment in segments {
            let chapter = Int(segment.startTime / 300)
            if chapter != lastChapter {
                result += "### Chapter \(chapter + 1) · \(Self.timestamp(TimeInterval(chapter * 300)))\n\n"
                lastChapter = chapter
            }
            result += "**\(Self.timestamp(segment.startTime)) — \(segment.speaker):** \(segment.text)\n\n"
        }
        return result
    }

    var srt: String {
        segments.enumerated().map { index, segment in
            "\(index + 1)\n\(Self.captionTimestamp(segment.startTime, separator: ",")) --> \(Self.captionTimestamp(segment.endTime, separator: ","))\n\(segment.speaker): \(segment.text)"
        }.joined(separator: "\n\n")
    }

    var vtt: String {
        "WEBVTT\n\n" + segments.enumerated().map { index, segment in
            "\(index + 1)\n\(Self.captionTimestamp(segment.startTime, separator: ".")) --> \(Self.captionTimestamp(segment.endTime, separator: "."))\n<v \(segment.speaker)>\(segment.text)"
        }.joined(separator: "\n\n")
    }

    static func deduplicatingSourceOverlap(
        _ segments: [MeetingTranscriptSegment],
        microphoneSpeaker: String = "You"
    ) -> [MeetingTranscriptSegment] {
        let ordered = segments.sorted {
            if $0.startTime == $1.startTime { return $0.speaker < $1.speaker }
            return $0.startTime < $1.startTime
        }
        let remote = ordered.filter { $0.speaker != microphoneSpeaker }
        guard !remote.isEmpty else { return ordered }
        return ordered.filter { segment in
            guard segment.speaker == microphoneSpeaker else { return true }
            let nearbyRemote = remote.filter {
                abs($0.startTime - segment.startTime) <= 32
            }
            return !isMicrophoneEcho(segment, of: nearbyRemote)
        }
    }

    private static func isMicrophoneEcho(
        _ microphone: MeetingTranscriptSegment,
        of remote: [MeetingTranscriptSegment]
    ) -> Bool {
        let microphoneTokens = normalizedWords(microphone.text)
        guard !microphoneTokens.isEmpty, !remote.isEmpty else { return false }

        for segment in remote where abs(segment.startTime - microphone.startTime) <= 3 {
            let remoteTokens = normalizedWords(segment.text)
            if microphoneTokens == remoteTokens { return true }
        }
        guard microphoneTokens.count >= 4 else { return false }

        let remoteTokens = remote.flatMap { normalizedWords($0.text) }
        guard remoteTokens.count >= 4 else { return false }
        let microphoneText = microphoneTokens.joined(separator: " ")
        let remoteText = remoteTokens.joined(separator: " ")
        if remoteText.contains(microphoneText) { return true }

        let microphoneBigrams = adjacentPairs(microphoneTokens)
        let remoteBigrams = Set(adjacentPairs(remoteTokens))
        guard !microphoneBigrams.isEmpty else { return false }
        let matchingBigrams = microphoneBigrams.filter(remoteBigrams.contains).count
        return Double(matchingBigrams) / Double(microphoneBigrams.count) >= 0.72
    }

    private static func normalizedWords(_ text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private static func adjacentPairs(_ words: [String]) -> [String] {
        guard words.count > 1 else { return [] }
        return zip(words, words.dropFirst()).map { "\($0) \($1)" }
    }

    private static func timestamp(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    private static func captionTimestamp(_ seconds: TimeInterval, separator: String) -> String {
        let milliseconds = max(0, Int((seconds * 1000).rounded()))
        return String(
            format: "%02d:%02d:%02d%@%03d",
            milliseconds / 3_600_000,
            (milliseconds % 3_600_000) / 60_000,
            (milliseconds % 60_000) / 1000,
            separator,
            milliseconds % 1000
        )
    }
}
