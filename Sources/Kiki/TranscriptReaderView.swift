import AppKit

/// The scrollable document shared by the transcript library.
final class TranscriptReaderView: NSTextView {
    override init(frame frameRect: NSRect = .zero) {
        super.init(frame: frameRect)
        configureScrolling()
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        configureScrolling()
    }

    private func configureScrolling() {
        // Embedded libraries are constructed at zero size, then reparented into
        // the workbench. The document must follow the clip view, not retain its
        // initial zero width while its accessibility value contains the text.
        autoresizingMask = [.width]
        isVerticallyResizable = true
        isHorizontallyResizable = false
        minSize = .zero
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textContainer?.widthTracksTextView = true
        textContainer?.heightTracksTextView = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
