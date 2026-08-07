import Contacts
import EventKit
import Foundation

enum ContextTermSource: String, Codable, CaseIterable {
    case contacts
    case calendar
    case project
    case manual

    var title: String {
        switch self {
        case .contacts: "Contacts"
        case .calendar: "Calendar"
        case .project: "Project"
        case .manual: "Manual"
        }
    }
}

struct ContextTerm: Codable, Identifiable, Equatable {
    let id: UUID
    var value: String
    var source: ContextTermSource
    var bundleIdentifier: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        value: String,
        source: ContextTermSource,
        bundleIdentifier: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.value = value
        self.source = source
        self.bundleIdentifier = bundleIdentifier
        self.createdAt = createdAt
    }
}

@MainActor
final class ContextVocabularyStore {
    static let shared = ContextVocabularyStore()
    static let didChangeNotification = Notification.Name("KikiContextVocabularyDidChange")

    private(set) var terms: [ContextTerm] = []
    private let storageURL: URL

    private static var defaultFileURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Kiki", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("context-vocabulary.json")
    }

    init(fileURL: URL? = nil) {
        storageURL = fileURL ?? Self.defaultFileURL
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([ContextTerm].self, from: data)
        else { return }
        terms = decoded
    }

    func add(
        values: [String],
        source: ContextTermSource,
        bundleIdentifier: String? = nil
    ) {
        for raw in values {
            let value = Self.clean(raw)
            guard Self.isUseful(value) else { continue }
            terms.removeAll {
                $0.value.caseInsensitiveCompare(value) == .orderedSame &&
                $0.bundleIdentifier == bundleIdentifier
            }
            terms.append(
                ContextTerm(value: value, source: source, bundleIdentifier: bundleIdentifier)
            )
        }
        terms.sort { $0.value.localizedCaseInsensitiveCompare($1.value) == .orderedAscending }
        save()
    }

    func remove(id: UUID) {
        terms.removeAll { $0.id == id }
        save()
    }

    func remove(source: ContextTermSource) {
        terms.removeAll { $0.source == source }
        save()
    }

    func apply(to text: String, bundleIdentifier: String?) -> String {
        guard Settings.useContextVocabulary else { return text }
        let values = terms.filter {
            $0.bundleIdentifier == nil || $0.bundleIdentifier == bundleIdentifier
        }.map(\.value)
        return ApproximateTermReplacer.apply(terms: values, to: text)
    }

    private static func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private static func isUseful(_ value: String) -> Bool {
        guard value.count >= 4, value.count <= 80 else { return false }
        return value.rangeOfCharacter(from: .letters) != nil
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(terms) else { return }
        try? data.write(to: storageURL, options: .atomic)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }
}

enum ContextVocabularyImporter {
    @MainActor
    static func importContacts() async throws -> Int {
        let store = CNContactStore()
        let granted: Bool
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized, .limited:
            granted = true
        case .notDetermined:
            granted = try await store.requestAccess(for: .contacts)
        default:
            granted = false
        }
        guard granted else { throw KikiError("Contacts access was not granted.") }

