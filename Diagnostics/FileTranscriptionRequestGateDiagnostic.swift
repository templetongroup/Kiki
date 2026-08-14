import Foundation

@main
enum FileTranscriptionRequestGateDiagnostic {
    static func main() {
        var gate = FileTranscriptionRequestGate()
        guard let first = gate.begin() else { fail("first request was rejected") }
        guard gate.begin() == nil else { fail("overlapping request was accepted") }
        guard gate.requestCancellation(for: first), gate.isCancelling else {
            fail("active request did not enter cancelling state")
        }
        guard gate.complete(first) == .cancelled, !gate.isActive else {
            fail("cancelled completion was accepted or left the gate busy")
        }
        guard let second = gate.begin() else { fail("retry was rejected after cancellation") }
        guard gate.complete(first) == .stale else { fail("stale completion was accepted") }
        guard gate.complete(second) == .accepted, !gate.isActive else {
            fail("current completion was not accepted")
        }
        print("File transcription request gate diagnostic passed")
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        exit(1)
    }
}
