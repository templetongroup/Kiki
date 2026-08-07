import AppKit
import Foundation

enum TranscriptionSource: String, Codable {
    case dictation
    case file
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
    private let maximumRecords = 1_000
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
    }

    func add(
        text: String,
        duration: TimeInterval,
        modelName: String,
        source: TranscriptionSource,
        context: String?
    ) {
        guard Settings.saveTranscriptionHistory, !text.isEmpty else { return }
        records.insert(
            TranscriptionRecord(
                id: UUID(),
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
        if records.count > maximumRecords {
            records.removeLast(records.count - maximumRecords)
        }
        save()
    }

    func remove(id: UUID) {
        records.removeAll { $0.id == id }
        save()
    }

    func clear() {
        records.removeAll()
        save()
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(records) else { return }
        try? FileManager.default.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: storageURL, options: .atomic)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }
}
