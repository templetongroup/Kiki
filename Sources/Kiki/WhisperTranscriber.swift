import Foundation
import whisper

final class WhisperTranscriber {
    private let ctx: OpaquePointer
    private let languageC: UnsafeMutablePointer<CChar>?

    init(modelPath: String, language: String) throws {
        var cparams = whisper_context_default_params()
        cparams.use_gpu = true
        guard let ctx = whisper_init_from_file_with_params(modelPath, cparams) else {
            throw KikiError("Failed to load Whisper model: \(modelPath)")
        }
        self.ctx = ctx
        self.languageC = language == "auto" ? nil : strdup(language)
    }

    deinit {
        whisper_free(ctx)
        if let languageC { free(languageC) }
    }

    /// Transcribes 16 kHz mono Float32 samples. Blocking; call off the main thread.
    func transcribe(_ samples: [Float]) -> String {
        // Whisper needs at least ~1s of audio; pad short clips with silence.
        var padded = samples
        let minSamples = Int(1.2 * AudioRecorder.sampleRate)
        if padded.count < minSamples {
            padded.append(contentsOf: [Float](repeating: 0, count: minSamples - padded.count))
        }

        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_progress = false
        params.print_realtime = false
        params.print_special = false
        params.print_timestamps = false
        params.no_timestamps = true
        params.suppress_blank = true
        params.n_threads = Int32(max(2, ProcessInfo.processInfo.activeProcessorCount - 2))
        if let languageC {
            params.language = UnsafePointer(languageC)
        } else {
            params.language = nil // auto-detect
        }

        let status = padded.withUnsafeBufferPointer { buf in
            whisper_full(ctx, params, buf.baseAddress, Int32(buf.count))
        }
        guard status == 0 else { return "" }

        var text = ""
        for i in 0..<whisper_full_n_segments(ctx) {
            if let segment = whisper_full_get_segment_text(ctx, i) {
                text += String(cString: segment)
            }
        }
        return Self.cleaned(text)
    }

    /// Strips non-speech artifacts Whisper emits for silence/noise,
    /// e.g. "[BLANK_AUDIO]", "(wind blowing)", "♪".
    static func cleaned(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let artifact = #"^([\[\(][^\]\)]*[\]\)]|♪+|\*[^*]*\*)$"#
        if trimmed.range(of: artifact, options: .regularExpression) != nil {
            return ""
        }
        return trimmed
    }
}
