import CryptoKit
import Foundation

enum ModelFileIntegrity {
    private struct VerificationStamp: Codable {
        let size: Int64
        let modifiedAt: TimeInterval
        let fileIdentifier: UInt64
        let sha256: String
    }

    private static let verificationLock = NSLock()

    static func matchesExpectedSize(_ url: URL, expectedSize: Int64) -> Bool {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return false
        }
        return Int64(size) == expectedSize
    }

    static func isValid(
        _ url: URL,
        expectedSize: Int64,
        expectedSHA256: String
    ) -> Bool {
        verificationLock.lock()
        defer { verificationLock.unlock() }

        let expectedHash = expectedSHA256.lowercased()
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = (attributes[.size] as? NSNumber)?.int64Value,
              size == expectedSize,
              let modifiedAt = (attributes[.modificationDate] as? Date)?.timeIntervalSinceReferenceDate,
              let fileIdentifier = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value else {
            removeMetadata(for: url)
            return false
        }

        if let stamp = verificationStamp(for: url),
           stamp.size == expectedSize,
           stamp.modifiedAt == modifiedAt,
           stamp.fileIdentifier == fileIdentifier,
           stamp.sha256 == expectedHash {
            return true
        }

        guard let actualHash = sha256(of: url), actualHash == expectedHash else {
            removeMetadata(for: url)
            return false
        }
        let stamp = VerificationStamp(
            size: expectedSize,
            modifiedAt: modifiedAt,
            fileIdentifier: fileIdentifier,
            sha256: actualHash
        )
        if let encoded = try? JSONEncoder().encode(stamp) {
            try? encoded.write(to: metadataURL(for: url), options: .atomic)
        }
        return true
    }

    static func validateAsync(
        _ url: URL,
        expectedSize: Int64,
        expectedSHA256: String
    ) async -> Bool {
        await Task.detached(priority: .utility) {
            isValid(url, expectedSize: expectedSize, expectedSHA256: expectedSHA256)
        }.value
    }

    static func removeMetadata(for url: URL) {
        try? FileManager.default.removeItem(at: metadataURL(for: url))
    }

    private static func sha256(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        do {
            while let data = try handle.read(upToCount: 4 * 1_024 * 1_024), !data.isEmpty {
                hasher.update(data: data)
            }
        } catch {
            return nil
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func verificationStamp(for url: URL) -> VerificationStamp? {
        guard let data = try? Data(contentsOf: metadataURL(for: url)) else { return nil }
        return try? JSONDecoder().decode(VerificationStamp.self, from: data)
    }

    private static func metadataURL(for url: URL) -> URL {
        url.appendingPathExtension("kiki-verified")
    }
}
