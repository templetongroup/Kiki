import AppKit
import Foundation

struct VoiceSnippet: Codable, Identifiable, Equatable {
    let id: UUID
    var trigger: String
    var template: String

    init(id: UUID = UUID(), trigger: String, template: String) {
        self.id = id
        self.trigger = trigger
        self.template = template
    }
}

@MainActor
final class VoiceSnippetStore {
    static let shared = VoiceSnippetStore()
    static let didChangeNotification = Notification.Name("KikiVoiceSnippetsDidChange")

    private(set) var snippets: [VoiceSnippet] = []
    private let storageURL: URL

    private static var defaultFileURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Kiki", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("snippets.json")
    }

    init(fileURL: URL? = nil) {
        storageURL = fileURL ?? Self.defaultFileURL
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([VoiceSnippet].self, from: data)
        else { return }
        snippets = decoded
    }

    func add(trigger: String, template: String) {
        let trigger = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        let template = template.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trigger.isEmpty, !template.isEmpty else { return }
        snippets.removeAll { $0.trigger.caseInsensitiveCompare(trigger) == .orderedSame }
        snippets.append(VoiceSnippet(trigger: trigger, template: template))
        snippets.sort { $0.trigger.localizedCaseInsensitiveCompare($1.trigger) == .orderedAscending }
        save()
    }

    func update(id: UUID, trigger: String, template: String) {
        let trigger = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        let template = template.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trigger.isEmpty, !template.isEmpty,
              snippets.contains(where: { $0.id == id }) else { return }
        snippets.removeAll {
            $0.id != id && $0.trigger.caseInsensitiveCompare(trigger) == .orderedSame
        }
        guard let index = snippets.firstIndex(where: { $0.id == id }) else { return }
        snippets[index].trigger = trigger
        snippets[index].template = template
        snippets.sort { $0.trigger.localizedCaseInsensitiveCompare($1.trigger) == .orderedAscending }
        save()
    }

    func remove(id: UUID) {
        snippets.removeAll { $0.id == id }
        save()
    }

    func expansion(for transcript: String) -> String? {
        let normalized = Self.normalizedTrigger(transcript)
        guard let snippet = snippets.first(where: {
            Self.normalizedTrigger($0.trigger) == normalized ||
            "kiki \(Self.normalizedTrigger($0.trigger))" == normalized
        }) else { return nil }
        return Self.render(snippet.template)
    }

    private static func normalizedTrigger(_ value: String) -> String {
        value.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private static func render(_ template: String) -> String {
        let now = Date()
        let date = DateFormatter.localizedString(from: now, dateStyle: .medium, timeStyle: .none)
        let time = DateFormatter.localizedString(from: now, dateStyle: .none, timeStyle: .short)
        let clipboard = NSPasteboard.general.string(forType: .string) ?? ""
        return template
            .replacingOccurrences(of: "{{date}}", with: date)
            .replacingOccurrences(of: "{{time}}", with: time)
            .replacingOccurrences(of: "{{clipboard}}", with: clipboard)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(snippets) else { return }
        try? data.write(to: storageURL, options: .atomic)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }
}
