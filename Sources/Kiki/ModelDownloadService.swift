import Foundation

struct ModelDownloadProgress: Sendable {
    let completedBytes: Int64
    let totalBytes: Int64

    var fraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, max(0, Double(completedBytes) / Double(totalBytes)))
    }
}

enum ModelDownloadService {
    static func downloadWhisperModel(
        _ model: TranscriptionModelID,
        progress: @MainActor @escaping (ModelDownloadProgress) -> Void
    ) async throws {
        guard let fileName = model.whisperFileName, let url = model.downloadURL else {
            throw KikiError("This is not a downloadable Whisper model.")
        }
        ModelStore.ensureDirectory()
        let destination = ModelStore.modelsDirectory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: destination.path) { return }

        let downloader = TranscriptionModelFileDownloader()
        try await withTaskCancellationHandler {
            try await downloader.download(from: url, to: destination) { written, expected in
                Task { @MainActor in
                    progress(.init(completedBytes: written, totalBytes: expected))
                }
            }
        } onCancel: {
            downloader.cancel()
        }
    }
}

private final class TranscriptionModelFileDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var progressHandler: ((Int64, Int64) -> Void)?
    private var downloadTask: URLSessionDownloadTask?
    private var destination: URL?
    private var stagingDestination: URL?
    private var moveError: Error?
    private var session: URLSession?

    func download(
        from url: URL,
        to destination: URL,
        progress: @escaping (Int64, Int64) -> Void
    ) async throws {
        self.destination = destination
        stagingDestination = destination
            .deletingLastPathComponent()
            .appendingPathComponent(".\(UUID().uuidString).download")
        progressHandler = progress
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 60 * 60
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        self.session = session
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            self.continuation = continuation
            let task = session.downloadTask(with: url)
            downloadTask = task
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
        guard let stagingDestination else {
            moveError = KikiError("The model download lost its destination.")
            return
        }
        do {
            try FileManager.default.moveItem(at: location, to: stagingDestination)
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
        downloadTask = nil
        lock.unlock()

        let successfulResponse = (task.response as? HTTPURLResponse).map {
            (200..<300).contains($0.statusCode)
        } ?? false

        if let error {
            removeStagingDownload()
            continuation?.resume(throwing: error)
        } else if let moveError {
            removeStagingDownload()
            continuation?.resume(throwing: moveError)
        } else if !successfulResponse {
            removeStagingDownload()
            let status = (task.response as? HTTPURLResponse)?.statusCode
            let detail = status.map { " with HTTP \($0)" } ?? ""
            continuation?.resume(throwing: KikiError("Model download failed\(detail)."))
        } else {
            do {
                guard let destination, let stagingDestination else {
                    throw KikiError("The model download lost its destination.")
                }
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: stagingDestination)
                } else {
                    try FileManager.default.moveItem(at: stagingDestination, to: destination)
                }
                continuation?.resume()
            } catch {
                removeStagingDownload()
                continuation?.resume(throwing: error)
            }
        }
        session.finishTasksAndInvalidate()
        self.session = nil
    }

    private func removeStagingDownload() {
        guard let stagingDestination else { return }
        try? FileManager.default.removeItem(at: stagingDestination)
    }
}
