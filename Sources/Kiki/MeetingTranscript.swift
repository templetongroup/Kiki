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
}

struct MeetingTranscript: Codable, Sendable {
    let title: String
    let createdAt: Date
    let duration: TimeInterval
    let segments: [MeetingTranscriptSegment]
    let actionItems: [String]

    var plainText: String {
        segments.map { "[\(Self.timestamp($0.startTime))] \($0.speaker): \($0.text)" }
            .joined(separator: "\n\n")
    }

    var markdown: String {
        var result = "# \(title)\n\n"
        result += "- Date: \(DateFormatter.localizedString(from: createdAt, dateStyle: .medium, timeStyle: .short))\n"
        result += "- Duration: \(Self.timestamp(duration))\n"
        result += "- Processing: Fully local\n\n"
        if !actionItems.isEmpty {
            result += "## Possible action items\n\n"
            result += actionItems.map { "- [ ] \($0)" }.joined(separator: "\n") + "\n\n"
        }
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

    static func actionItems(from segments: [MeetingTranscriptSegment]) -> [String] {
        let patterns = ["need to", "will send", "will follow", "follow up", "action item", "to-do", "todo", "schedule", "please send", "I’ll", "I'll"]
        var items: [String] = []
        for segment in segments {
            let sentences = segment.text.split(whereSeparator: { ".!?".contains($0) })
            for sentence in sentences {
                let value = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                guard value.count >= 8,
                      patterns.contains(where: { value.localizedCaseInsensitiveContains($0) }),
                      !items.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame })
                else { continue }
                items.append(value)
            }
        }
        return Array(items.prefix(20))
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

