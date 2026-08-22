import AppKit
import AVFoundation
import Foundation

private struct SupportBundleReport: Codable {
    struct PermissionStatus: Codable {
        let microphone: String
        let accessibility: Bool
    }

    struct CheckupStatus: Codable {
        let shortcutVerified: Bool
        let firstDictationCompleted: Bool
    }

    let schemaVersion: Int
    let generatedAt: Date
    let appVersion: String
    let appBuild: String
    let osVersion: String
    let architecture: String
    let permissionStatus: PermissionStatus
    let selectedModel: String
    let modelReady: Bool
    let activationMode: String
    let listeningDisplayMode: String
    let listeningDisplayPosition: String
    let appearanceMode: String
    let privateSessionActive: Bool
    let checkupStatus: CheckupStatus
}

@MainActor
enum SupportBundleBuilder {
    static func diagnosticJSONForTesting() -> Data {
        encode(
            SupportBundleReport(
                schemaVersion: 1,
                generatedAt: Date(timeIntervalSince1970: 0),
                appVersion: "0.0.0",
                appBuild: "0",
                osVersion: "test",
                architecture: "test",
                permissionStatus: .init(microphone: "authorized", accessibility: true),
                selectedModel: "parakeetEnglish",
                modelReady: true,
                activationMode: "hold",
                listeningDisplayMode: "waveform",
                listeningDisplayPosition: "bottom",
                appearanceMode: "dark",
                privateSessionActive: false,
                checkupStatus: .init(shortcutVerified: true, firstDictationCompleted: true)
            )
        ) ?? Data()
    }

    static func createArchive(at destination: URL, modelReady: Bool) throws {
        let report = currentReport(modelReady: modelReady)
        guard let data = encode(report) else { throw KikiError("Kiki could not encode the support report.") }

        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("Kiki-Support-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }
        try data.write(to: temporaryRoot.appendingPathComponent("diagnostics.json"), options: .atomic)
        let privacyNote = """
        Kiki Support Bundle

        This archive contains only allowlisted technical configuration and readiness information.
        It does not contain dictated text, recordings, clipboard contents, personal vocabulary, contacts, or file paths.
        """
        try privacyNote.write(
            to: temporaryRoot.appendingPathComponent("README.txt"),
            atomically: true,
            encoding: .utf8
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", temporaryRoot.path, destination.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw KikiError("Kiki could not create the support archive.")
        }
    }

    private static func currentReport(modelReady: Bool) -> SupportBundleReport {
        let info = Bundle.main.infoDictionary ?? [:]
        return SupportBundleReport(
            schemaVersion: 1,
            generatedAt: Date(),
            appVersion: info["CFBundleShortVersionString"] as? String ?? "unknown",
            appBuild: info["CFBundleVersion"] as? String ?? "unknown",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            architecture: architecture,
            permissionStatus: .init(
                microphone: microphoneAuthorization,
                accessibility: AXIsProcessTrusted()
            ),
            selectedModel: Settings.transcriptionModel.rawValue,
            modelReady: modelReady,
            activationMode: Settings.activationMode.rawValue,
            listeningDisplayMode: Settings.listeningDisplayMode.rawValue,
            listeningDisplayPosition: Settings.listeningDisplayPosition.rawValue,
            appearanceMode: Settings.appearanceMode.rawValue,
            privateSessionActive: PrivateSessionController.shared.isActive,
            checkupStatus: .init(
                shortcutVerified: Settings.checkupShortcutVerified,
                firstDictationCompleted: Settings.checkupFirstDictationCompleted
            )
        )
    }

    private static func encode(_ report: SupportBundleReport) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(report)
    }

    private static var microphoneAuthorization: String {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: "authorized"
        case .denied: "denied"
        case .restricted: "restricted"
        case .notDetermined: "notDetermined"
        @unknown default: "unknown"
        }
    }

    private static var architecture: String {
        #if arch(arm64)
        "arm64"
        #elseif arch(x86_64)
        "x86_64"
        #else
        "unknown"
        #endif
    }
}
