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

    var downloadSize: Int64? {
        switch self {
        case .whisperLargeTurbo: 1_624_555_275
        case .whisperSmallEnglish: 487_614_201
        case .whisperBaseEnglish: 147_964_211
        default: nil
        }
    }

    var downloadSHA256: String? {
        switch self {
        case .whisperLargeTurbo: "1fc70f774d38eb169993ac391eea357ef47c88757ef72ee5943879b7e8e2bc69"
        case .whisperSmallEnglish: "c6138d6d58ecc8322097e0f987c32f1be8bb0a18532a3f88f734d1bbf9c41e5d"
        case .whisperBaseEnglish: "a03779c86df3323075f5e796cb2ce5029f00ec8869eee3fdfb897afe36c6d002"
        default: nil
        }
    }
}
