import AVFoundation

/// Captures microphone audio and accumulates it as 16 kHz mono Float32,
/// the input format Whisper expects.
final class AudioRecorder {
    static let sampleRate: Double = 16000
    static let tapBufferSize: AVAudioFrameCount = 1024

    static func captureInterval(inputSampleRate: Double) -> TimeInterval {
        Double(tapBufferSize) / inputSampleRate
    }

    private var engine: AVAudioEngine?
    private var converter: AVAudioConverter?
    private var samples: [Float] = []
    private var samplesHandler: (([Float]) -> Void)?
    private let lock = NSLock()

    /// Receives newly captured 16 kHz mono samples. The handler runs off the
    /// main thread and should return quickly.
    func setSamplesHandler(_ handler: (([Float]) -> Void)?) {
        lock.lock()
        samplesHandler = handler
        lock.unlock()
    }

    func start() throws {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let inFormat = input.outputFormat(forBus: 0)
        guard inFormat.sampleRate > 0, inFormat.channelCount > 0 else {
            throw KikiError("No audio input device available.")
        }
        guard let outFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                            sampleRate: Self.sampleRate,
                                            channels: 1,
                                            interleaved: false),
              let converter = AVAudioConverter(from: inFormat, to: outFormat) else {
            throw KikiError("Could not prepare audio conversion from \(inFormat).")
        }

        lock.lock()
        samples.removeAll(keepingCapacity: true)
        lock.unlock()

        self.converter = converter
        input.installTap(onBus: 0, bufferSize: Self.tapBufferSize, format: inFormat) { [weak self] buffer, _ in
            self?.consume(buffer, outFormat: outFormat)
        }
        engine.prepare()
        try engine.start()
        self.engine = engine
    }

    /// Stops capture and returns everything recorded since start().
    func stop() -> [Float] {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        converter = nil
        lock.lock()
        defer { lock.unlock() }
        return samples
    }

    private func consume(_ buffer: AVAudioPCMBuffer, outFormat: AVAudioFormat) {
        guard let converter else { return }
        let ratio = Self.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let out = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: capacity) else { return }

        var fed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if fed {
                status.pointee = .noDataNow
                return nil
            }
            fed = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, out.frameLength > 0, let channel = out.floatChannelData else { return }

        let chunk = Array(UnsafeBufferPointer(start: channel[0], count: Int(out.frameLength)))
        lock.lock()
        samples.append(contentsOf: chunk)
        let handler = samplesHandler
        lock.unlock()
        handler?(chunk)
    }
}

/// Loads an audio file as 16 kHz mono Float32 (used by --transcribe-file).
enum AudioFileLoader {
    static func load16kMono(url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let inFormat = file.processingFormat
        guard let outFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                            sampleRate: AudioRecorder.sampleRate,
                                            channels: 1,
                                            interleaved: false),
              let converter = AVAudioConverter(from: inFormat, to: outFormat),
              let inBuf = AVAudioPCMBuffer(pcmFormat: inFormat, frameCapacity: 8192) else {
            throw KikiError("Could not prepare conversion for \(url.lastPathComponent).")
        }

        var result: [Float] = []
        var reachedEnd = false
        while true {
            guard let outBuf = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: 8192) else { break }
            var convError: NSError?
            let status = converter.convert(to: outBuf, error: &convError) { _, inputStatus in
                if reachedEnd {
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                inBuf.frameLength = 0
                do {
                    try file.read(into: inBuf)
                } catch {
                    reachedEnd = true
                }
                if inBuf.frameLength == 0 {
                    reachedEnd = true
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                inputStatus.pointee = .haveData
                return inBuf
            }
            if let convError { throw convError }
            if outBuf.frameLength > 0, let channel = outBuf.floatChannelData {
                result.append(contentsOf: UnsafeBufferPointer(start: channel[0],
                                                              count: Int(outBuf.frameLength)))
            }
            if status == .endOfStream || (reachedEnd && outBuf.frameLength == 0) { break }
        }
        return result
    }
}