        let request = CNContactFetchRequest(keysToFetch: [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
        ])
        var values: [String] = []
        try store.enumerateContacts(with: request) { contact, _ in
            values.append(contentsOf: [
                contact.givenName,
                contact.familyName,
                [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " "),
                contact.organizationName,
            ])
        }
        let before = ContextVocabularyStore.shared.terms.count
        ContextVocabularyStore.shared.add(values: values, source: .contacts)
        return max(0, ContextVocabularyStore.shared.terms.count - before)
    }

    @MainActor
    static func importUpcomingCalendar(days: Int = 30) async throws -> Int {
        let store = EKEventStore()
        let granted: Bool
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized:
            granted = true
        case .notDetermined:
            granted = try await store.requestFullAccessToEvents()
        default:
            granted = false
        }
        guard granted else { throw KikiError("Calendar access was not granted.") }

        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: days, to: start) ?? start
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)
        var values: [String] = []
        for event in events {
            values.append(event.title)
            values.append(contentsOf: event.attendees?.compactMap(\.name) ?? [])
        }
        let before = ContextVocabularyStore.shared.terms.count
        ContextVocabularyStore.shared.add(values: values, source: .calendar)
        return max(0, ContextVocabularyStore.shared.terms.count - before)
    }

    @MainActor
    static func importProject(at directory: URL, bundleIdentifier: String? = nil) async throws -> Int {
        let values: [String] = await Task.detached(priority: .utility) {
            projectTerms(at: directory)
        }.value
        let before = ContextVocabularyStore.shared.terms.count
        ContextVocabularyStore.shared.add(
            values: values,
            source: .project,
            bundleIdentifier: bundleIdentifier
        )
        return max(0, ContextVocabularyStore.shared.terms.count - before)
    }

    private static func projectTerms(at directory: URL) -> [String] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }
        var result: Set<String> = []
        var visited = 0
        while let url = enumerator.nextObject() as? URL {
            visited += 1
            if visited > 10_000 { break }
            let name = url.deletingPathExtension().lastPathComponent
            guard name.count >= 4, name.count <= 80 else { continue }
            result.insert(name.replacingOccurrences(of: "[-_]", with: " ", options: .regularExpression))
            let camelWords = name.replacingOccurrences(
                of: "([a-z0-9])([A-Z])",
                with: "$1 $2",
                options: .regularExpression
            )
            result.insert(camelWords)
        }
        return Array(result)
    }
}

private enum ApproximateTermReplacer {
    private struct Candidate {
        let value: String
        let normalized: String
        let count: Int
    }

    private static let commonWords: Set<String> = [
        "about", "after", "again", "could", "first", "from", "have", "just", "more",
        "other", "should", "some", "than", "that", "their", "there", "these", "they",
        "this", "very", "what", "when", "where", "which", "with", "would", "your"
    ]

    static func apply(terms: [String], to text: String) -> String {
        let values = Set(terms.flatMap { term -> [String] in
            let words = term.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
            return words.count == 1 ? words : words.filter { $0.count >= 5 }
        }).filter { $0.count >= 5 && !commonWords.contains($0.lowercased()) }
        var index: [Character: [Candidate]] = [:]
        for value in values {
            let normalized = normalize(value)
            guard let first = normalized.first else { continue }
            index[first, default: []].append(
                Candidate(value: value, normalized: normalized, count: normalized.count)
            )
        }
        guard let regex = try? NSRegularExpression(pattern: "[\\p{L}\\p{M}’'-]+") else { return text }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        var replacements: [(NSRange, String)] = []
        for match in matches {
            let word = nsText.substring(with: match.range)
            let normalizedWord = normalize(word)
            guard let first = normalizedWord.first, let possible = index[first] else { continue }
            var best: Candidate?
            var bestDistance = Int.max
            var tied = false
            for candidate in possible {
                guard normalizedWord != candidate.normalized,
                      abs(normalizedWord.count - candidate.count) <= 2,
                      candidate.count >= 7 || word.first?.isUppercase == true
                else { continue }
                let maximum = candidate.count >= 9 ? 2 : 1
                let distance = levenshtein(normalizedWord, candidate.normalized)
                guard distance <= maximum else { continue }
                if distance < bestDistance {
                    best = candidate
                    bestDistance = distance
                    tied = false
                } else if distance == bestDistance, best?.normalized != candidate.normalized {
                    tied = true
                }
            }
            if let best, !tied {
                replacements.append((match.range, best.value))
            }
        }
        guard !replacements.isEmpty else { return text }
        let mutable = NSMutableString(string: text)
        for (range, replacement) in replacements.reversed() {
            mutable.replaceCharacters(in: range, with: replacement)
        }
        return mutable as String
    }

    private static func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs)
        let b = Array(rhs)
        var previous = Array(0...b.count)
        for (i, left) in a.enumerated() {
            var current = [i + 1] + Array(repeating: 0, count: b.count)
            for (j, right) in b.enumerated() {
                current[j + 1] = min(
                    current[j] + 1,
                    previous[j + 1] + 1,
                    previous[j] + (left == right ? 0 : 1)
                )
            }
            previous = current
        }
        return previous[b.count]
    }
}
