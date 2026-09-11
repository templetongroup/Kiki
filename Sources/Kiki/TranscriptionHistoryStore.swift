import AppKit
import Foundation

enum TranscriptionSource: String, Codable {
    case dictation
    case file
    case meeting
}

struct TranscriptionRecord: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let text: String
    let duration: TimeInterval
    let modelName: String
    let source: TranscriptionSource
    let context: String?
    let processedLocally: Bool
}

@MainActor
final class TranscriptionHistoryStore {
    static let shared = TranscriptionHistoryStore()
    static let didChangeNotification = Notification.Name("KikiHistoryDidChange")

    private(set) var records: [TranscriptionRecord] = []
    private let storageURL: URL

    private static var defaultFileURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Kiki", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("history.json")
    }

    init(fileURL: URL? = nil) {
        storageURL = fileURL ?? Self.defaultFileURL
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? decoder.decode([TranscriptionRecord].self, from: data)
        else { return }
        records = decoded.sorted { $0.createdAt > $1.createdAt }
        let originalCount = records.count
        applyRetentionPolicy(notify: false)
        if records.count != originalCount { save(notify: false) }
    }

    @discardableResult
    func add(
        text: String,
        duration: TimeInterval,
        modelName: String,
        source: TranscriptionSource,
        context: String?
    ) -> UUID? {
        guard Settings.saveTranscriptionHistory, !text.isEmpty else { return nil }
        let id = UUID()
        records.insert(
            TranscriptionRecord(
                id: id,
                createdAt: Date(),
                text: text,
                duration: duration,
                modelName: modelName,
                source: source,
                context: context,
                processedLocally: true
            ),
            at: 0
        )
        applyRetentionPolicy(notify: false)
        save()
        return id
    }

    func remove(id: UUID) {
        records.removeAll { $0.id == id }
        save()
    }

    func update(id: UUID, text: String, context: String? = nil) {
        guard let index = records.firstIndex(where: { $0.id == id }), !text.isEmpty else { return }
        let existing = records[index]
        records[index] = TranscriptionRecord(
            id: existing.id,
            createdAt: existing.createdAt,
            text: text,
            duration: existing.duration,
            modelName: existing.modelName,
            source: existing.source,
            context: context ?? existing.context,
            processedLocally: existing.processedLocally
        )
        save()
    }

    func clear() {
        records.removeAll()
        save()
    }

    func clear(sources: Set<TranscriptionSource>) {
        records.removeAll { sources.contains($0.source) }
        save()
    }

    func applyRetentionPolicy() {
        applyRetentionPolicy(notify: true)
    }

    private func applyRetentionPolicy(notify: Bool) {
        guard let maximum = Settings.dictationHistoryRetention.maximumCount else {
            if notify { NotificationCenter.default.post(name: Self.didChangeNotification, object: nil) }
            return
        }
        var dictationCount = 0
        records.removeAll { record in
            guard record.source == .dictation else { return false }
            dictationCount += 1
            return dictationCount > maximum
        }
        if notify { save() }
    }

    private func save(notify: Bool = true) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(records) else { return }
        try? FileManager.default.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: storageURL, options: .atomic)
        if notify {
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        }
    }
}
