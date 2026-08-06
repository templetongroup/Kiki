import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    var onSettingsChange: (@MainActor (DictationShortcut, ActivationMode) -> Void)?
    var onModelChange: (@MainActor (TranscriptionModelID) -> Void)?

    private let shortcutButton = NSButton(title: "", target: nil, action: nil)
    private let modePopup = NSPopUpButton()
    private let modelPopup = NSPopUpButton()
    private let modelDetailLabel = NSTextField(wrappingLabelWithString: "")
    private let useModelButton = NSButton(title: "Use Model", target: nil, action: nil)
    private let silenceAudioCheckbox = NSButton(
        checkboxWithTitle: "Silence system audio while recording",
        target: nil,
        action: nil
    )
    private let liveTranscriptionCheckbox = NSButton(
        checkboxWithTitle: "Show live transcription while speaking",
        target: nil,
        action: nil
    )
    private let messageLabel = NSTextField(labelWithString: "")
    private var captureMonitor: Any?
    private var pendingModifierKeyCode: UInt16?
    private var pendingModifierFlags: NSEvent.ModifierFlags = []

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Kiki Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildContent()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        refresh()
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildContent() {
        let title = NSTextField(labelWithString: "Dictation Shortcut")
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        let detail = NSTextField(wrappingLabelWithString: "Choose any modifier key or a keyboard shortcut. Kiki listens globally after Accessibility permission is granted.")
        detail.textColor = .secondaryLabelColor

        shortcutButton.target = self
        shortcutButton.action = #selector(beginCapture)
        shortcutButton.bezelStyle = .rounded
        shortcutButton.font = .monospacedSystemFont(ofSize: 14, weight: .medium)

        let reset = NSButton(title: "Restore Default", target: self, action: #selector(resetShortcut))
        modePopup.addItems(withTitles: ActivationMode.allCases.map(\.title))
        modePopup.target = self
        modePopup.action = #selector(modeChanged)

        let modelTitle = NSTextField(labelWithString: "Local Transcription Model")
        modelTitle.font = .systemFont(ofSize: 16, weight: .semibold)
        modelPopup.addItems(withTitles: TranscriptionModelID.allCases.map(\.displayName))
        for (index, model) in TranscriptionModelID.allCases.enumerated() {
            modelPopup.item(at: index)?.isEnabled = model.isCompatible
        }
        modelPopup.target = self
        modelPopup.action = #selector(modelSelectionChanged)
        modelDetailLabel.textColor = .secondaryLabelColor
        useModelButton.target = self
        useModelButton.action = #selector(useSelectedModel)

        let modelRow = NSStackView(views: [modelPopup, useModelButton])
        modelRow.spacing = 10

        messageLabel.textColor = .secondaryLabelColor
        messageLabel.font = .systemFont(ofSize: 12)

        let shortcutRow = NSStackView(views: [NSTextField(labelWithString: "Shortcut:"), shortcutButton, reset])
        shortcutRow.spacing = 10
        let modeRow = NSStackView(views: [NSTextField(labelWithString: "Behavior:"), modePopup])
        modeRow.spacing = 10
        let note = NSTextField(labelWithString: "Control–Option–D remains available as a backup toggle shortcut.")
        note.textColor = .tertiaryLabelColor
        note.font = .systemFont(ofSize: 12)

        silenceAudioCheckbox.target = self
        silenceAudioCheckbox.action = #selector(silenceAudioChanged)
        let silenceAudioDetail = NSTextField(wrappingLabelWithString: "Prevents music, podcasts, and other playback from reaching the microphone. Kiki restores the previous mute or volume when recording stops.")
        silenceAudioDetail.textColor = .secondaryLabelColor
        silenceAudioDetail.font = .systemFont(ofSize: 12)

        liveTranscriptionCheckbox.target = self
        liveTranscriptionCheckbox.action = #selector(liveTranscriptionChanged)
        let liveTranscriptionDetail = NSTextField(wrappingLabelWithString: "Shows words in Kiki's branded listening window as they are recognized. Low-latency preview is available with Parakeet models; the final paste still uses a full accuracy pass.")
        liveTranscriptionDetail.textColor = .secondaryLabelColor
        liveTranscriptionDetail.font = .systemFont(ofSize: 12)

        let divider = NSBox()
        divider.boxType = .separator
        let stack = NSStackView(views: [title, detail, shortcutRow, messageLabel, modeRow, note, silenceAudioCheckbox, silenceAudioDetail, liveTranscriptionCheckbox, liveTranscriptionDetail, divider, modelTitle, modelRow, modelDetailLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        guard let content = window?.contentView else { return }
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 26),
            detail.widthAnchor.constraint(equalTo: stack.widthAnchor),
            silenceAudioDetail.widthAnchor.constraint(equalTo: stack.widthAnchor),
            liveTranscriptionDetail.widthAnchor.constraint(equalTo: stack.widthAnchor),
            modelDetailLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            divider.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        refresh()
    }

    private func refresh() {
        shortcutButton.title = Settings.dictationShortcut.displayString
        silenceAudioCheckbox.state = Settings.silenceSystemAudioWhileRecording ? .on : .off
        liveTranscriptionCheckbox.state = Settings.showLiveTranscription ? .on : .off
        modePopup.selectItem(at: ActivationMode.allCases.firstIndex(of: Settings.activationMode) ?? 0)
        modelPopup.selectItem(at: TranscriptionModelID.allCases.firstIndex(of: Settings.transcriptionModel) ?? 0)
        updateModelControls()
    }

    @objc private func beginCapture() {
        stopCapture()
        pendingModifierKeyCode = nil
        pendingModifierFlags = []
        shortcutButton.title = "Press shortcut…"
        messageLabel.stringValue = "Press a modifier by itself, or a modifier plus another key. Escape cancels."
        captureMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.capture(event) ?? event
        }
    }

    private func capture(_ event: NSEvent) -> NSEvent? {
        let relevant = event.modifierFlags.intersection([.command, .option, .control, .shift, .function])
        if event.type == .keyDown {
            if event.keyCode == 53 { stopCapture(); refresh(); messageLabel.stringValue = ""; return nil }
            guard !relevant.isEmpty else { messageLabel.stringValue = "Use a modifier key or a modified shortcut."; return nil }
            save(DictationShortcut(keyCode: event.keyCode, modifiersRawValue: relevant.rawValue))
            return nil
        }
        guard event.type == .flagsChanged, let flag = DictationShortcut.modifierFlag(for: event.keyCode) else { return nil }
        if relevant.contains(flag) {
            pendingModifierKeyCode = event.keyCode
            pendingModifierFlags = relevant
        } else if let keyCode = pendingModifierKeyCode {
            save(DictationShortcut(keyCode: keyCode, modifiersRawValue: pendingModifierFlags.rawValue))
        }
        return nil
    }

    private func save(_ shortcut: DictationShortcut) {
        Settings.dictationShortcut = shortcut
        stopCapture()
        refresh()
        messageLabel.stringValue = "Shortcut updated."
        onSettingsChange?(shortcut, Settings.activationMode)
    }

    private func stopCapture() {
        if let captureMonitor { NSEvent.removeMonitor(captureMonitor) }
        captureMonitor = nil
    }

    @objc private func resetShortcut() { save(.rightOption) }

    @objc private func modeChanged() {
        Settings.activationMode = ActivationMode.allCases[modePopup.indexOfSelectedItem]
        onSettingsChange?(Settings.dictationShortcut, Settings.activationMode)
    }

    @objc private func silenceAudioChanged() {
        Settings.silenceSystemAudioWhileRecording = silenceAudioCheckbox.state == .on
    }

    @objc private func liveTranscriptionChanged() {
        Settings.showLiveTranscription = liveTranscriptionCheckbox.state == .on
    }

    @objc private func modelSelectionChanged() {
        updateModelControls()
    }

    private var selectedModel: TranscriptionModelID {
        TranscriptionModelID.allCases[max(0, modelPopup.indexOfSelectedItem)]
    }

    private func updateModelControls() {
        let model = selectedModel
        var detail = model.detail
        if !model.isCompatible {
            detail += " Requires Apple Silicon."
        } else if model.isParakeet {
            detail += " The Core ML model downloads automatically on first use."
        } else if ModelStore.isWhisperModelInstalled(model) {
            detail += " Installed."
        } else {
            detail += " Not installed."
        }
        modelDetailLabel.stringValue = detail
        useModelButton.isEnabled = model.isCompatible
        useModelButton.title = !model.isParakeet && !ModelStore.isWhisperModelInstalled(model)
            ? "Download & Use" : "Use Model"
    }

    @objc private func useSelectedModel() {
        let model = selectedModel
        guard model.isCompatible else { return }
        useModelButton.isEnabled = false
        modelDetailLabel.stringValue = model.isParakeet ? "Downloading or loading Core ML model…" : "Downloading Whisper model…"

        if model.isParakeet || ModelStore.isWhisperModelInstalled(model) {
            Settings.transcriptionModel = model
            onModelChange?(model)
            updateModelControls()
            return
        }

        Task { [weak self] in
            do {
                try await ModelDownloadService.downloadWhisperModel(model)
                await MainActor.run {
                    Settings.transcriptionModel = model
                    self?.onModelChange?(model)
                    self?.updateModelControls()
                }
            } catch {
                await MainActor.run {
                    self?.modelDetailLabel.stringValue = "Download failed: \(error.localizedDescription)"
                    self?.useModelButton.isEnabled = true
                }
            }
        }
    }
}
