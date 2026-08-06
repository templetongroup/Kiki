import FluidAudio
import Foundation

final class ParakeetTranscriber {
    private let manager: AsrManager

    private init(manager: AsrManager) {
        self.manager = manager
    }

    static func load(model: TranscriptionModelID) async throws -> ParakeetTranscriber {
        let version: AsrModelVersion = model == .parakeetMultilingual ? .v3 : .v2
        let models = try await AsrModels.downloadAndLoad(version: version)
        return ParakeetTranscriber(manager: AsrManager(models: models))
    }

    func transcribe(_ samples: [Float]) async -> String {
        do {
            var decoderState = TdtDecoderState.make()
            let result = try await manager.transcribe(samples, decoderState: &decoderState)
            return WhisperTranscriber.cleaned(result.text)
        } catch {
            return ""
        }
    }
}
