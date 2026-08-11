import Foundation

struct ConfidenceReview: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let primaryText: String
    let alternateText: String
    let context: String?
    let similarity: Double

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        primaryText: String,
        alternateText: String,
        context: String?,
        similarity: Double
    ) {
        self.id = id
        self.createdAt = createdAt
        self.primaryText = primaryText
        self.alternateText = alternateText
        self.context = context
        self.similarity = similarity
    }
}

@MainActor
final class ConfidenceReviewStore {
    static let shared = ConfidenceReviewStore()
    static let didChangeNotification = Notification.Name("KikiConfidenceReviewsDidChange")

    private(set) var reviews: [ConfidenceReview] = []
    private let storageURL: URL

    private static var defaultFileURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Kiki", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("confidence-reviews.json")
    }

    private init() {
        storageURL = Self.defaultFileURL
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([ConfidenceReview].self, from: data)
        else { return }
        reviews = decoded
    }

    func add(primary: String, alternate: String, context: String?, similarity: Double) {
        guard similarity < 0.82, !primary.isEmpty, !alternate.isEmpty else { return }
        reviews.insert(
            ConfidenceReview(
                primaryText: primary,
                alternateText: alternate,
                context: context,
                similarity: similarity
            ),
            at: 0
        )
        reviews = Array(reviews.prefix(100))
        save()
    }

    func remove(id: UUID) {
        reviews.removeAll { $0.id == id }
        save()
    }

    func clear() {
        reviews.removeAll()
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(reviews) else { return }
        try? data.write(to: storageURL, options: .atomic)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }
}

final class BackgroundConfidenceVerifier: @unchecked Sendable {
    private let queue = DispatchQueue(label: "kiki.confidence-verifier", qos: .utility)
    private var transcriber: WhisperTranscriber?
    private var modelPath: String?

    @MainActor
    func verify(
        samples: [Float],
        primaryText: String,
        context: AppContextSnapshot?
    ) {
        guard Settings.enableConfidenceVerification,
              Settings.transcriptionModel.isParakeet,
              context?.privacyPolicy.confidenceVerificationEnabled ?? true,
              let url = ModelStore.activeModelURL()
        else { return }
        let language = Settings.language
        let contextName = context?.displayName
        queue.async { [weak self] in
            guard let self else { return }
            if self.transcriber == nil || self.modelPath != url.path {
                self.transcriber = try? WhisperTranscriber(modelPath: url.path, language: language)
                self.modelPath = self.transcriber == nil ? nil : url.path
            }
            guard let alternate = self.transcriber?.transcribe(samples), !alternate.isEmpty else { return }
            let similarity = TranscriptSimilarity.score(primaryText, alternate)
            DispatchQueue.main.async {
                ConfidenceReviewStore.shared.add(
                    primary: primaryText,
                    alternate: alternate,
                    context: contextName,
                    similarity: similarity
                )
            }
        }
    }
}

private enum TranscriptSimilarity {
    static func score(_ lhs: String, _ rhs: String) -> Double {
        let a = words(lhs)
        let b = words(rhs)
        guard !a.isEmpty || !b.isEmpty else { return 1 }
        let common = a.intersection(b).count
        let union = a.union(b).count
        return union == 0 ? 1 : Double(common) / Double(union)
    }

    private static func words(_ text: String) -> Set<String> {
        Set(text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
    }
}
