import Foundation

/// Sanitizes a user-supplied title into a filesystem-safe path component,
/// falling back to `fallback` when nothing usable remains.
func kikiSafeFileComponent(_ value: String, fallback: String) -> String {
    let cleaned = value.replacingOccurrences(
        of: "[^A-Za-z0-9._-]+",
        with: "-",
        options: .regularExpression
    )
    let result = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    return result.isEmpty ? fallback : result
}
