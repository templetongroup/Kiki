import AppKit
import ServiceManagement

enum AppAppearanceMode: String, CaseIterable {
    case dark

    var title: String {
        "Dark"
    }

    var appearance: NSAppearance? {
        NSAppearance(named: .darkAqua)
    }
}

enum KikiAccentColor: String, CaseIterable {
    case gold, teal, blue, purple, rose, graphite

    var title: String {
        switch self {
        case .gold: "Sage"
        default: rawValue.capitalized
        }
    }

    var color: NSColor {
        switch self {
        // Keep the historical raw value for existing preferences while making
        // the default accent match the Studio Hardware palette.
        case .gold: NSColor(red: 0.376, green: 0.424, blue: 0.349, alpha: 1)
        case .teal: NSColor(red: 0.12, green: 0.68, blue: 0.66, alpha: 1)
        case .blue: .systemBlue
        case .purple: .systemPurple
        case .rose: NSColor(red: 0.92, green: 0.30, blue: 0.48, alpha: 1)
        case .graphite: .secondaryLabelColor
        }
    }
}

enum DictationSoundStyle: String, CaseIterable {
    case off, subtle, classic

    var title: String {
        switch self {
        case .off: "Off"
        case .subtle: "Subtle"
        case .classic: "Classic"
        }
    }
}

@MainActor
enum AppearanceController {
    static func apply() {
        Settings.appearanceMode = .dark
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }
}

enum LaunchAtLoginController {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else if SMAppService.mainApp.status == .enabled {
            try SMAppService.mainApp.unregister()
        }
    }
}

final class DictationSoundPlayer {
    private func play(named name: String, volume: Float) {
        guard let sound = NSSound(
            contentsOfFile: "/System/Library/Sounds/\(name).aiff",
            byReference: true
        ) else { return }
        sound.volume = volume
        sound.play()
    }

    func playRecordingStarted() {
        switch Settings.soundStyle {
        case .off: break
        case .subtle: play(named: "Tink", volume: 0.28)
        case .classic: play(named: "Glass", volume: 0.42)
        }
    }

    func playTranscriptionCompleted() {
        switch Settings.soundStyle {
        case .off: break
        case .subtle: play(named: "Pop", volume: 0.28)
        case .classic: play(named: "Hero", volume: 0.36)
        }
    }
}
