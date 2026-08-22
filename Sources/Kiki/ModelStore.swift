import Foundation

enum ModelStore {
    /// Preference order when multiple models are installed.
    static let preferredOrder = [
        "ggml-large-v3-turbo.bin",
        "ggml-large-v3-turbo-q5_0.bin",
        "ggml-medium.en.bin",
        "ggml-small.en.bin",
        "ggml-small.bin",
        "ggml-base.en.bin",
        "ggml-base.bin",
        "ggml-tiny.en.bin",
    ]

    static var modelsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        return base.appendingPathComponent("Kiki/models", isDirectory: true)
    }

    static func ensureDirectory() {
        try? FileManager.default.createDirectory(at: modelsDirectory,
                                                 withIntermediateDirectories: true)
    }

    static func installedModels() -> [String] {
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: modelsDirectory.path)) ?? []
        return entries.filter { $0.hasPrefix("ggml-") && $0.hasSuffix(".bin") }.sorted()
    }

    static func activeModelURL() -> URL? {
        ensureDirectory()
        let installed = installedModels()
        guard !installed.isEmpty else { return nil }

        if let override = Settings.modelOverride, installed.contains(override) {
            return modelsDirectory.appendingPathComponent(override)
        }
        for name in preferredOrder where installed.contains(name) {
            return modelsDirectory.appendingPathComponent(name)
        }
        return modelsDirectory.appendingPathComponent(installed[0])
    }

    static func modelURL(for model: TranscriptionModelID) -> URL? {
        guard let fileName = model.whisperFileName,
              installedModels().contains(fileName) else { return nil }
        return modelsDirectory.appendingPathComponent(fileName)
    }

    static func isWhisperModelInstalled(_ model: TranscriptionModelID) -> Bool {
        guard let fileName = model.whisperFileName,
              let expectedSize = model.downloadSize else { return false }
        return ModelFileIntegrity.matchesExpectedSize(
            modelsDirectory.appendingPathComponent(fileName),
            expectedSize: expectedSize
        )
    }
}
