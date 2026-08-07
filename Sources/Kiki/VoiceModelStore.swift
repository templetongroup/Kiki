import Foundation

struct VoiceModelDownloadProgress: Sendable {
    let completedBytes: Int64
    let totalBytes: Int64
    let currentFile: String

    var fraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, max(0, Double(completedBytes) / Double(totalBytes)))
    }
}

enum VoiceModelStore {
    static let displayName = "Kiki Local Voice · Qwen3-TTS 0.6B"
    static let downloadSize: Int64 = 1_991_296_593
    static let modelRepository = "mlx-community/Qwen3-TTS-12Hz-0.6B-Base-8bit"
    private static let revision = "50f45ef0047cde7e84c2ef04326acb8ada2436a7"

    private struct ModelFile: Sendable {
        let path: String
        let size: Int64
    }

    private static let files: [ModelFile] = [
        .init(path: "config.json", size: 5_522),
        .init(path: "generation_config.json", size: 245),
        .init(path: "merges.txt", size: 1_671_839),
        .init(path: "model.safetensors", size: 1_304_461_214),
        .init(path: "model.safetensors.index.json", size: 77_731),
        .init(path: "preprocessor_config.json", size: 127),
        .init(path: "speech_tokenizer/config.json", size: 2_336),
        .init(path: "speech_tokenizer/configuration.json", size: 76),
        .init(path: "speech_tokenizer/model.safetensors", size: 682_293_092),
        .init(path: "speech_tokenizer/preprocessor_config.json", size: 234),
        .init(path: "tokenizer_config.json", size: 7_344),
        .init(path: "vocab.json", size: 2_776_833),
    ]

    static var manifestSize: Int64 { files.reduce(0) { $0 + $1.size } }

    static var directory: URL {
        if let override = ProcessInfo.processInfo.environment["KIKI_VOICE_MODEL_ROOT"],
           !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Kiki/voice-models/qwen3-tts-0.6b-base-8bit", isDirectory: true)
    }

    static var isInstalled: Bool {
        files.allSatisfy { file in
            let url = directory.appendingPathComponent(file.path)
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
                  let size = values.fileSize else { return false }
            return Int64(size) == file.size
        }
    }

    static var installedSize: Int64 {
        files.reduce(into: Int64(0)) { total, file in
            let url = directory.appendingPathComponent(file.path)
            total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }

    static func download(
        progress: @MainActor @escaping (VoiceModelDownloadProgress) -> Void
    ) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var completed: Int64 = 0

        for file in files {
            try Task.checkCancellation()
            let destination = directory.appendingPathComponent(file.path)
            let existingSize = Int64((try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            if existingSize == file.size {
                completed += file.size
                await progress(.init(completedBytes: completed, totalBytes: downloadSize, currentFile: file.path))
                continue
            }

            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? FileManager.default.removeItem(at: destination)

            guard let encodedPath = file.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: "https://huggingface.co/\(modelRepository)/resolve/\(revision)/\(encodedPath)?download=true")
            else { throw KikiError("Kiki could not prepare the voice-model download.") }

            let downloader = VoiceModelFileDownloader()
            let base = completed
            try await withTaskCancellationHandler {
                try await downloader.download(from: url, to: destination) { written, expected in
                    let fileTotal = expected > 0 ? min(expected, file.size) : file.size
                    let bounded = min(fileTotal, max(0, written))
                    Task { @MainActor in
                        progress(.init(
                            completedBytes: base + bounded,
                            totalBytes: downloadSize,
                            currentFile: file.path
                        ))
                    }
                }
            } onCancel: {
                downloader.cancel()
            }
            let downloadedSize = Int64((try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            guard downloadedSize == file.size else {
                try? FileManager.default.removeItem(at: destination)
                throw KikiError("The local voice model download was incomplete. Please try again.")
            }
            completed += file.size
        }

        guard isInstalled else { throw KikiError("The local voice model is incomplete.") }
        await progress(.init(completedBytes: downloadSize, totalBytes: downloadSize, currentFile: "Complete"))
    }

    static func delete() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }
}

private final class VoiceModelFileDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var progressHandler: ((Int64, Int64) -> Void)?
    private var downloadTask: URLSessionDownloadTask?
    private var destination: URL?
    private var moveError: Error?
    private var session: URLSession?

    func download(
        from url: URL,
        to destination: URL,
        progress: @escaping (Int64, Int64) -> Void
    ) async throws {
        self.destination = destination
        self.progressHandler = progress
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 60 * 60
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        self.session = session
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            self.continuation = continuation
            let task = session.downloadTask(with: url)
            self.downloadTask = task
            lock.unlock()
            task.resume()
        }
    }

    func cancel() {
        lock.lock()
        let task = downloadTask
        lock.unlock()
        task?.cancel()
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        progressHandler?(totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let destination else {
            moveError = KikiError("The voice-model download lost its destination.")
            return
        }
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            moveError = error
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        self.downloadTask = nil
        lock.unlock()

        if let error {
            continuation?.resume(throwing: error)
        } else if let moveError {
            continuation?.resume(throwing: moveError)
        } else if let response = task.response as? HTTPURLResponse,
                  !(200..<300).contains(response.statusCode) {
            continuation?.resume(throwing: KikiError("Voice-model download failed with HTTP \(response.statusCode)."))
        } else {
            continuation?.resume()
        }
        session.finishTasksAndInvalidate()
        self.session = nil
    }
}
