import Foundation

@MainActor
final class PrivateZoneStore {
    static let shared = PrivateZoneStore()
    static let didChangeNotification = Notification.Name("KikiPrivateZonesDidChange")

    private(set) var bundleIdentifiers: [String]

    private init() {
        bundleIdentifiers = UserDefaults.standard.stringArray(forKey: "privateBundleIdentifiers") ?? []
    }

    func contains(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return bundleIdentifiers.contains { $0.caseInsensitiveCompare(bundleIdentifier) == .orderedSame }
    }

    func add(_ bundleIdentifier: String) {
        let value = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !contains(bundleIdentifier: value) else { return }
        bundleIdentifiers.append(value)
        bundleIdentifiers.sort(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })
        save()
    }

    func remove(_ bundleIdentifier: String) {
        bundleIdentifiers.removeAll { $0.caseInsensitiveCompare(bundleIdentifier) == .orderedSame }
        save()
    }

    private func save() {
        UserDefaults.standard.set(bundleIdentifiers, forKey: "privateBundleIdentifiers")
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }
}

