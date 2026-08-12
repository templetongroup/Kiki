import Foundation

enum TranscriptionModelID: String, CaseIterable, Codable, Sendable {
    case parakeetEnglish
    case parakeetMultilingual
    case whisperLargeTurbo
    case whisperSmallEnglish
    case whisperBaseEnglish

    static var isAppleSilicon: Bool {
        #if arch(arm64)
        true
        #else
        false
        #endif
    }

    static var recommendedDefault: TranscriptionModelID {
        isAppleSilicon ? .parakeetEnglish : .whisperSmallEnglish
    }

    var displayName: String {
        switch self {
        case .parakeetEnglish: "Parakeet TDT v2 — English"
        case .parakeetMultilingual: "Parakeet TDT v3 — Multilingual"
        case .whisperLargeTurbo: "Whisper Large v3 Turbo"
        case .whisperSmallEnglish: "Whisper Small — English"
        case .whisperBaseEnglish: "Whisper Base — English"
        }
    }

    var detail: String {
        switch self {
        case .parakeetEnglish:
            "Best speed and accuracy for English on Apple Silicon. About 500 MB."
        case .parakeetMultilingual:
            "Fast local transcription across 25 European languages. About 500 MB."
        case .whisperLargeTurbo:
            "Highest Whisper accuracy, but slower and memory-heavy. About 1.5 GB."
        case .whisperSmallEnglish:
            "Balanced Whisper fallback for most Macs. About 465 MB."
        case .whisperBaseEnglish:
            "Fastest lightweight fallback for older hardware. About 142 MB."
        }
    }

    var isCompatible: Bool {
        switch self {
        case .parakeetEnglish, .parakeetMultilingual: Self.isAppleSilicon
        default: true
        }
    }

    var isParakeet: Bool {
        self == .parakeetEnglish || self == .parakeetMultilingual
    }

    var whisperFileName: String? {
        switch self {
        case .whisperLargeTurbo: "ggml-large-v3-turbo.bin"
        case .whisperSmallEnglish: "ggml-small.en.bin"
        case .whisperBaseEnglish: "ggml-base.en.bin"
        default: nil
        }
    }

    var downloadURL: URL? {
        guard let whisperFileName else { return nil }
        return URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(whisperFileName)")
    }
}
