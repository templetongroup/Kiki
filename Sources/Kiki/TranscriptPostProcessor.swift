import Foundation

enum SpeechProfile: String, CaseIterable {
    case standard
    case disfluencyAssist
    case verbatim
    case softSpeech

    var title: String {
        switch self {
        case .standard: "Standard"
        case .disfluencyAssist: "Disfluency Assist"
        case .verbatim: "Preserve Every Word"
        case .softSpeech: "Soft Speech"
        }
    }

    var detail: String {
        switch self {
        case .standard: "Fast, unchanged local transcription."
        case .disfluencyAssist: "Removes common fillers, repeated words, and phrases before “scratch that.”"
        case .verbatim: "Avoids speech cleanup while retaining your approved spelling rules."
        case .softSpeech: "Normalizes quiet microphone input before transcription."
        }
    }
}

@MainActor
enum TranscriptPostProcessor {
    static func process(_ rawText: String, context: AppContextSnapshot?) -> String {
        var text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return text }

        if Settings.speechProfile == .disfluencyAssist {
            text = DisfluencyProcessor.clean(text)
        }
        if let expansion = VoiceSnippetStore.shared.expansion(for: text) {
            return expansion
        }
        text = CustomDictionaryStore.shared.apply(to: text)
        text = CorrectionMemoryStore.shared.apply(
            to: text,
            bundleIdentifier: context?.bundleIdentifier
        )
        if !(context?.isPrivate ?? false) {
            text = ContextVocabularyStore.shared.apply(
                to: text,
                bundleIdentifier: context?.bundleIdentifier
            )
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private enum DisfluencyProcessor {
    static func clean(_ input: String) -> String {
        var text = input
        if let range = text.range(
            of: #"(?i)\b(?:scratch that|never mind|start over)\b"#,
            options: .regularExpression
        ) {
            text = String(text[range.upperBound...])
        }
        text = text.replacingOccurrences(
            of: #"(?i)(?<![\p{L}])(?:um+|uh+|erm|ah)(?![\p{L}])[,]?\s*"#,
            with: "",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"(?i)\b([\p{L}’'-]+)(?:\s+\1){1,3}\b"#,
            with: "$1",
            options: .regularExpression
        )
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
