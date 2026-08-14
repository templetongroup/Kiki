import AppKit

struct KikiError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

enum Settings {
    /// Whisper language code ("en", "de", ...) or "auto" to detect per utterance.
    static var language: String {
        UserDefaults.standard.string(forKey: "language") ?? "en"
    }

    /// Optional model file name override, e.g. "ggml-small.en.bin".
    static var modelOverride: String? {
        UserDefaults.standard.string(forKey: "model")
    }

    static var dictationShortcut: DictationShortcut {
        get {
            guard let data = UserDefaults.standard.data(forKey: "dictationShortcut"),
                  let shortcut = try? JSONDecoder().decode(DictationShortcut.self, from: data)
            else { return .rightOption }
            return shortcut
        }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: "dictationShortcut") }
    }

    static var activationMode: ActivationMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "activationMode") else { return .hold }
            return ActivationMode(rawValue: raw) ?? .hold
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "activationMode") }
    }

    static var transcriptionModel: TranscriptionModelID {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "transcriptionModel") else {
                return TranscriptionModelID.recommendedDefault
            }
            return TranscriptionModelID(rawValue: raw) ?? TranscriptionModelID.recommendedDefault
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "transcriptionModel") }
    }

    static var silenceSystemAudioWhileRecording: Bool {
        get {
            let key = "silenceSystemAudioWhileRecording"
            guard UserDefaults.standard.object(forKey: key) != nil else { return true }
            return UserDefaults.standard.bool(forKey: key)
        }
        set { UserDefaults.standard.set(newValue, forKey: "silenceSystemAudioWhileRecording") }
    }

    static var listeningDisplayMode: ListeningDisplayMode {
        get {
            if let raw = UserDefaults.standard.string(forKey: "listeningDisplayMode"),
               let mode = ListeningDisplayMode(rawValue: raw) {
                return mode
            }
            // The old switch controlled live words but always kept the panel.
            // Preserve that preference by migrating "off" to the compact mode.
            if UserDefaults.standard.object(forKey: "showLiveTranscription") != nil,
               !UserDefaults.standard.bool(forKey: "showLiveTranscription") {
                return .waveform
            }
            return .fullTranscript
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "listeningDisplayMode") }
    }

    static var appearanceMode: AppAppearanceMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "appearanceMode") else {
                return .dark
            }
            return AppAppearanceMode(rawValue: raw) ?? .dark
        }
        set { UserDefaults.standard.set(AppAppearanceMode.dark.rawValue, forKey: "appearanceMode") }
    }

    static var accentColor: KikiAccentColor {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "accentColor") else {
                return .gold
            }
            return KikiAccentColor(rawValue: raw) ?? .gold
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "accentColor") }
    }

    static var soundStyle: DictationSoundStyle {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "soundStyle") else {
                return .subtle
            }
            return DictationSoundStyle(rawValue: raw) ?? .subtle
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "soundStyle") }
    }

    static var saveTranscriptionHistory: Bool {
        get {
            let key = "saveTranscriptionHistory"
            guard UserDefaults.standard.object(forKey: key) != nil else { return true }
            return UserDefaults.standard.bool(forKey: key)
        }
        set { UserDefaults.standard.set(newValue, forKey: "saveTranscriptionHistory") }
    }

    static var learnFromCorrections: Bool {
        get { bool(forKey: "learnFromCorrections", default: true) }
        set { UserDefaults.standard.set(newValue, forKey: "learnFromCorrections") }
    }

    static var useContextVocabulary: Bool {
        get { bool(forKey: "useContextVocabulary", default: true) }
        set { UserDefaults.standard.set(newValue, forKey: "useContextVocabulary") }
    }

    static var enableZeroWaitChaining: Bool {
        get { bool(forKey: "enableZeroWaitChaining", default: true) }
        set { UserDefaults.standard.set(newValue, forKey: "enableZeroWaitChaining") }
    }

    static var enableVoiceContinuations: Bool {
        get { bool(forKey: "enableVoiceContinuations", default: true) }
        set { UserDefaults.standard.set(newValue, forKey: "enableVoiceContinuations") }
    }

    static var listeningDisplayPosition: ListeningDisplayPosition {
        get {
            if let raw = UserDefaults.standard.string(forKey: "listeningDisplayPosition"),
               let position = ListeningDisplayPosition(rawValue: raw) {
                return position
            }
            // Preserve the former near-cursor preference when upgrading.
            if UserDefaults.standard.object(forKey: "showHUDNearCaret") != nil,
               !UserDefaults.standard.bool(forKey: "showHUDNearCaret") {
                return .bottom
            }
            return .nearTargetWindow
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "listeningDisplayPosition") }
    }

    static var enableConfidenceVerification: Bool {
        get { bool(forKey: "enableConfidenceVerification", default: false) }
        set { UserDefaults.standard.set(newValue, forKey: "enableConfidenceVerification") }
    }

    static var speechProfile: SpeechProfile {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "speechProfile") else { return .standard }
            return SpeechProfile(rawValue: raw) ?? .standard
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "speechProfile") }
    }

    static var continuationWindow: TimeInterval {
        get {
            let value = UserDefaults.standard.double(forKey: "continuationWindow")
            return value > 0 ? min(max(value, 1), 12) : 4
        }
        set { UserDefaults.standard.set(min(max(newValue, 1), 12), forKey: "continuationWindow") }
    }

    static var saveMeetingAudio: Bool {
        get { bool(forKey: "saveMeetingAudio", default: false) }
        set { UserDefaults.standard.set(newValue, forKey: "saveMeetingAudio") }
    }

    static var microphoneDeviceUID: String? {
        get { UserDefaults.standard.string(forKey: "microphoneDeviceUID") }
        set { UserDefaults.standard.set(newValue, forKey: "microphoneDeviceUID") }
    }

    static var checkupShortcutVerified: Bool {
        get { UserDefaults.standard.bool(forKey: "checkupShortcutVerified") }
        set { UserDefaults.standard.set(newValue, forKey: "checkupShortcutVerified") }
    }

    static var checkupFirstDictationCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: "checkupFirstDictationCompleted") }
        set { UserDefaults.standard.set(newValue, forKey: "checkupFirstDictationCompleted") }
    }

    static var pawprintsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "pawprintsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "pawprintsEnabled") }
    }

    private static func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else { return defaultValue }
        return UserDefaults.standard.bool(forKey: key)
    }
}

