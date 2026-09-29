import Foundation

// Test doubles for application settings/stores; the processor itself is the
// production implementation, including the original destructive dictation path.
@MainActor enum Settings { static var speechProfile: SpeechProfile = .standard }
struct AppContextSnapshot { let bundleIdentifier: String?; let isPrivate: Bool }
@MainActor final class VoiceSnippetStore {
    static let shared = VoiceSnippetStore()
    func expansion(for text: String) -> String? { text == "insert signature" ? "EXPANDED SNIPPET" : nil }
}
@MainActor final class CustomDictionaryStore {
    static let shared = CustomDictionaryStore()
    func apply(to text: String) -> String { text.replacingOccurrences(of: "Marin", with: "MARTIN") }
}
@MainActor final class CorrectionMemoryStore {
    static let shared = CorrectionMemoryStore()
    func apply(to text: String, bundleIdentifier: String?) -> String { text.replacingOccurrences(of: "draft", with: "FINAL") }
}
@MainActor final class ContextVocabularyStore {
    static let shared = ContextVocabularyStore()
    func apply(to text: String, bundleIdentifier: String?) -> String { text.replacingOccurrences(of: "review", with: "APPROVE") }
}

@main struct MeetingPostProcessingTests {
    @MainActor static func main() {
        let original = "The budget is not approved. Marin will review the draft. Scratch that, the review is tomorrow."
        for profile in SpeechProfile.allCases {
            Settings.speechProfile = profile
            precondition(TranscriptPostProcessor.processMeeting("  " + original + "\n") == original,
                         "Meeting speech must survive every dictation profile unchanged")
            precondition(TranscriptPostProcessor.processMeeting("insert signature") == "insert signature",
                         "A meeting participant must not trigger a dictation snippet")
        }
        Settings.speechProfile = .disfluencyAssist
        precondition(!TranscriptPostProcessor.process(original, context: nil).contains("budget"),
                     "The test must exercise the destructive original dictation path")
        precondition(TranscriptPostProcessor.process("insert signature", context: nil) == "EXPANDED SNIPPET",
                     "Ordinary dictation snippets must keep working")
        print("PASS: meeting speech retains negation, corrections and original wording under every profile; dictation behavior unchanged")
    }
}
