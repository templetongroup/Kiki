import AppKit

@MainActor
final class GuidedWorkbenchSupportView: NSView {
    var onCreateBundle: (() -> Void)?
    var onOpenModels: (() -> Void)?
    var onCheckUpdates: (() -> Void)?

    init() {
        super.init(frame: .zero)
        let backdrop = KikiBackdropView()
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backdrop)
        let header = headerView(eyebrow: "SUPPORT", title: "Diagnostics without guesswork.", detail: "Create a private support bundle or inspect the local files Kiki manages.")
        let bundle = card(symbol: "shippingbox", title: "Support Bundle", detail: "Collect logs and configuration without transcript text or recordings.", button: "Create Support Bundle", action: #selector(createBundle))
        let models = card(symbol: "folder", title: "Models Folder", detail: "Reveal downloaded local transcription models in Finder.", button: "Open Models Folder", action: #selector(openModels))
        let updates = card(symbol: "arrow.triangle.2.circlepath", title: "Signed Updates", detail: "Check Kiki’s verified Sparkle release feed.", button: "Check for Updates", action: #selector(checkUpdates))
        let cards = NSStackView(views: [bundle, models, updates])
        cards.orientation = .horizontal
        cards.alignment = .top
        cards.distribution = .fillEqually
        cards.spacing = 14
        let stack = NSStackView(views: [header, cards])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 22
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: leadingAnchor), backdrop.trailingAnchor.constraint(equalTo: trailingAnchor), backdrop.topAnchor.constraint(equalTo: topAnchor), backdrop.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28), stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -28), stack.topAnchor.constraint(equalTo: topAnchor, constant: 30),
            cards.widthAnchor.constraint(equalTo: stack.widthAnchor), bundle.heightAnchor.constraint(equalToConstant: 260), models.heightAnchor.constraint(equalTo: bundle.heightAnchor), updates.heightAnchor.constraint(equalTo: bundle.heightAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func headerView(eyebrow: String, title: String, detail: String) -> NSView {
        let eyebrowLabel = kikiLabel(eyebrow, size: 10, weight: .bold, color: KikiPalette.accentText)
        let titleLabel = kikiLabel(title, size: 29, weight: .bold)
        let detailLabel = kikiLabel(detail, size: 14, color: KikiPalette.secondaryText)
        let stack = NSStackView(views: [eyebrowLabel, titleLabel, detailLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        return stack
    }

    private func card(symbol: String, title: String, detail: String, button: String, action: Selector) -> KikiCardView {
        let card = KikiCardView()
        let image = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: title) ?? NSImage())
        image.contentTintColor = KikiPalette.accentText
        let titleLabel = kikiLabel(title, size: 18, weight: .semibold)
        let detailLabel = kikiLabel(detail, size: 12.5, color: KikiPalette.secondaryText)
        detailLabel.maximumNumberOfLines = 0
        let actionButton = KikiActionButton(button, kind: .hardware, target: self, action: action)
        let stack = NSStackView(views: [image, titleLabel, detailLabel, NSView(), actionButton])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            image.widthAnchor.constraint(equalToConstant: 28), image.heightAnchor.constraint(equalToConstant: 28),
            actionButton.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18), stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18), stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18), stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])
        return card
    }

    @objc private func createBundle() { onCreateBundle?() }
    @objc private func openModels() { onOpenModels?() }
    @objc private func checkUpdates() { onCheckUpdates?() }
}

@MainActor
final class GuidedWorkbenchAboutView: NSView {
    var onRunCheckup: (() -> Void)?
    var onCheckUpdates: (() -> Void)?

