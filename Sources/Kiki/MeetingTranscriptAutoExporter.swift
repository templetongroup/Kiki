import Foundation

struct MeetingAutoExportConfiguration: Equatable {
    let isEnabled: Bool
    let folderURL: URL?

    init(isEnabled: Bool, folderURL: URL?) {
        self.folderURL = folderURL
        self.isEnabled = isEnabled && folderURL != nil
    }
}

enum MeetingAutoExportResult: Equatable {
    case disabled
    case saved(fileName: String)
    case failed(String)
}

enum MeetingTranscriptAutoExporter {
    static func export(
        _ transcript: MeetingTranscript,
        configuration: MeetingAutoExportConfiguration = Settings.meetingAutoExportConfiguration,
        fileManager: FileManager = .default
    ) -> MeetingAutoExportResult {
        guard configuration.isEnabled else { return .disabled }
        guard let folder = configuration.folderURL else {
            return .failed("no export folder is selected")
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return .failed("the selected export folder is no longer available")
        }
        guard fileManager.isWritableFile(atPath: folder.path) else {
            return .failed("the selected export folder is not writable")
        }

        let fileName = kikiTimestampedFileStem(
            date: transcript.createdAt,
            title: transcript.title,
            fallback: "Meeting"
        ) + ".md"
        let url = folder.appendingPathComponent(fileName)
        do {
            try transcript.markdown.write(to: url, atomically: true, encoding: .utf8)
            return .saved(fileName: fileName)
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
