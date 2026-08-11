import AppKit
import ApplicationServices

struct AppContextSnapshot: Codable, Equatable {
    let processIdentifier: pid_t
    let bundleIdentifier: String?
    let applicationName: String?
    let capturedAt: Date
    let isSecureField: Bool
    let privateSessionActive: Bool

    var displayName: String? { applicationName ?? bundleIdentifier }
    @MainActor
    var privacyPolicy: PrivateSessionPolicy {
        PrivateSessionPolicy.resolved(
            privateSessionActive: privateSessionActive,
            privateContext: isSecureField || PrivateZoneStore.shared.contains(bundleIdentifier: bundleIdentifier)
        )
    }

    @MainActor
    var isPrivate: Bool { !privacyPolicy.historyEnabled }

    @MainActor
    static func capture() -> AppContextSnapshot {
        let app = NSWorkspace.shared.frontmostApplication
        let pid = app?.processIdentifier ?? 0
        return AppContextSnapshot(
            processIdentifier: pid,
            bundleIdentifier: app?.bundleIdentifier,
            applicationName: app?.localizedName,
            capturedAt: Date(),
            isSecureField: focusedElementSubrole(pid: pid) == kAXSecureTextFieldSubrole as String,
            privateSessionActive: PrivateSessionController.shared.isActive
        )
    }

    func markingPrivateSessionActive() -> AppContextSnapshot {
        AppContextSnapshot(
            processIdentifier: processIdentifier,
            bundleIdentifier: bundleIdentifier,
            applicationName: applicationName,
            capturedAt: capturedAt,
            isSecureField: isSecureField,
            privateSessionActive: true
        )
    }

    @MainActor
    static func caretScreenRect() -> CGRect? {
        guard AXIsProcessTrusted(),
              let app = NSWorkspace.shared.frontmostApplication
        else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
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

        var boundsValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &boundsValue
        ) == .success,
        let boundsValue,
        CFGetTypeID(boundsValue) == AXValueGetTypeID()
        else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(unsafeBitCast(boundsValue, to: AXValue.self), .cgRect, &rect),
              !rect.isNull,
              !rect.isInfinite
        else { return nil }
        return rect
    }

    @MainActor
    static func selectedTextFromFrontmostApplication() -> String? {
        guard AXIsProcessTrusted(),
              let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success,
        let focusedValue else { return nil }
        let focused = unsafeBitCast(focusedValue, to: AXUIElement.self)
        var selectedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focused,
            kAXSelectedTextAttribute as CFString,
            &selectedValue
        ) == .success,
        let selected = selectedValue as? String else { return nil }
        let trimmed = selected.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func focusedElementSubrole(pid: pid_t) -> String? {
        guard pid != 0, AXIsProcessTrusted() else { return nil }
        let appElement = AXUIElementCreateApplication(pid)
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success,
        let focusedValue
        else { return nil }
        let element = unsafeBitCast(focusedValue, to: AXUIElement.self)
        var roleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSubroleAttribute as CFString,
            &roleValue
        ) == .success
        else { return nil }
        return roleValue as? String
    }
}
