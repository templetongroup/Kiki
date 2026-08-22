import Foundation

enum FileTranscriptionCompletion: Equatable {
    case accepted
    case cancelled
    case stale
}

struct FileTranscriptionRequestGate {
    private var activeRequestID: UUID?
    private var cancellationRequested = false

    var isActive: Bool { activeRequestID != nil }
    var isCancelling: Bool { isActive && cancellationRequested }

    mutating func begin() -> UUID? {
        guard activeRequestID == nil else { return nil }
        let requestID = UUID()
        activeRequestID = requestID
        cancellationRequested = false
        return requestID
    }

    mutating func requestCancellation(for requestID: UUID) -> Bool {
        guard activeRequestID == requestID else { return false }
        cancellationRequested = true
        return true
    }

    mutating func complete(_ requestID: UUID) -> FileTranscriptionCompletion {
        guard activeRequestID == requestID else { return .stale }
        let result: FileTranscriptionCompletion = cancellationRequested ? .cancelled : .accepted
        activeRequestID = nil
        cancellationRequested = false
        return result
    }
}
