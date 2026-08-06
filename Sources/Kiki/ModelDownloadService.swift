import Foundation

enum ModelDownloadService {
    static func downloadWhisperModel(_ model: TranscriptionModelID) async throws {
        guard let fileName = model.whisperFileName, let url = model.downloadURL else {
            throw KikiError("This is not a downloadable Whisper model.")
        }
        ModelStore.ensureDirectory()
        let destination = ModelStore.modelsDirectory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: destination.path) { return }

        let (temporaryURL, response) = try await URLSession.shared.download(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw KikiError("The model download failed.")
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
    }
}
