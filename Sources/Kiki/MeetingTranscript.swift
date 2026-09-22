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
        var pieces: [String] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .bySentences) { sentence, _, _, _ in
            if let sentence {
                let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { pieces.append(trimmed) }
            }
        }
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
    let summaryMarkdown: String?
    let historyRecordID: UUID?

    init(
        title: String,
        createdAt: Date,
        duration: TimeInterval,
        segments: [MeetingTranscriptSegment],
        actionItems: [String],
        summaryMarkdown: String? = nil,
        historyRecordID: UUID? = nil
    ) {
        self.title = title
        self.createdAt = createdAt
        self.duration = duration
        self.segments = segments
        self.actionItems = actionItems
        self.summaryMarkdown = summaryMarkdown
        self.historyRecordID = historyRecordID
    }

    var speakerNames: [String] {
        var seen = Set<String>()
        return segments.compactMap { seen.insert($0.speaker).inserted ? $0.speaker : nil }
    }

    static func restoringSavedText(_ text: String, title: String, createdAt: Date, duration: TimeInterval) -> MeetingTranscript? {
        let body = text.range(of: "## Transcript\n").map { String(text[$0.upperBound...]) } ?? text
        let pattern = #"(?m)^(?:\*\*|\[)(\d{2,}):(\d\d):(\d\d)(?: — |\] )([^\n]+?):(?:\*\*)?\s*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = body as NSString
        let matches = regex.matches(in: body, range: NSRange(location: 0, length: ns.length))
        var segments: [MeetingTranscriptSegment] = []
        for (index, match) in matches.enumerated() {
            let start = NSMaxRange(match.range)
            let end = index + 1 < matches.count ? matches[index + 1].range.location : ns.length
            var speech = ns.substring(with: NSRange(location: start, length: end - start))
            if let heading = speech.range(of: "\n\n### ") { speech = String(speech[..<heading.lowerBound]) }
            speech = speech.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !speech.isEmpty else { continue }
            let seconds = (Double(ns.substring(with: match.range(at: 1))) ?? 0) * 3600
                + (Double(ns.substring(with: match.range(at: 2))) ?? 0) * 60
                + (Double(ns.substring(with: match.range(at: 3))) ?? 0)
            segments.append(.init(startTime: seconds, endTime: min(duration, seconds + 1), speaker: ns.substring(with: match.range(at: 4)), text: speech))
        }
        guard !segments.isEmpty else { return nil }
        return MeetingTranscript(title: title, createdAt: createdAt, duration: duration, segments: segments, actionItems: [])
    }

    /// Updating notes must not rewrite or re-segment the saved transcript.
    static func replacingSummary(in savedText: String, with summary: String) -> String {
        if let transcript = savedText.range(of: "## Transcript\n") {
            let prefix = String(savedText[..<transcript.lowerBound])
            let metadata = prefix.range(of: "## Summary").map { String(prefix[..<$0.lowerBound]) } ?? prefix
            return metadata + summary.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n" + savedText[transcript.lowerBound...]
        }
        return summary.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n## Transcript\n\n" + savedText
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
            actionItems: actionItems,
            summaryMarkdown: summaryMarkdown,
            historyRecordID: historyRecordID
        )
    }

    func addingSummary(_ markdown: String) -> MeetingTranscript {
        MeetingTranscript(
            title: title,
            createdAt: createdAt,
            duration: duration,
            segments: segments,
            actionItems: actionItems,
            summaryMarkdown: markdown,
            historyRecordID: historyRecordID
        )
    }

    func linkingHistoryRecord(_ id: UUID?) -> MeetingTranscript {
        MeetingTranscript(
            title: title,
            createdAt: createdAt,
            duration: duration,
            segments: segments,
            actionItems: actionItems,
            summaryMarkdown: summaryMarkdown,
            historyRecordID: id
        )
    }

    var plainText: String {
        segments.map { "[\(Self.timestamp($0.startTime))] \($0.speaker): \($0.text)" }
            .joined(separator: "\n\n")
    }

    /// A conservative review hint, never a deletion boundary. A late exchange of
    /// farewells can signal a finished call, but it can also be one person leaving.
    var possiblePostMeetingStart: UUID? {
        guard duration >= 120 else { return nil }
        let closing = segments.enumerated().filter { _, segment in
            guard segment.startTime >= duration * 0.8 else { return false }
            let words = Self.normalizedWords(segment.text)
            guard words.count <= 5 else { return false }
            return words.first == "bye" || words.first == "goodbye"
                || Array(words.prefix(2)) == ["take", "care"]
                || Array(words.prefix(2)) == ["be", "well"]
        }
        guard let last = closing.last,
              closing.contains(where: { $0.element.speaker != last.element.speaker && abs($0.element.startTime - last.element.startTime) <= 20 }),
              last.offset + 1 < segments.count,
              let final = segments.last, final.startTime - last.element.endTime >= 20 else { return nil }
        return segments[last.offset + 1].id
    }

    var summarySource: String {
        let reviewStart = possiblePostMeetingStart
        return segments.map { segment in
            let warning = segment.id == reviewStart
                ? "[REVIEW NOTE: A late farewell exchange occurred. Following speech may be post-meeting material. Do not infer new commitments from unrelated or garbled speech; retain genuine continued meeting discussion.]\n\n"
                : ""
            return warning + "[\(Self.timestamp(segment.startTime))] \(segment.speaker): \(segment.text)"
        }.joined(separator: "\n\n")
    }

    var markdown: String {
        var result = "# \(title)\n\n"
        result += "- Date: \(DateFormatter.localizedString(from: createdAt, dateStyle: .medium, timeStyle: .short))\n"
        result += "- Duration: \(Self.timestamp(duration))\n"
        result += "- Processing: Fully local\n\n"

        if let summaryMarkdown, !summaryMarkdown.isEmpty {
            result += summaryMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
            result += "\n\n"
        }

        result += "## Transcript\n\n"
        var lastChapter = -1
        let reviewStart = possiblePostMeetingStart
        for segment in segments {
            if segment.id == reviewStart {
                result += "### Possible post-meeting content — review before sharing\n\nA late farewell exchange was detected. The remaining speech is preserved below; check whether it belongs to the meeting.\n\n"
            }
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
        guard microphoneTokens.count >= 4, !remote.isEmpty else { return false }

        for segment in remote where abs(segment.startTime - microphone.startTime) <= 3 {
            let remoteTokens = normalizedWords(segment.text)
            if microphoneTokens == remoteTokens { return true }
        }
        // Compare with nearby source material only when its negation agrees.
        // Similar wording with "don't" or "not" can be a genuine disagreement,
        // not echo; dropping it would reverse the meeting's meaning.
        let negations: Set<String> = ["no", "not", "never", "cannot", "t"]
        let microphoneNegations = Set(microphoneTokens).intersection(negations)
        let compatibleRemote = remote.filter {
            Set(normalizedWords($0.text)).intersection(negations) == microphoneNegations
        }
        let remoteTokens = compatibleRemote.flatMap { normalizedWords($0.text) }
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
            .filter { !$0.isEmpty && $0 != "uh" && $0 != "um" }
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
