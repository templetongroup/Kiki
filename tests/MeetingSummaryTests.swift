import Foundation

struct KikiError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

@main struct MeetingSummaryTests {
    static func main() async throws {
        if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--evaluate" {
            let text = try String(contentsOfFile: CommandLine.arguments[2], encoding: .utf8)
            let expression = try NSRegularExpression(pattern: #"(?m)^- Duration: (\d{2,}):(\d\d):(\d\d)"#)
            let ns = text as NSString
            guard let match = expression.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else {
                throw KikiError("Evaluation expects a Kiki Markdown export with a Duration header.")
            }
            let duration = Double(ns.substring(with: match.range(at: 1)))! * 3600 + Double(ns.substring(with: match.range(at: 2)))! * 60 + Double(ns.substring(with: match.range(at: 3)))!
            guard let input = MeetingTranscript.restoringSavedText(text, title: "Private evaluation", createdAt: Date(), duration: duration) else {
                throw KikiError("No timestamped transcript entries found.")
            }
            do {
                let result = try await MeetingSummaryGenerator.generate(from: input) { progress in
                    fputs(progress + "\n", stderr)
                }
                print(result.markdown)
            } catch {
                fputs(error.localizedDescription + "\n", stderr)
                exit(1)
            }
            return
        }
        let meeting = MeetingTranscript(title: "Synthetic planning", createdAt: Date(), duration: 3600,
            segments: [
                .init(startTime: 10, endTime: 15, speaker: "Alex", text: "I'll pause there."),
                .init(startTime: 3500, endTime: 3510, speaker: "Jordan", text: "I will send the prototype tomorrow.")
            ], actionItems: [])
        let response = "## Summary\n\nThe team planned a prototype review.\n\n## Key points\n\n- A prototype will be reviewed.\n\n## Next steps\n\n- Jordan will send the prototype tomorrow."
        let normalized = MeetingSummaryGenerator.normalizeForDiagnostics(response, transcript: meeting)
        guard normalized?.contains("## Summary\n") == true,
              normalized?.contains("\n## Next steps\n") == true else {
            fputs("FAIL: heading normalization removed section boundaries\n", stderr); exit(1)
        }
        guard normalized?.contains("- Jordan will send the prototype tomorrow.") == true,
              normalized?.contains("I'll pause there") == false else {
            fputs("FAIL: valid model actions were overwritten by conversational excerpts\n", stderr)
            exit(1)
        }
        let leaked = response.replacingOccurrences(of: "A prototype will be reviewed.", with: "Up to five factual bullets.")
        guard MeetingSummaryGenerator.normalizeForDiagnostics(leaked, transcript: meeting) == nil else {
            fputs("FAIL: prompt instructions accepted as meeting notes\n", stderr)
            exit(1)
        }
        print("PASS: summary actions preserved; instruction leakage rejected")
        let version = MeetingTranscriptSegment.sentenceSegments(startTime: 0, endTime: 10, speaker: "Alex", text: "Use version 2.5 for the pilot. Then review it.")
        guard version.count == 2, version[0].text == "Use version 2.5 for the pilot." else {
            fputs("FAIL: decimal version split into separate transcript entries\n", stderr)
            exit(1)
        }
        print("PASS: sentence grouping preserves decimal versions")
        let echo: [MeetingTranscriptSegment] = [
            .init(startTime: 10, endTime: 15, speaker: "Speaker 1", text: "I actually had a webinar today."),
            .init(startTime: 12, endTime: 17, speaker: "You", text: "I actually uh had a um webinar today.")
        ]
        guard MeetingTranscript.deduplicatingSourceOverlap(echo).count == 1 else {
            fputs("FAIL: filler words prevent cross-source echo removal\n", stderr); exit(1)
        }
        let disagreement: [MeetingTranscriptSegment] = [
            .init(startTime: 10, endTime: 15, speaker: "Speaker 1", text: "I want the partner to decide which tools we can use for our work."),
            .init(startTime: 12, endTime: 17, speaker: "You", text: "I don't want the partner to decide which tools we can use for our work.")
        ]
        guard MeetingTranscript.deduplicatingSourceOverlap(disagreement).count == 2 else {
            fputs("FAIL: deduplication discarded a meaning-changing negation\n", stderr); exit(1)
        }
        print("PASS: cross-source echo tolerates fillers but preserves negation differences")
        let closing = MeetingTranscript(title: "Closing review", createdAt: Date(), duration: 600,
            segments: [
                .init(startTime: 0, endTime: 10, speaker: "Alex", text: "We will review the pilot."),
                .init(startTime: 550, endTime: 552, speaker: "Alex", text: "Bye."),
                .init(startTime: 553, endTime: 555, speaker: "You", text: "Take care."),
                .init(startTime: 580, endTime: 590, speaker: "You", text: "Is the door open?")
            ], actionItems: [])
        guard closing.markdown.contains("Possible post-meeting content"),
              closing.markdown.contains("Is the door open?") else {
            fputs("FAIL: post-closing material must be marked for review, not deleted\n", stderr); exit(1)
        }
        print("PASS: post-closing material marked for review and preserved")
        guard let restored = MeetingTranscript.restoringSavedText(closing.markdown, title: closing.title, createdAt: closing.createdAt, duration: closing.duration),
              restored.segments.map(\.text) == closing.segments.map(\.text) else {
            fputs("FAIL: saved meeting must reopen for summary regeneration without losing speech\n", stderr); exit(1)
        }
        let revised = MeetingTranscript.replacingSummary(in: closing.markdown, with: response)
        let originalBody = closing.markdown.components(separatedBy: "## Transcript\n").last!
        guard revised.components(separatedBy: "## Transcript\n").last == originalBody,
              let plain = MeetingTranscript.restoringSavedText(closing.plainText, title: closing.title, createdAt: closing.createdAt, duration: closing.duration),
              plain.segments.map(\.text) == closing.segments.map(\.text) else {
            fputs("FAIL: summary refresh altered saved transcript or plain-text restoration failed\n", stderr); exit(1)
        }
        let manyActions = (1...12).map { "- Reviewer \($0) will send their feedback." }.joined(separator: "\n")
        let complete = response.replacingOccurrences(of: "- Jordan will send the prototype tomorrow.", with: manyActions)
        guard let normalizedComplete = MeetingSummaryGenerator.normalizeForDiagnostics(complete, transcript: meeting),
              normalizedComplete.contains(manyActions) else {
            fputs("FAIL: long action list truncated\n", stderr); exit(1)
        }
        print("PASS: saved transcript preserved byte-for-byte; all 12 semantic actions retained")
        let acknowledgments: [MeetingTranscriptSegment] = [
            .init(startTime: 10, endTime: 11, speaker: "Speaker 1", text: "Yes."),
            .init(startTime: 11, endTime: 12, speaker: "You", text: "Yes.")
        ]
        guard MeetingTranscript.deduplicatingSourceOverlap(acknowledgments).count == 2 else {
            fputs("FAIL: short acknowledgments are not sufficient evidence of echo\n", stderr); exit(1)
        }
        let parts = (1...100).map { index in
            response.replacingOccurrences(of: "- Jordan will send the prototype tomorrow.", with: "- Owner \(index) will review item \(index).")
        }
        let combined = try MeetingSummaryGenerator.combinePartBriefs(parts, overview: "A long planning meeting.")
        guard combined.contains("- Owner 1 will review item 1."),
              combined.contains("- Owner 100 will review item 100."),
              combined.components(separatedBy: "will review item").count == 101 else {
            fputs("FAIL: aggregation lost a part's actions\n", stderr); exit(1)
        }
        print("PASS: aggregation retains actions from all 100 parts without a model-context limit")
        let partial = try MeetingSummaryGenerator.combinePartBriefs([response], overview: "Planning.", warnings: ["Part 2 needs manual review."])
        guard partial.contains("Incomplete draft"), partial.contains("## Review required"),
              partial.contains("Part 2 needs manual review."), partial.contains("Jordan will send") else {
            fputs("FAIL: partial generation must retain useful notes and clearly disclose gaps\n", stderr); exit(1)
        }
        let evidence = "[00:01:00] Alex: I don't want to use that tool."
        guard MeetingSummaryGenerator.evidenceEntry(1, in: [evidence]) == evidence,
              MeetingSummaryGenerator.evidenceEntry(2, in: [evidence]) == nil,
              MeetingSummaryGenerator.evidenceEntry(0, in: [evidence]) == nil,
              MeetingSummaryGenerator.evidenceEntry(1, in: ["Review note"]) == nil else {
            fputs("FAIL: task evidence must use an existing source entry verbatim\n", stderr); exit(1)
        }
    }
}
