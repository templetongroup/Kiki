import Foundation

enum ModelPreparationStatus: Equatable, Sendable {
    case unavailable(model: TranscriptionModelID)
    case downloading(model: TranscriptionModelID, fraction: Double)
    case loading(model: TranscriptionModelID)
    case ready(model: TranscriptionModelID)
    case failed(model: TranscriptionModelID, message: String)

    var model: TranscriptionModelID {
        switch self {
        case let .unavailable(model),
             let .downloading(model, _),
             let .loading(model),
             let .ready(model),
             let .failed(model, _):
            model
        }
    }

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }

    var downloadFraction: Double? {
        guard case let .downloading(_, fraction) = self else { return nil }
        return min(1, max(0, fraction))
    }

    var compactTitle: String {
        switch self {
        case let .unavailable(model):
            "\(model.displayName) is unavailable"
        case let .downloading(model, fraction):
            "Downloading \(model.displayName) · \(Self.percent(fraction))%"
        case let .loading(model):
            "Loading \(model.displayName)…"
        case let .ready(model):
            "\(model.displayName) is ready"
        case let .failed(model, _):
            "Could not prepare \(model.displayName)"
        }
    }

    var checkupDetail: String {
        switch self {
        case .unavailable:
            "Unavailable"
        case let .downloading(_, fraction):
            "Downloading · \(Self.percent(fraction))%"
        case .loading:
            "Loading into memory"
        case .ready:
            "Ready and local"
        case .failed:
            "Setup failed"
        }
    }

    var modelsDetail: String {
        switch self {
        case .unavailable:
            "Unavailable on this Mac"
        case let .downloading(_, fraction):
            "Downloading · \(Self.percent(fraction))%"
        case .loading:
            "Loading into memory…"
        case .ready:
            "Ready and local"
        case let .failed(_, message):
            "Could not prepare model: \(message)"
        }
    }

    private static func percent(_ fraction: Double) -> Int {
        min(100, max(0, Int((fraction * 100).rounded(.down))))
    }
}
