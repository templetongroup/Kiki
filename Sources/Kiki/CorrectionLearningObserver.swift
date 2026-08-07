import AppKit
import ApplicationServices

@MainActor
final class CorrectionLearningObserver {
    static let shared = CorrectionLearningObserver()

    struct Anchor {
        let element: AXUIElement
        let selectedRange: CFRange
    }

    private struct Observation {
        let id: UUID
        let element: AXUIElement
        let processIdentifier: pid_t
        let bundleIdentifier: String?
        let insertedText: String
        let expectedRange: NSRange
        var baseline: String?
        var expiresAt: Date
        var timer: Timer?
    }

    private var observations: [UUID: Observation] = [:]

    func captureAnchor(context: AppContextSnapshot) -> Anchor? {
        guard AXIsProcessTrusted(), context.processIdentifier != 0 else { return nil }
        let appElement = AXUIElementCreateApplication(context.processIdentifier)
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success,
        let focusedValue
        else { return nil }
        let element = unsafeBitCast(focusedValue, to: AXUIElement.self)
        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeValue
        ) == .success,
        let rangeValue,
        CFGetTypeID(rangeValue) == AXValueGetTypeID()
        else { return nil }
        var range = CFRange()
        guard AXValueGetValue(unsafeBitCast(rangeValue, to: AXValue.self), .cfRange, &range) else {
            return nil
        }
        return Anchor(element: element, selectedRange: range)
    }

    func observe(insertedText: String, anchor: Anchor, context: AppContextSnapshot?) {
        let id = UUID()
        let timer = Timer(timeInterval: 0.8, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll(id: id) }
        }
        var observation = Observation(
            id: id,
            element: anchor.element,
            processIdentifier: context?.processIdentifier ?? 0,
            bundleIdentifier: context?.bundleIdentifier,
            insertedText: insertedText,
            expectedRange: NSRange(location: anchor.selectedRange.location, length: (insertedText as NSString).length),
            baseline: nil,
            expiresAt: Date().addingTimeInterval(15),
            timer: timer
        )
        observations[id] = observation
        RunLoop.main.add(timer, forMode: .common)

        // Capture after the synthetic paste has had time to land.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self, var current = self.observations[id] else { return }
            current.baseline = self.stringValue(of: current.element)
            observation = current
            self.observations[id] = observation
        }
    }

    private func poll(id: UUID) {
        guard var observation = observations[id] else { return }
        guard Date() < observation.expiresAt,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == observation.processIdentifier,
              let current = stringValue(of: observation.element)
        else {
            stop(id: id)
            return
        }
        guard let baseline = observation.baseline else {
            observation.baseline = current
            observations[id] = observation
            return
        }
        guard baseline != current else { return }

        let change = TextChange.between(old: baseline, new: current)
        let touchesInsertion = change.oldRange.length == 0
            ? change.oldRange.location >= observation.expectedRange.location &&
                change.oldRange.location <= NSMaxRange(observation.expectedRange)
            : change.oldRange.intersection(observation.expectedRange) != nil
        if touchesInsertion,
           let pair = CorrectionPair.extract(
               originalInsertion: observation.insertedText,
               oldValue: baseline,
               newValue: current,
               change: change
           ) {
            CorrectionMemoryStore.shared.suggest(
                heard: pair.heard,
                replacement: pair.replacement,
                bundleIdentifier: observation.bundleIdentifier
            )
            stop(id: id)
            return
        }

        // Ignore typing outside the inserted range while still allowing a later correction.
        observation.baseline = current
        observations[id] = observation
    }

    private func stringValue(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &value
        ) == .success
        else { return nil }
        return value as? String
    }

    private func stop(id: UUID) {
        observations[id]?.timer?.invalidate()
        observations.removeValue(forKey: id)
    }
}

private struct TextChange {
    let oldRange: NSRange
    let newRange: NSRange
    let oldText: String
    let newText: String

    static func between(old: String, new: String) -> TextChange {
        let oldChars = Array(old)
        let newChars = Array(new)
        var prefix = 0
        while prefix < oldChars.count,
              prefix < newChars.count,
              oldChars[prefix] == newChars[prefix] {
            prefix += 1
        }
        var suffix = 0
        while suffix < oldChars.count - prefix,
              suffix < newChars.count - prefix,
              oldChars[oldChars.count - 1 - suffix] == newChars[newChars.count - 1 - suffix] {
            suffix += 1
        }
        let oldSlice = oldChars[prefix..<(oldChars.count - suffix)]
        let newSlice = newChars[prefix..<(newChars.count - suffix)]
        let utf16Location = String(oldChars[..<prefix]).utf16.count
        let oldText = String(oldSlice)
        return TextChange(
            oldRange: NSRange(location: utf16Location, length: oldText.utf16.count),
            newRange: NSRange(location: utf16Location, length: String(newSlice).utf16.count),
            oldText: oldText,
            newText: String(newSlice)
        )
    }
}

private struct CorrectionPair {
    let heard: String
    let replacement: String

    static func extract(
        originalInsertion: String,
        oldValue: String,
        newValue: String,
        change: TextChange
    ) -> CorrectionPair? {
        let oldWord = word(around: change.oldRange, in: oldValue)
        let newWord = word(around: change.newRange, in: newValue)
        let old = (oldWord ?? change.oldText).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        let new = (newWord ?? change.newText).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard !old.isEmpty,
              !new.isEmpty,
              old.count <= 80,
              new.count <= 80,
              old.rangeOfCharacter(from: .letters) != nil,
              new.rangeOfCharacter(from: .letters) != nil,
              originalInsertion.localizedCaseInsensitiveContains(old)
        else { return nil }
        return CorrectionPair(heard: old, replacement: new)
    }

    private static func word(around change: NSRange, in value: String) -> String? {
        let nsValue = value as NSString
        guard let regex = try? NSRegularExpression(pattern: "[\\p{L}\\p{M}’'-]+") else { return nil }
        let matches = regex.matches(in: value, range: NSRange(location: 0, length: nsValue.length))
        let location = change.location
        guard let match = matches.first(where: {
            location >= $0.range.location && location <= NSMaxRange($0.range)
        }) else { return nil }
        return nsValue.substring(with: match.range)
    }
}
