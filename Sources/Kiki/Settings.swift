import Foundation

struct KikiError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

enum Settings {
    /// Whisper language code ("en", "de", ...) or "auto" to detect per utterance.
    static var language: String {
        UserDefaults.standard.string(forKey: "language") ?? "en"
    }

    /// Optional model file name override, e.g. "ggml-small.en.bin".
    static var modelOverride: String? {
        UserDefaults.standard.string(forKey: "model")
    }
}
