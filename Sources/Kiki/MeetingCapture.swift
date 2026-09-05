import AVFoundation
import CoreMedia
import CoreGraphics
import Foundation
import ScreenCaptureKit

enum MeetingCaptureStartError: LocalizedError {
    case systemAudioPermissionRequired
    case systemAudioUnavailable(String)
    case microphoneUnavailable(String)

    var requiresScreenRecordingSettings: Bool {
        switch self {
        case .systemAudioPermissionRequired, .systemAudioUnavailable: true
        case .microphoneUnavailable: false
        }
    }

    var errorDescription: String? {
        switch self {
        case .systemAudioPermissionRequired:
            "Kiki needs Screen & System Audio Recording access to capture other people in Zoom, Google Meet, and similar apps."
        case .systemAudioUnavailable(let detail):
            "Kiki could not start system-audio capture. \(detail)"
        case .microphoneUnavailable(let detail):
            "Kiki could not start microphone capture. \(detail)"
        }
    }
}

struct MeetingAudioCapture: Sendable {
    let microphoneSamples: [Float]
    let systemSamples: [Float]
    let duration: TimeInterval
    let systemAudioAvailable: Bool
}

enum MeetingAutoExportResult {
    case disabled
    case saved(fileName: String)
    case failed(String)
}

/// Writes a finished meeting's Markdown transcript straight to a
/// user-chosen folder, so a meeting can be captured without an explicit
/// Export click each time. Opt-in via Settings.meetingAutoExportEnabled;
/// the folder is a plain path (Kiki is not sandboxed, so no security-scoped
/// bookmark is required to keep write access across launches).
enum MeetingTranscriptAutoExporter {
    static func export(_ transcript: MeetingTranscript) -> MeetingAutoExportResult {
        guard Settings.meetingAutoExportEnabled else { return .disabled }
        guard let path = Settings.meetingAutoExportFolderPath, !path.isEmpty else {
            return .failed("no export folder is selected")
        }
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let safeTitle = kikiSafeFileComponent(transcript.title, fallback: "Meeting")
        let url = folder.appendingPathComponent("\(formatter.string(from: transcript.createdAt))-\(safeTitle).md")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try transcript.markdown.write(to: url, atomically: true, encoding: .utf8)
            return .saved(fileName: url.lastPathComponent)
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}

enum MeetingAudioArchiver {
    static func save(_ capture: MeetingAudioCapture, title: String) throws -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Kiki/Meetings", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let safeTitle = kikiSafeFileComponent(title, fallback: "Meeting")
        let folder = root.appendingPathComponent("\(formatter.string(from: Date()))-\(safeTitle)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try writeWAV(capture.microphoneSamples, to: folder.appendingPathComponent("microphone.wav"))
        if !capture.systemSamples.isEmpty {
            try writeWAV(capture.systemSamples, to: folder.appendingPathComponent("system-audio.wav"))
        }
        return folder
    }

    private static func writeWAV(_ samples: [Float], to url: URL) throws {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: AudioRecorder.sampleRate,
            channels: 1,
            interleaved: false
        ),
        let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(samples.count)
        ),
        let channel = buffer.floatChannelData?[0]
        else { throw KikiError("Could not create an audio archive.") }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        channel.update(from: samples, count: samples.count)
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }
}

@MainActor
final class MeetingCaptureSession {
    private let microphone = AudioRecorder()
    private let systemAudio = SystemAudioRecorder()
    private var startedAt: Date?

    func setMicrophoneSamplesHandler(_ handler: (([Float]) -> Void)?) {
        microphone.setSamplesHandler(handler)
    }

    func start() async throws {
        guard startedAt == nil else { throw KikiError("A meeting capture is already running.") }

        if !CGPreflightScreenCaptureAccess() {
            guard CGRequestScreenCaptureAccess() else {
                throw MeetingCaptureStartError.systemAudioPermissionRequired
            }
        }

        do {
            try await systemAudio.start()
        } catch {
            throw MeetingCaptureStartError.systemAudioUnavailable(error.localizedDescription)
        }
        do {
            try microphone.start()
        } catch {
            _ = await systemAudio.stop()
            throw MeetingCaptureStartError.microphoneUnavailable(error.localizedDescription)
        }
        startedAt = Date()
    }

    func stop() async -> MeetingAudioCapture {
        microphone.setSamplesHandler(nil)
        let microphoneSamples = microphone.stop()
        let systemSamples = await systemAudio.stop()
        let duration = Date().timeIntervalSince(startedAt ?? Date())
        startedAt = nil
        return MeetingAudioCapture(
            microphoneSamples: microphoneSamples,
            systemSamples: systemSamples,
            duration: duration,
            systemAudioAvailable: !systemSamples.isEmpty
        )
    }
}

private final class SystemAudioRecorder: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private let sampleQueue = DispatchQueue(label: "kiki.meeting-system-audio", qos: .userInitiated)
    private let lock = NSLock()
    private var samples: [Float] = []
    private var stream: SCStream?

    func start() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        guard let display = content.displays.first else {
            throw KikiError("No display is available for system-audio capture.")
        }
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = 2
        configuration.height = 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 2)
        configuration.showsCursor = false
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true
        configuration.sampleRate = Int(AudioRecorder.sampleRate)
        configuration.channelCount = 1

        resetSamples()

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: sampleQueue)
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() async -> [Float] {
        if let stream {
            try? await stream.stopCapture()
            try? stream.removeStreamOutput(self, type: .audio)
        }
        stream = nil
        return capturedSamples()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio,
              sampleBuffer.isValid,
              let description = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee,
              asbd.mFormatID == kAudioFormatLinearPCM
        else { return }

        var requiredSize = 0
        var retainedBlock: CMBlockBuffer?
        _ = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &requiredSize,
            bufferListOut: nil,
            bufferListSize: 0,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: UInt32(kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment),
            blockBufferOut: &retainedBlock
        )
        guard requiredSize > 0 else { return }
        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: requiredSize,
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { raw.deallocate() }
        let list = raw.bindMemory(to: AudioBufferList.self, capacity: 1)
        guard CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: list,
            bufferListSize: requiredSize,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: UInt32(kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment),
            blockBufferOut: &retainedBlock
        ) == noErr else { return }

        let buffers = UnsafeMutableAudioBufferListPointer(list)
        var captured: [Float] = []
        for buffer in buffers {
            guard let data = buffer.mData, buffer.mDataByteSize > 0 else { continue }
            if asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0,
               asbd.mBitsPerChannel == 32 {
                let count = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
                captured.append(contentsOf: UnsafeBufferPointer(
                    start: data.assumingMemoryBound(to: Float.self),
                    count: count
                ))
            } else if asbd.mBitsPerChannel == 16 {
                let count = Int(buffer.mDataByteSize) / MemoryLayout<Int16>.size
                let input = UnsafeBufferPointer(
                    start: data.assumingMemoryBound(to: Int16.self),
                    count: count
                )
                captured.append(contentsOf: input.map { Float($0) / Float(Int16.max) })
            }
        }
        guard !captured.isEmpty else { return }
        lock.lock()
        samples.append(contentsOf: captured)
        lock.unlock()
    }

    func stream(_ stream: SCStream, didStopWithError error: any Error) {}

    private func resetSamples() {
        lock.lock()
        samples.removeAll(keepingCapacity: true)
        lock.unlock()
    }

    private func capturedSamples() -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        return samples
    }
}
