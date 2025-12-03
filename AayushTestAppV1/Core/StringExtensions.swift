import Foundation

/// String extension providing common string manipulation utilities.
///
/// **Purpose**: Reduces code duplication across the codebase by providing
/// reusable string manipulation methods, particularly for style hints and
/// user input validation.
extension String {
    /// Returns a trimmed version of the string (whitespace and newlines removed).
    ///
    /// **Usage**: Commonly used for style hints, user input, and text fields
    /// to ensure consistent trimming behavior across the app.
    ///
    /// - Returns: Trimmed string, or empty string if all characters are whitespace
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Returns the string if it's non-empty after trimming, otherwise nil.
    ///
    /// **Usage**: Perfect for optional style hints and user input where empty
    /// strings should be treated as nil.
    ///
    /// - Returns: Trimmed string if non-empty, nil otherwise
    ///
    /// **Example**:
    /// ```swift
    /// let hint: String? = "  ".nonEmptyTrimmed  // nil
    /// let hint2: String? = " hello ".nonEmptyTrimmed  // "hello"
    /// ```
    var nonEmptyTrimmed: String? {
        let trimmed = self.trimmed
        return trimmed.isEmpty ? nil : trimmed
    }
    
    /// Checks if the string is non-empty after trimming.
    ///
    /// **Usage**: Useful for validation checks before processing user input.
    ///
    /// - Returns: `true` if the trimmed string is non-empty, `false` otherwise
    var hasNonEmptyContent: Bool {
        !trimmed.isEmpty
    }
}

/// Helper functions for style hint processing.
///
/// **Purpose**: Consolidates style hint validation and combination logic
/// that was previously duplicated across multiple files.
enum StyleHintHelper {
    /// Combines multiple style hints into a single string, filtering out empty ones.
    ///
    /// **Usage**: Used when combining contact style hints, tone profiles, and
    /// custom context into a single style hint for LLM requests.
    ///
    /// - Parameters:
    ///   - hints: Array of optional style hint strings
    /// - Returns: Combined hint string, or nil if all hints are empty
    ///
    /// **Example**:
    /// ```swift
    /// let combined = StyleHintHelper.combine([
    ///     contact.styleHint,
    ///     customContext,
    ///     toneProfile.map { "Tone profile: \($0)" }
    /// ])
    /// ```
    static func combine(_ hints: [String?]) -> String? {
        let nonEmptyHints = hints.compactMap { $0?.nonEmptyTrimmed }
        return nonEmptyHints.isEmpty ? nil : nonEmptyHints.joined(separator: "\n\n")
    }
    
    /// Combines multiple style hints with optional prefix formatting.
    ///
    /// - Parameters:
    ///   - hints: Array of tuples containing (hint, prefix) where prefix is prepended if hint is non-empty
    /// - Returns: Combined hint string, or nil if all hints are empty
    ///
    /// **Example**:
    /// ```swift
    /// let combined = StyleHintHelper.combineWithPrefixes([
    ///     (toneProfile, "Tone profile: "),
    ///     (customContext, nil)
    /// ])
    /// ```
    static func combineWithPrefixes(_ hints: [(hint: String?, prefix: String?)]) -> String? {
        let formattedHints = hints.compactMap { hint, prefix -> String? in
            guard let trimmed = hint?.nonEmptyTrimmed else { return nil }
            if let prefix = prefix {
                return "\(prefix)\(trimmed)"
            }
            return trimmed
        }
        return formattedHints.isEmpty ? nil : formattedHints.joined(separator: "\n\n")
    }
    
    /// Overload that accepts String (non-optional) hints for convenience.
    ///
    /// This allows passing `String` values directly without explicit conversion to `String?`.
    static func combineWithPrefixes(_ hints: [(hint: String, prefix: String?)]) -> String? {
        let optionalHints: [(hint: String?, prefix: String?)] = hints.map { ($0, $1) }
        return combineWithPrefixes(optionalHints)
    }
}