enum ActivationMode: String, CaseIterable {
    case hold, toggle

    var title: String { self == .hold ? "Hold to Dictate" : "Press to Toggle" }

    func configuredInstruction(for shortcut: DictationShortcut) -> String {
        switch self {
        case .hold:
            "Hold \(shortcut.displayString) to dictate; release to stop and insert."
        case .toggle:
            "Press \(shortcut.displayString) to start; press it again to stop and insert."
        }
    }

    func shortcutTestInstruction(for shortcut: DictationShortcut) -> String {
        switch self {
        case .hold:
            "Hold \(shortcut.displayString) briefly, then release."
        case .toggle:
            "Press \(shortcut.displayString) once."
        }
    }

    func recordingStopInstruction(for shortcut: DictationShortcut) -> String {
        switch self {
        case .hold:
            "Release \(shortcut.displayString)"
        case .toggle:
            "Press \(shortcut.displayString) again"
        }
    }
}

enum DictationShortcutGuidance {
    static let handsFreeKeys = "⌃⌥D"
    static let handsFreeInstruction = "Hands-free toggle: press ⌃⌥D to start; press it again to stop and insert."
}

enum ListeningDisplayMode: String, CaseIterable {
    case fullTranscript
    case waveform
    case hidden

    var title: String {
        switch self {
        case .fullTranscript: "Full Transcript"
        case .waveform: "Waveform"
        case .hidden: "Hidden"
        }
    }

    var detail: String {
        switch self {
        case .fullTranscript:
            "Shows Kiki's live words and recording status while you speak."
        case .waveform:
            "Shows only a compact sound wave that responds to your voice."
        case .hidden:
            "Keeps the screen completely clear while Kiki listens and transcribes."
        }
    }
}

enum ListeningDisplayPosition: String, CaseIterable {
    case bottom
    case top
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case nearTargetWindow

    var title: String {
        switch self {
        case .bottom: "Bottom of Screen"
        case .top: "Top of Screen"
        case .topLeft: "Top Left"
        case .topRight: "Top Right"
        case .bottomLeft: "Bottom Left"
        case .bottomRight: "Bottom Right"
        case .nearTargetWindow: "Hover Near Target Window"
        }
    }
}

struct DictationShortcut: Codable, Equatable {
    let keyCode: UInt16
    let modifiersRawValue: UInt

    static let rightOption = DictationShortcut(keyCode: 61, modifiersRawValue: NSEvent.ModifierFlags.option.rawValue)

    var modifiers: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiersRawValue) }
    var isModifierOnly: Bool { Self.modifierFlag(for: keyCode) != nil }

    var displayString: String {
        if isModifierOnly { return Self.keyName(keyCode) }
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append(Self.keyName(keyCode))
        return parts.joined()
    }

    static func modifierFlag(for keyCode: UInt16) -> NSEvent.ModifierFlags? {
        switch keyCode {
        case 54, 55: .command
        case 56, 60: .shift
        case 58, 61: .option
        case 59, 62: .control
        case 63: .function
        default: nil
        }
    }

    static func keyName(_ keyCode: UInt16) -> String {
        let names: [UInt16: String] = [
            0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",11:"B",
            12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",18:"1",19:"2",20:"3",21:"4",22:"6",23:"5",
            25:"9",26:"7",28:"8",29:"0",31:"O",32:"U",34:"I",35:"P",36:"Return",37:"L",38:"J",40:"K",
            45:"N",46:"M",48:"Tab",49:"Space",51:"Delete",53:"Esc",54:"Right ⌘",55:"Left ⌘",
            56:"Left ⇧",58:"Left ⌥",59:"Left ⌃",60:"Right ⇧",61:"Right ⌥",62:"Right ⌃",63:"Fn",
            123:"←",124:"→",125:"↓",126:"↑"
        ]
        return names[keyCode] ?? "Key \(keyCode)"
    }
}
