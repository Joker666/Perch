import Foundation

/// Rules for todo text. A todo is one line, so line breaks become spaces.
public enum TodoText {
    /// Trims the ends, turns line breaks and tabs into spaces, and collapses
    /// runs of spaces. Returns nil when nothing is left, which means "no todo".
    public static func clean(_ text: String) -> String? {
        let words = text.split(whereSeparator: \.isWhitespace)
        return words.isEmpty ? nil : words.joined(separator: " ")
    }
}
