import Foundation

enum ExactInsertionUndoPlanner {
    static func range(insertedText: String, currentValue: String, selection: NSRange) -> NSRange? {
        guard !insertedText.isEmpty, selection.length == 0 else { return nil }
        let insertedLength = (insertedText as NSString).length
        let value = currentValue as NSString
        guard selection.location >= insertedLength,
              selection.location <= value.length else { return nil }
        let candidate = NSRange(location: selection.location - insertedLength, length: insertedLength)
        guard value.substring(with: candidate) == insertedText else { return nil }
        return candidate
    }
}
