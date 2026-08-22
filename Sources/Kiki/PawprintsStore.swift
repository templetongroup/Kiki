import Foundation

struct PawprintsSummary: Equatable {
    let dictations: Int
    let words: Int
    let speakingSeconds: TimeInterval
    let activeDays: Int

    static let empty = PawprintsSummary(dictations: 0, words: 0, speakingSeconds: 0, activeDays: 0)
}

@MainActor
final class PawprintsStore {
    static let shared = PawprintsStore()
    static let didChangeNotification = Notification.Name("KikiPawprintsDidChange")

    private struct DayAggregate: Codable {
        var dictations: Int
        var words: Int
        var speakingSeconds: TimeInterval
    }

    private var days: [String: DayAggregate] = [:]
    private let storageURL: URL
    private let isEnabled: () -> Bool

    init(fileURL: URL? = nil, isEnabled: @escaping () -> Bool = { Settings.pawprintsEnabled }) {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Kiki", isDirectory: true)
        storageURL = fileURL ?? directory.appendingPathComponent("pawprints.json")
        self.isEnabled = isEnabled
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([String: DayAggregate].self, from: data) else { return }
        days = decoded
    }

    var summary: PawprintsSummary {
        days.values.reduce(into: .empty) { result, day in
            result = PawprintsSummary(
                dictations: result.dictations + day.dictations,
                words: result.words + day.words,
                speakingSeconds: result.speakingSeconds + day.speakingSeconds,
                activeDays: result.activeDays + 1
            )
        }
    }

    @discardableResult
    func record(text: String, duration: TimeInterval, isPrivate: Bool, now: Date = Date()) -> Bool {
        guard isEnabled(), !isPrivate else { return false }
        let words = text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).count
        guard words > 0 else { return false }
        let key = Self.dayKey(for: now)
        let previous = days[key]
        var day = previous ?? DayAggregate(dictations: 0, words: 0, speakingSeconds: 0)
        day.dictations += 1
        day.words += words
        day.speakingSeconds += max(0, duration)
        days[key] = day
        guard save() else {
            days[key] = previous
            return false
        }
        return true
    }

    @discardableResult
    func reset() -> Bool {
        if FileManager.default.fileExists(atPath: storageURL.path) {
            do {
                try FileManager.default.removeItem(at: storageURL)
            } catch {
                return false
            }
        }
        days.removeAll()
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
        return true
    }

    private func save() -> Bool {
        do {
            let data = try JSONEncoder().encode(days)
            try FileManager.default.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: storageURL, options: .atomic)
            NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
            return true
        } catch {
            return false
        }
    }

    private static func dayKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
