import Foundation

struct LearnedCorrection: Codable, Identifiable, Equatable {
    let id: UUID
    var heard: String
    var replacement: String
    var bundleIdentifier: String?
    var createdAt: Date
    var useCount: Int

    init(
        id: UUID = UUID(),
        heard: String,
        replacement: String,
        bundleIdentifier: String? = nil,
        createdAt: Date = Date(),
        useCount: Int = 0
    ) {
        self.id = id
        self.heard = heard
        self.replacement = replacement
        self.bundleIdentifier = bundleIdentifier
        self.createdAt = createdAt
        self.useCount = useCount
    }
}

struct CorrectionSuggestion: Codable, Identifiable, Equatable {
    let id: UUID
    let heard: String
    let replacement: String
    let bundleIdentifier: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        heard: String,
        replacement: String,
        bundleIdentifier: String?,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.heard = heard
        self.replacement = replacement
        self.bundleIdentifier = bundleIdentifier
        self.createdAt = createdAt
    }
}

@MainActor
final class CorrectionMemoryStore {
    static let shared = CorrectionMemoryStore()
    static let didChangeNotification = Notification.Name("KikiCorrectionMemoryDidChange")

    private(set) var corrections: [LearnedCorrection] = []
    private(set) var suggestions: [CorrectionSuggestion] = []
    private let storageURL: URL

    private struct Payload: Codable {
        var corrections: [LearnedCorrection]
        var suggestions: [CorrectionSuggestion]
    }

    private static var defaultFileURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Kiki", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("learning.json")
    }

    init(fileURL: URL? = nil) {
        storageURL = fileURL ?? Self.defaultFileURL
        guard let data = try? Data(contentsOf: storageURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return }
        corrections = payload.corrections
        suggestions = payload.suggestions
    }

    func apply(to text: String, bundleIdentifier: String?) -> String {
        var result = text
        let applicable = corrections.filter {
            $0.bundleIdentifier == nil || $0.bundleIdentifier == bundleIdentifier
        }
        for correction in applicable.sorted(by: { $0.heard.count > $1.heard.count }) {
            result = WholePhraseReplacer.replace(
                correction.heard,
                with: correction.replacement,
                in: result
            )
        }
        return result
    }

    func suggest(heard: String, replacement: String, bundleIdentifier: String?) {
        let heard = heard.trimmingCharacters(in: .whitespacesAndNewlines)
        let replacement = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard heard.count >= 2,
              replacement.count >= 2,
              heard.caseInsensitiveCompare(replacement) != .orderedSame,
              !suggestions.contains(where: {
                  $0.heard.caseInsensitiveCompare(heard) == .orderedSame &&
                  $0.replacement.caseInsensitiveCompare(replacement) == .orderedSame
              })
        else { return }
        suggestions.insert(
            CorrectionSuggestion(
                heard: heard,
                replacement: replacement,
                bundleIdentifier: bundleIdentifier
            ),
            at: 0
        )
        suggestions = Array(suggestions.prefix(100))
        save()
    }

    func approve(_ suggestion: CorrectionSuggestion, scopeToApp: Bool) {
        corrections.removeAll {
            $0.heard.caseInsensitiveCompare(suggestion.heard) == .orderedSame &&
            $0.bundleIdentifier == (scopeToApp ? suggestion.bundleIdentifier : nil)
        }
        corrections.append(
            LearnedCorrection(
                heard: suggestion.heard,
                replacement: suggestion.replacement,
                bundleIdentifier: scopeToApp ? suggestion.bundleIdentifier : nil
            )
        )
        suggestions.removeAll { $0.id == suggestion.id }
        save()
    }

    func reject(_ suggestion: CorrectionSuggestion) {
        suggestions.removeAll { $0.id == suggestion.id }
        save()
    }

    func removeCorrection(id: UUID) {
        corrections.removeAll { $0.id == id }
        save()
    }

    private func save() {
        let payload = Payload(corrections: corrections, suggestions: suggestions)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: storageURL, options: .atomic)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }
}

enum WholePhraseReplacer {
    static func replace(_ phrase: String, with replacement: String, in text: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: phrase)
        guard let regex = try? NSRegularExpression(
            pattern: "(?i)(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])"
        ) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(
            in: text,
            range: range,
            withTemplate: NSRegularExpression.escapedTemplate(for: replacement)
        )
    }
}

