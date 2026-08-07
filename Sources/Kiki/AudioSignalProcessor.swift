import Foundation

enum AudioSignalProcessor {
    static func prepareForFinalTranscription(_ samples: [Float]) -> [Float] {
        guard Settings.speechProfile == .softSpeech,
              let peak = samples.lazy.map({ abs($0) }).max(),
              peak > 0.001,
              peak < 0.35
        else { return samples }
        let gain = min(4, 0.72 / peak)
        return samples.map { min(1, max(-1, $0 * gain)) }
    }
}

