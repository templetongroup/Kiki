import AppKit
import ServiceManagement

enum AppAppearanceMode: String, CaseIterable {
    case system, light, dark

    var title: String {
        switch self {
        case .system: "Follow System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var appearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

enum KikiAccentColor: String, CaseIterable {
    case gold, teal, blue, purple, rose, graphite

    var title: String {
        switch self {
        case .gold: "Orange"
        default: rawValue.capitalized
        }
    }

    var color: NSColor {
        switch self {
        case .gold: NSColor(red: 1.00, green: 0.55, blue: 0.12, alpha: 1)
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
        NSApp.appearance = Settings.appearanceMode.appearance
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