    init() {
        super.init(frame: .zero)
        let backdrop = KikiBackdropView()
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backdrop)
        let image = KikiCircularPortraitView()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        let eyebrow = kikiLabel("ABOUT KIKI", size: 10, weight: .bold, color: KikiPalette.accentText)
        let title = kikiLabel("Voice intelligence that stays yours.", size: 30, weight: .bold)
        let detail = kikiLabel("Private dictation, meeting intelligence, and local transcription for macOS.", size: 14, color: KikiPalette.secondaryText)
        detail.maximumNumberOfLines = 0
        let versionLabel = kikiLabel("Version \(version) · Build \(build) · Fully local", size: 12, weight: .semibold, color: KikiPalette.khaki)
        let checkup = KikiActionButton("Troubleshoot Dictation", kind: .primary, target: self, action: #selector(runCheckup))
        checkup.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.about.checkup")
        let checkUpdates = KikiActionButton("Check for Updates", kind: .secondary, target: self, action: #selector(checkUpdates))
        checkUpdates.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.about.check-updates")
        let actions = NSStackView(views: [checkup, checkUpdates])
        actions.orientation = .horizontal
        actions.alignment = .centerY
        actions.spacing = 10
        NSLayoutConstraint.activate([
            checkup.widthAnchor.constraint(equalToConstant: 150),
            checkUpdates.widthAnchor.constraint(equalTo: checkup.widthAnchor),
            checkUpdates.heightAnchor.constraint(equalTo: checkup.heightAnchor),
        ])
        let copy = NSStackView(views: [eyebrow, title, detail, versionLabel, actions])
        copy.orientation = .vertical
        copy.alignment = .leading
        copy.spacing = 8
        copy.setCustomSpacing(17, after: versionLabel)
        let hero = KikiCardView()
        image.translatesAutoresizingMaskIntoConstraints = false
        copy.translatesAutoresizingMaskIntoConstraints = false
        hero.addSubview(image)
        hero.addSubview(copy)
        NSLayoutConstraint.activate([
            image.leadingAnchor.constraint(equalTo: hero.leadingAnchor, constant: 28), image.centerYAnchor.constraint(equalTo: hero.centerYAnchor), image.widthAnchor.constraint(equalToConstant: 180), image.heightAnchor.constraint(equalToConstant: 180),
            copy.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 32), copy.trailingAnchor.constraint(equalTo: hero.trailingAnchor, constant: -28), copy.centerYAnchor.constraint(equalTo: hero.centerYAnchor),
        ])
        let changes = KikiCardView()
        let changesTitle = kikiLabel("Built for the real world", size: 18, weight: .semibold)
        let changesCopy = kikiLabel("Home guides setup and daily use. Transcripts handles recordings and meetings; Words & Replacements improves results; Settings controls input, privacy, and local models.", size: 13, color: KikiPalette.secondaryText)
        changesCopy.maximumNumberOfLines = 0
        let changeStack = NSStackView(views: [changesTitle, changesCopy])
        changeStack.orientation = .vertical
        changeStack.alignment = .leading
        changeStack.spacing = 8
        changeStack.translatesAutoresizingMaskIntoConstraints = false
        changes.addSubview(changeStack)
        NSLayoutConstraint.activate([
            changeStack.leadingAnchor.constraint(equalTo: changes.leadingAnchor, constant: 20), changeStack.trailingAnchor.constraint(equalTo: changes.trailingAnchor, constant: -20), changeStack.topAnchor.constraint(equalTo: changes.topAnchor, constant: 18), changeStack.bottomAnchor.constraint(equalTo: changes.bottomAnchor, constant: -18),
        ])
        let templetonFooter = TempletonTechnologiesProductFooterView(placement: .about)
        let templetonFooterContainer = NSView()
        templetonFooterContainer.translatesAutoresizingMaskIntoConstraints = false
        templetonFooter.translatesAutoresizingMaskIntoConstraints = false
        templetonFooterContainer.addSubview(templetonFooter)
        let stack = NSStackView(views: [hero, changes, templetonFooterContainer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: leadingAnchor), backdrop.trailingAnchor.constraint(equalTo: trailingAnchor), backdrop.topAnchor.constraint(equalTo: topAnchor), backdrop.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28), stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -28), stack.topAnchor.constraint(equalTo: topAnchor, constant: 28),
            hero.widthAnchor.constraint(equalTo: stack.widthAnchor), hero.heightAnchor.constraint(equalToConstant: 260), changes.widthAnchor.constraint(equalTo: stack.widthAnchor), changes.heightAnchor.constraint(equalToConstant: 150),
            templetonFooterContainer.widthAnchor.constraint(equalTo: stack.widthAnchor),
            templetonFooter.leadingAnchor.constraint(equalTo: templetonFooterContainer.leadingAnchor),
            templetonFooter.trailingAnchor.constraint(equalTo: templetonFooterContainer.trailingAnchor),
            templetonFooter.topAnchor.constraint(equalTo: templetonFooterContainer.topAnchor),
            templetonFooter.bottomAnchor.constraint(equalTo: templetonFooterContainer.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func runCheckup() { onRunCheckup?() }
    @objc private func checkUpdates() { onCheckUpdates?() }
}
