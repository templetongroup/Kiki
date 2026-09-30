import Foundation

struct KikiError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

@main struct MeetingSummaryTests {
    static func main() async throws {
        if (CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--evaluate") ||
           (CommandLine.arguments.count == 4 && CommandLine.arguments[1] == "--render-draft") ||
           (CommandLine.arguments.count == 5 && ["--audit-action", "--audit-source"].contains(CommandLine.arguments[1])) {
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
                if ["--audit-action", "--audit-source"].contains(CommandLine.arguments[1]) {
                    let prefix = CommandLine.arguments[3]
                    var actions: [LocalMeetingSummarizer.Action] = []
                    for index in 1...32 {
                        let path = prefix + "-\(index).json"
                        guard FileManager.default.fileExists(atPath: path) else { break }
                        actions += try JSONDecoder().decode(LocalMeetingSummarizer.Notes.self, from: Data(contentsOf: URL(fileURLWithPath: path))).actions
                    }
                    guard let index = Int(CommandLine.arguments[4]), index > 0, index <= actions.count else { throw KikiError("Invalid evaluation candidate index") }
                    if CommandLine.arguments[1] == "--audit-source" {
                        let candidate = actions[index - 1]
                        print(LocalMeetingSummarizer.reviewSource(text: candidate.task, references: candidate.entries ?? [], quotes: candidate.quotes,
                            entries: input.summarySource.components(separatedBy: "\n\n").filter { !$0.isEmpty }))
                        return
                    }
                    let result = try await LocalMeetingSummarizer.reviewAction(actions[index - 1],
                        entries: input.summarySource.components(separatedBy: "\n\n").filter { !$0.isEmpty },
                        model: ProcessInfo.processInfo.environment["KIKI_LOCAL_SUMMARY_MODEL"] ?? "apple")
                    print(String(decoding: try JSONEncoder().encode(result.map { [$0] } ?? []), as: UTF8.self))
                    return
                }
                let result: MeetingSummaryResult
                if CommandLine.arguments[1] == "--render-draft" {
                    let notes = try JSONDecoder().decode(LocalMeetingSummarizer.Notes.self,
                        from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[3])))
                    result = try LocalMeetingSummarizer.render(notes, transcript: input, model: "saved evaluation draft")
                } else if let model = ProcessInfo.processInfo.environment["KIKI_LOCAL_SUMMARY_MODEL"],
                   let draftPath = ProcessInfo.processInfo.environment["KIKI_EVALUATION_DRAFT_PATH"] {
                    result = try await LocalMeetingSummarizer.generate(transcript: input, model: model,
                        onProgress: { fputs($0 + "\n", stderr) }, inspectDraft: { notes in
                            let encoder = JSONEncoder()
                            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                            try encoder.encode(notes).write(to: URL(fileURLWithPath: draftPath), options: .atomic)
                        }, inspectSection: { index, notes in
                            if let prefix = ProcessInfo.processInfo.environment["KIKI_EVALUATION_SECTION_PREFIX"] {
                                let encoder = JSONEncoder()
                                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                                try encoder.encode(notes).write(to: URL(fileURLWithPath: prefix + "-\(index).json"), options: .atomic)
                            }
                        }, inspectAction: { index, candidate, reviewed in
                            if let prefix = ProcessInfo.processInfo.environment["KIKI_EVALUATION_AUDIT_PREFIX"] {
                                struct Trace: Codable {
                                    let candidate: LocalMeetingSummarizer.Action
                                    let reviewed: LocalMeetingSummarizer.Action?
                                }
                                let encoder = JSONEncoder()
                                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                                try encoder.encode(Trace(candidate: candidate, reviewed: reviewed)).write(
                                    to: URL(fileURLWithPath: prefix + "-\(index).json"), options: .atomic)
                            }
                        }, savedSections: try ProcessInfo.processInfo.environment["KIKI_EVALUATION_CACHED_SECTION_PREFIX"].map { prefix in
                            let original = input.summarySource.components(separatedBy: "\n\n").filter { !$0.isEmpty }
                            let numbered = original.enumerated().map { "ENTRY \($0.offset + 1):\n\($0.element)" }.joined(separator: "\n\n")
                            let count = try LocalMeetingSummarizer.sourceParts(numbered, maximumBytes: model == "apple" ? 5_000 : 14_000).count
                            var cached: [LocalMeetingSummarizer.Notes] = []
                            for index in 1...count {
                                let path = prefix + "-\(index).json"
                                guard FileManager.default.fileExists(atPath: path) else { break }
                                cached.append(try JSONDecoder().decode(LocalMeetingSummarizer.Notes.self,
                                    from: Data(contentsOf: URL(fileURLWithPath: path))))
                            }
                            return cached
                        })
                } else {
                    result = try await MeetingSummaryGenerator.generate(from: input) { fputs($0 + "\n", stderr) }
                }
                print(result.markdown)
            } catch {
                fputs(error.localizedDescription + "\n", stderr)
                exit(1)
            }
            return
        }
        let gate = MeetingSummaryGenerationGate()
        let firstJob = await gate.acquire()
        let simultaneousJob = await gate.acquire()
        precondition(firstJob && !simultaneousJob, "Summary surfaces must not run competing inference jobs")
        await gate.release()
        let captureStarted = await gate.beginCapture()
        let summaryDuringCapture = await gate.acquire()
        precondition(captureStarted && !summaryDuringCapture, "Summary inference must not overlap meeting capture/final transcription")
        await gate.endCapture()
        let summaryStarted = await gate.acquire()
        let captureDuringSummary = await gate.beginCapture()
        precondition(summaryStarted && !captureDuringSummary, "Starting a capture must not erase a transcript or overlap a running summary")
        await gate.release()
        let retryJob = await gate.acquire()
        precondition(retryJob, "Completing or cancelling a summary must permit another job")
        await gate.release()
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
        let opening = MeetingTranscript(title: "Long review", createdAt: Date(), duration: 3200,
            segments: [
                .init(startTime: 0, endTime: 5, speaker: "You", text: "That one."),
                .init(startTime: 8, endTime: 12, speaker: "You", text: "That one is not solvable next month."),
                .init(startTime: 2900, endTime: 2910, speaker: "Sam", text: "I will send the backup quote tomorrow.")
            ], actionItems: [])
        let openingOnly = "## Summary\n\nThat one. That one is not solvable next month.\n\n## Key points\n\n- That one.\n\n## Next steps\n\n- We will see if anyone hears it."
        guard MeetingSummaryGenerator.normalizeForDiagnostics(openingOnly, transcript: opening) == nil else {
            fputs("FAIL: opening-only fallback accepted as a full meeting summary\n", stderr); exit(1)
        }
        let timed = MeetingTranscriptSegment.sentenceSegments(startTime: 100, endTime: 130, speaker: "Alex", text: "Ready. Send it tomorrow.", words: [
            .init(text: "Ready.", startTime: 2, endTime: 3),
            .init(text: "Send", startTime: 25, endTime: 25.5),
            .init(text: "it", startTime: 25.5, endTime: 26),
            .init(text: "tomorrow.", startTime: 26, endTime: 27)
        ])
        precondition(timed.map(\.startTime) == [102, 125], "Sentence times must follow recognized speech, not divide the chunk evenly")
        precondition(timed.map(\.endTime) == [103, 127], "Silence must not stretch sentence times")
        let mismatched = MeetingTranscriptSegment.sentenceSegments(startTime: 100, endTime: 130, speaker: "Alex", text: "Different words.", words: [
            .init(text: "Ready.", startTime: 2, endTime: 3)
        ])
        precondition(mismatched.first?.text == "Different words." && mismatched.first?.startTime == 100,
                     "A post-processing text change must not inherit unrelated word timings")
        let invalid = MeetingTranscriptSegment.sentenceSegments(startTime: 100, endTime: 130, speaker: "Alex", text: "Ready.", words: [
            .init(text: "Ready.", startTime: .nan, endTime: 3)
        ])
        precondition(invalid.first?.startTime == 100, "Invalid acoustic times must not enter saved data")
        let outside = MeetingTranscriptSegment.sentenceSegments(startTime: 100, endTime: 130, speaker: "Alex", text: "Ready.", words: [
            .init(text: "Ready.", startTime: 30.05, endTime: 30.09)
        ])
        precondition(outside.first?.startTime == 100, "Words beginning outside a chunk must not create inverted time ranges")
        print("PASS: acoustic sentence times preserve pauses and reject mismatched or invalid timing")
        let crossing = [
            MeetingWordTiming(text: "before", startTime: 0, endTime: 0.5),
            MeetingWordTiming(text: "boundary", startTime: 1.3, endTime: 1.7),
            MeetingWordTiming(text: "after", startTime: 2, endTime: 2.4)
        ]
        let owned = MeetingTranscriptSegment.wordsOwnedByCore(crossing, inferenceStart: 28.5, coreStart: 30, coreEnd: 60)
        precondition(owned?.map(\.text) == ["boundary", "after"])
        precondition(abs((owned?.first?.startTime ?? 0) - 0) < 0.001)
        precondition(MeetingTranscriptSegment.wordsOwnedByCore([.init(text: "bad", startTime: .nan, endTime: 2)], inferenceStart: 0, coreStart: 0, coreEnd: 30) == nil)
        print("PASS: overlap words assigned by acoustic midpoint; invalid timing cannot silently discard speech")
        var chunked: [MeetingTranscriptSegment] = [.init(startTime: 29.4, endTime: 30, speaker: "You", text: "The archive")]
        MeetingTranscriptSegment.appendChunk([.init(startTime: 30.1, endTime: 33.5, speaker: "You", text: "license costs four to five dollars.")], to: &chunked)
        precondition(chunked.count == 1 && chunked[0].text == "The archive license costs four to five dollars.")
        MeetingTranscriptSegment.appendChunk([.init(startTime: 34, endTime: 35, speaker: "You", text: "Next topic.")], to: &chunked)
        precondition(chunked.count == 2, "Do not merge completed sentences")
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
        let fragments = ["[00:01:00] Sam: I will send the size of every user's", "[00:01:05] Sam: Drive."]
        precondition(MeetingSummaryGenerator.evidenceForQuote("Drive.", in: fragments) == nil)
        precondition(MeetingSummaryGenerator.evidenceForQuote("I will send the size of every user's Drive.", in: fragments) == fragments.joined(separator: "\n  "))
        precondition(MeetingSummaryGenerator.evidenceForQuote("I will send the estimate tomorrow.", in: fragments) == nil)
        precondition(MeetingSummaryGenerator.evidenceForQuote("Sam: I will send the size of every user's Drive.", in: fragments) == fragments.joined(separator: "\n  "))
        let identified = ["[00:01:00] Alex: I will review the drawings tomorrow.", "[00:02:00] Morgan: I will send the overall box volume."]
        precondition(MeetingSummaryGenerator.evidenceForQuote("Alex: I will send the overall box volume.", in: identified) == nil,
                     "A speaker-prefixed quote must not match someone else's words")
        precondition(!MeetingSummaryGenerator.detailsAreGrounded("Send the drive size this week", in: fragments.joined(separator: " ")))
        precondition(!MeetingSummaryGenerator.detailsAreGrounded("Send the 45 GB report", in: "Send the 4 GB report."))
        precondition(MeetingSummaryGenerator.detailsAreGrounded("Send the drive size", in: fragments.joined(separator: " ")))
        precondition(!MeetingSummaryGenerator.detailsAreGrounded("Send 45 files", in: "[00:45:00] Sam: Send the files."))
        precondition(!MeetingSummaryGenerator.detailsAreGrounded("The team plans to prohibit external storage.",
            in: "I could implement a policy to prohibit external storage."), "A possible policy is not an agreed plan")
        precondition(MeetingSummaryGenerator.detailsAreGrounded("A policy to prohibit external storage was proposed.",
            in: "I could implement a policy to prohibit external storage."))
        precondition(MeetingSummaryGenerator.detailsAreGrounded("The team approved the policy.",
            in: "We could delay it, but we approved the policy."))
        let focused = ["[00:00:10] Sam: Tomorrow we discuss costs.", "[00:00:12] Sam: I will send the size of every drive."]
        precondition(MeetingSummaryGenerator.evidenceForQuote("I will send the size of every drive.", in: focused) == focused[1],
                     "Evidence must not borrow unrelated neighboring dates")
        let localNotes = LocalMeetingSummarizer.Notes(overview: "The team planned a prototype review.",
            points: [.init(text: "A prototype will be sent.", quote: "I will send the prototype tomorrow.")],
            actions: [.init(task: "Send the prototype next week.", quote: "I will send the prototype tomorrow.")], openQuestions: [])
        let localResult = try LocalMeetingSummarizer.render(localNotes, transcript: meeting, model: "test")
        precondition(localResult.markdown.contains("Incomplete draft"))
        precondition(!localResult.markdown.contains("next week"))
        precondition(!localResult.warnings.isEmpty)
        let separateEvidence = ["[00:01:00] Sam: We operate fourteen laptops at this location.",
                                "[00:02:00] Sam: We also keep two spare laptops here."]
        precondition(LocalMeetingSummarizer.evidenceForQuotes([
            "We operate fourteen laptops at this location.", "We also keep two spare laptops here."
        ], entries: separateEvidence) == separateEvidence.joined(separator: "\n  "))
        precondition(LocalMeetingSummarizer.evidenceForQuotes([
            "We operate fourteen laptops at this location.", "We will buy ten computers next week."
        ], entries: separateEvidence) == nil)
        precondition(LocalMeetingSummarizer.evidenceForReferences([1, 2], quotes: [], entries: separateEvidence) == separateEvidence.joined(separator: "\n  "))
        precondition(LocalMeetingSummarizer.evidenceForReferences([0], quotes: [], entries: separateEvidence) == nil)
        precondition(LocalMeetingSummarizer.evidenceForReferences([3], quotes: [], entries: separateEvidence) == nil)
        let auditSource = "ENTRY 4:\n[00:01:00] Sam: I will send the quote.\n\nENTRY 9:\n[00:02:00] Sam: Tomorrow."
        precondition(LocalMeetingSummarizer.reviewedClaimHasValidReferences("Sam will send the quote tomorrow.", references: [4, 9], source: auditSource))
        precondition(!LocalMeetingSummarizer.reviewedClaimHasValidReferences("Sam will send the quote.", references: [5], source: auditSource), "A verifier cannot cite unseen speech")
        precondition(!LocalMeetingSummarizer.reviewedClaimHasValidReferences("", references: [4], source: auditSource), "A kept claim must contain text")
        precondition(!LocalMeetingSummarizer.reviewedClaimHasValidReferences("Audit only this proposed follow-up. Cite original ENTRY numbers.", references: [4], source: auditSource), "Review instructions are not meeting notes")
        let promises = LocalMeetingSummarizer.explicitCommitmentCandidates(in: ["[00:01] Priya: I will email the revised floor plan to Morgan tomorrow.", "[00:02] Alex: I'll pause here.", "REVIEW NOTE: I will send invented instructions."])
        precondition(LocalMeetingSummarizer.speechForInference("[00:08:53] Speaker 1: I need total, not every user.") == "[00:08:53] I need total, not every user.")
        precondition(LocalMeetingSummarizer.speechForInference("[00:08:53] Morgan: I need total, not every user.") == "[00:08:53] Morgan: I need total, not every user.")
        precondition(promises.count == 1 && promises[0].entries == [1], "A literal late commitment must survive generative action-array omissions; post-meeting notes are not promises")
        let publication = LocalMeetingSummarizer.explicitCommitmentCandidates(in: ["[00:00:01] Jordan: I will publish the price list only after Lee approves."])
        precondition(publication.count == 1, "Publication promises must survive omission from a generated action array")
        precondition(LocalMeetingSummarizer.explicitCommitmentCandidates(in: ["[00:00:01] Sam: Once MFA is configured, we'll elevate the permissions."]).count == 1, "An unfamiliar action verb must not hide a literal promise")
        precondition(!LocalMeetingSummarizer.conditionalCommitmentSupportsOwner("Lee", entry: "[00:00:01] Lee: Once I approve the agreement, Jordan will publish the price list."), "A condition is not a separate commitment by its speaker")
        precondition(LocalMeetingSummarizer.conditionalCommitmentSupportsOwner("Jordan", entry: "[00:00:01] Lee: Once I approve the agreement, Jordan will publish the price list."))
        precondition(LocalMeetingSummarizer.conditionalCommitmentSupportsOwner("Sam", entry: "[00:00:01] Sam: I will create the account; only after MFA will I grant administrator access."))
        let orderedSpeech = ["[00:01] Speaker 1: We'll create a user for you.", "[00:02] Speaker 1: You'll set a password, and once MFA is configured, we'll grant administrator access."]
        precondition(LocalMeetingSummarizer.reviewRemainsInScope(focusedReferences: [1], reviewedReferences: [1, 2]), "Later corrections may augment the original request")
        precondition(!LocalMeetingSummarizer.reviewRemainsInScope(focusedReferences: [5, 6], reviewedReferences: [1, 3, 4, 8]), "An unrelated task cannot replace the focused exchange")
        precondition(!LocalMeetingSummarizer.reviewRemainsInScope(focusedReferences: [], reviewedReferences: [1]), "An unanchored follow-up must not pass review")
        let literalWorkflow = LocalMeetingSummarizer.quotedOrderedCommitment(references: [1, 2], entries: orderedSpeech)!
        precondition(literalWorkflow.contains("We'll create a user for you.") && literalWorkflow.contains("You'll set a password, and once MFA is configured, we'll grant administrator access."))
        precondition(!literalWorkflow.contains("Speaker 1:"), "Audio channels must not become task owners")
        precondition(LocalMeetingSummarizer.quotedOrderedCommitment(references: [1], entries: orderedSpeech) == nil, "Ordinary commitments must not manufacture an ordered workflow")
        let overCited = orderedSpeech + ["[00:05:00] Casey: I will update the equipment inventory tomorrow."]
        let scopedWorkflow = LocalMeetingSummarizer.quotedOrderedCommitment(references: [1, 2, 3], entries: overCited,
            topic: "Create the account and grant administrator access only after the recipient enables MFA", primary: 1)!
        precondition(!scopedWorkflow.contains("inventory") && scopedWorkflow.contains("MFA"),
                     "Overinclusive citations must not drag an unrelated promise into a workflow quote")
        let linkedDeliverables = ["[00:00:01] Jordan: I will send the agreement to Lee after the call.",
                                  "[00:00:02] Jordan: I will publish the new price list only after Lee approves the agreement."]
        let roleTask = try LocalMeetingSummarizer.taskWithRoles("Send the agreement after the call.", owner: "Jordan", recipient: "Lee", references: [1], entries: linkedDeliverables)
        precondition(roleTask.contains("Owner: Jordan.") && roleTask.contains("Recipient: Lee."), "Explicit role fields must survive a concise task description")
        do {
            _ = try LocalMeetingSummarizer.taskWithRoles("Send the agreement.", owner: "Jo", recipient: "Lee", references: [1], entries: linkedDeliverables)
            preconditionFailure("A name substring is not evidence for a different person")
        } catch {}
        do {
            _ = try LocalMeetingSummarizer.taskWithRoles("Send the agreement.", owner: "Speaker 1", recipient: "", references: [1], entries: ["[00:01] Speaker 1: I will send the agreement."])
            preconditionFailure("Audio channels cannot become owners")
        } catch {}
        precondition(LocalMeetingSummarizer.quotedOrderedCommitment(references: [1, 2], entries: linkedDeliverables,
            topic: linkedDeliverables[0]) == nil, "Sharing a document noun must not replace its delivery with a separate approval-dependent publication")
        precondition(LocalMeetingSummarizer.displayText("Inventory (ENTRY 1‑2) and scope (ENTRY 11).", references: [1, 2, 11]) == "Inventory and scope.")
        precondition(LocalMeetingSummarizer.displayText("Cost is 45; citation (ENTRY 1-3).", references: [1, 3]).contains("45"), "Spoken numbers are not citation metadata")
        let correctionEntries = ["[00:00:01] Alex: We think the storage contract includes offsite storage."] +
            (1...30).map { "[00:01:00] Sam: Unrelated printer discussion \($0)." } +
            ["[00:30:00] Morgan: Correction: the storage contract excludes offsite storage."]
        let review = LocalMeetingSummarizer.reviewSource(text: "The storage contract includes offsite storage", references: [1], quotes: [], entries: correctionEntries)
        precondition(review.contains("ENTRY 1:") && review.contains("ENTRY 32:") && review.contains("excludes offsite"),
                     "A later correction outside the original section must reach semantic review")
        let interleaved = ["[00:00:01] Sam: Please share the equipment spreadsheet."] +
            (1...15).map { "[00:00:10] Alex: Brief interleaved response \($0)." } +
            ["[00:01:00] Morgan: I will update the list and email it in the next few days."]
        let context = LocalMeetingSummarizer.reviewSource(text: "Share the equipment spreadsheet", references: [1], quotes: [], entries: interleaved)
        precondition(context.contains("ENTRY 17:") && context.contains("next few days"), "Interleaved responses must not hide the commitment after a request")
        let cited = LocalMeetingSummarizer.Notes(overview: "The prototype will be sent.",
            points: [.init(text: "A prototype will be sent.", quotes: [], entries: [2])],
            actions: [.init(task: "Send the prototype tomorrow.", quotes: [], entries: [2])], openQuestions: [])
        let citedResult = try LocalMeetingSummarizer.render(cited, transcript: meeting, model: "test")
        precondition(citedResult.warnings.isEmpty && citedResult.markdown.contains("Send the prototype tomorrow."),
                     "Source references preserve valid actions without model-copied quotes")
        precondition(LocalMeetingSummarizer.displayText("Send the prototype tomorrow. (ENTRY 2)", references: [2]) == "Send the prototype tomorrow.")
        precondition(LocalMeetingSummarizer.displayText("Send 45 files. (ENTRY 2)", references: [2]).contains("45"),
                     "Removing source metadata must not remove an unsupported spoken quantity")
        let checkedActions = [LocalMeetingSummarizer.Action(task: "Morgan will email Priya the overall box volume", quotes: [], entries: [7, 8]),
                              .init(task: "Priya will send Morgan the revised floor plan tomorrow", quotes: [], entries: [12])]
        let retained = LocalMeetingSummarizer.retainingAuditedActions([checkedActions[0]], audited: checkedActions)
        precondition(retained.count == 2 && retained[1].task.contains("floor plan"),
                     "A final formatting pass must not drop a verified late deliverable")
        let invented = LocalMeetingSummarizer.Action(task: "Purchase backup equipment", quotes: [], entries: [99])
        precondition(LocalMeetingSummarizer.retainingAuditedActions([invented], audited: checkedActions).count == 2,
                     "Formatting must not introduce a task that never passed semantic review")
        let relatedTasks = [LocalMeetingSummarizer.Action(task: "Review the backup platform license", quotes: [], entries: [8]),
                            .init(task: "Purchase the backup platform license", quotes: [], entries: [8])]
        precondition(LocalMeetingSummarizer.retainingAuditedActions([], audited: relatedTasks).count == 2,
                     "Shared topic words and evidence must not merge different operations")
        let duplicateDelivery = [
            LocalMeetingSummarizer.Action(task: "Sam will email Casey the backup service name and approximate price after the call.", quotes: [], entries: [4, 5]),
            LocalMeetingSummarizer.Action(task: "Sam will email Casey the backup service name and approximate price after the call. No purchase is approved.", quotes: [], entries: [4, 5])
        ]
        precondition(LocalMeetingSummarizer.retainingAuditedActions([], audited: duplicateDelivery).count == 1,
                     "A negated purchase mention must not duplicate one delivery task")
        let sectionEntries = (1...100).map { "[00:01:00] Sam: Entry \($0) " + String(repeating: "retained speech ", count: 8) }
        let sections = try LocalMeetingSummarizer.sourceParts(sectionEntries.joined(separator: "\n\n"), maximumBytes: 1_000)
        precondition(sections.count > 1 && sections.allSatisfy { $0.utf8.count <= 1_000 })
        precondition(sectionEntries.allSatisfy { entry in sections.contains { $0.components(separatedBy: "\n\n").contains(entry) } },
                     "Sectioning must preserve every source entry, including the last")
        precondition(sections.last?.hasSuffix(sectionEntries.last!) == true)
        print("PASS: evidence resolves actual clauses across fragments; unrelated quotes and unsupported dates/numbers rejected")
        print("PASS: sectioning preserves the entire source; multi-passage evidence rejects unsupported quotes")
    }
}
