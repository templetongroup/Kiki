import Foundation

struct PrivateSessionPolicy: Equatable {
    let historyEnabled: Bool

    static func resolved(privateSessionActive: Bool, privateContext: Bool) -> PrivateSessionPolicy {
        PrivateSessionPolicy(historyEnabled: !privateSessionActive && !privateContext)
    }
}

@MainActor
final class PrivateSessionController {
    static let shared = PrivateSessionController()
    private(set) var isActive = false

    private init() {}

    func toggle() { isActive.toggle() }
}
