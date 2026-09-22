import AppKit

@main
struct TranscriptReaderTests {
    @MainActor static func main() {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 500), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        let scroll = NSScrollView()
        let reader = TranscriptReaderView()
        guard reader.autoresizingMask.contains(.width) else {
            fatalError("FAIL: reader does not follow the clip view width when embedded")
        }
        reader.isEditable = false
        reader.isSelectable = true
        reader.font = .systemFont(ofSize: 13.5)
        reader.textColor = .labelColor
        reader.textContainerInset = NSSize(width: 10, height: 10)
        scroll.documentView = reader
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let root = window.contentView!
        root.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: root.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])
        root.layoutSubtreeIfNeeded()
        reader.string = "## Summary\nAn important meeting.\n\n## Transcript\n" + String(repeating: "Speaker: A complete line of meeting transcription.\n", count: 1600)
        for width in [340.0, 620.0, 360.0] {
            window.setContentSize(NSSize(width: width, height: 500))
            root.layoutSubtreeIfNeeded()
            reader.layoutManager?.ensureLayout(for: reader.textContainer!)
            let documentWidth = reader.frame.width
            guard documentWidth > 300, documentWidth <= scroll.contentSize.width + 1 else {
                fatalError("FAIL: transcript document width \(documentWidth), viewport \(scroll.contentSize.width)")
            }
            guard reader.frame.height > scroll.contentSize.height else {
                fatalError("FAIL: long transcript has no scrollable document height")
            }
            reader.scrollToBeginningOfDocument(nil)
            guard reader.visibleRect.minY <= 10 else { fatalError("FAIL: summary not at top: document \(reader.frame), visible \(reader.visibleRect), container \(reader.textContainer!.containerSize)") }
            reader.scrollToEndOfDocument(nil)
            guard reader.visibleRect.maxY >= reader.frame.height - 1 else { fatalError("FAIL: transcript end unreachable") }
        }
        print("PASS: long transcript wraps, resizes, and scrolls from summary to end")
    }
}
