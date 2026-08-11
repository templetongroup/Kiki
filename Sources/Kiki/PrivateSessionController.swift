import Foundation

struct PrivateSessionPolicy: Equatable {
    let historyEnabled: Bool
    let learningEnabled: Bool
    let confidenceVerificationEnabled: Bool
    let pawprintsEnabled: Bool

    static func resolved(privateSessionActive: Bool, privateContext: Bool) -> PrivateSessionPolicy {
        let allowsPersistence = !privateSessionActive && !privateContext
        return PrivateSessionPolicy(
            historyEnabled: allowsPersistence,
            learningEnabled: allowsPersistence,
            confidenceVerificationEnabled: allowsPersistence,
            pawprintsEnabled: allowsPersistence
        )
    }
}

@MainActor
final class PrivateSessionController {
    static let shared = PrivateSessionController()
    private(set) var isActive = false

    private init() {}

    func toggle() { isActive.toggle() }
}
