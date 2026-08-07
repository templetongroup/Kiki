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

    static var showLiveTranscription: Bool {
        get {
            let key = "showLiveTranscription"
            guard UserDefaults.standard.object(forKey: key) != nil else { return true }
            return UserDefaults.standard.bool(forKey: key)
        }
        set { UserDefaults.standard.set(newValue, forKey: "showLiveTranscription") }
    }

    static var appearanceMode: AppAppearanceMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "appearanceMode") else {
                return .system
            }
            return AppAppearanceMode(rawValue: raw) ?? .system
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "appearanceMode") }
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
}

enum ActivationMode: String, CaseIterable {
    case hold, toggle

    var title: String { self == .hold ? "Hold to Dictate" : "Press to Toggle" }
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
