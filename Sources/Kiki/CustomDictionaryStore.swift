import Foundation

struct CustomDictionaryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    var spoken: String
    var replacement: String

    init(id: UUID = UUID(), spoken: String, replacement: String) {
        self.id = id
        self.spoken = spoken
        self.replacement = replacement
    }
}

@MainActor
final class CustomDictionaryStore {
    static let shared = CustomDictionaryStore()

    private(set) var entries: [CustomDictionaryEntry] = []
    private let storageURL: URL

    private static var defaultFileURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Kiki", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("dictionary.json")
    }

    init(fileURL: URL? = nil) {
        storageURL = fileURL ?? Self.defaultFileURL
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([CustomDictionaryEntry].self, from: data)
        else { return }
        entries = decoded
    }

    func add(spoken: String, replacement: String) {
        let spoken = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
        let replacement = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty, !replacement.isEmpty else { return }
        entries.removeAll { $0.spoken.caseInsensitiveCompare(spoken) == .orderedSame }
        entries.append(CustomDictionaryEntry(spoken: spoken, replacement: replacement))
        entries.sort { $0.spoken.localizedCaseInsensitiveCompare($1.spoken) == .orderedAscending }
        save()
    }

    func remove(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    func apply(to text: String) -> String {
        var result = text
        for entry in entries.sorted(by: { $0.spoken.count > $1.spoken.count }) {
            let escaped = NSRegularExpression.escapedPattern(for: entry.spoken)
            guard let regex = try? NSRegularExpression(
                pattern: "(?i)(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])"
            ) else { continue }
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                range: range,
                withTemplate: NSRegularExpression.escapedTemplate(for: entry.replacement)
            )
        }
        return result
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? FileManager.default.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: storageURL, options: .atomic)
    }
}
