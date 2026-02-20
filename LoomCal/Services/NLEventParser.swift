import Foundation

/// ParsedEvent holds the result of natural language event text parsing.
struct ParsedEvent {
    /// Cleaned event title with date/time patterns removed.
    let title: String
    /// Detected date/time if found by NSDataDetector, otherwise nil.
    let date: Date?
    /// True when NSDataDetector found a date with a non-midnight time component.
    let hasTime: Bool
}

/// NLEventParser uses NSDataDetector to extract date/time from natural language input
/// and produces a clean event title by removing detected date patterns.
///
/// Example usage:
///   NLEventParser.parse("Dentist 3pm") -> ParsedEvent(title: "Dentist", date: today@15:00, hasTime: true)
///   NLEventParser.parse("Team meeting tomorrow 10am") -> ParsedEvent(title: "Team meeting", ...)
///   NLEventParser.parse("Birthday party") -> ParsedEvent(title: "Birthday party", date: nil, hasTime: false)
struct NLEventParser {

    /// Regex patterns to strip from title after detector match removal.
    private static let timeRegexPatterns: [String] = [
        // "3pm", "10am", "3:30 PM", "10:30am" etc.
        "\\b\\d{1,2}(:\\d{2})?\\s*(am|pm)\\b",
        // Relative day words
        "\\b(today|tomorrow|tonight)\\b"
    ]

    /// Parses a natural language event description and returns title + detected date.
    static func parse(_ input: String) -> ParsedEvent {
        guard !input.trimmingCharacters(in: .whitespaces).isEmpty else {
            return ParsedEvent(title: input, date: nil, hasTime: false)
        }

        // Set up NSDataDetector for date checking
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.date.rawValue
        ) else {
            return ParsedEvent(title: input, date: nil, hasTime: false)
        }

        let nsInput = input as NSString
        let range = NSRange(location: 0, length: nsInput.length)

        var detectedDate: Date? = nil
        var detectedRange: NSRange? = nil
        var hasTime = false

        // Find first date match
        detector.enumerateMatches(
            in: input,
            options: [],
            range: range
        ) { result, _, stop in
            guard let result = result, result.resultType == .date else { return }
            detectedDate = result.date
            detectedRange = result.range
            stop.pointee = true
        }

        // Determine hasTime: detected date exists and has a non-midnight time component
        if let date = detectedDate {
            let cal = Calendar.current
            let components = cal.dateComponents([.hour, .minute], from: date)
            let hour = components.hour ?? 0
            let minute = components.minute ?? 0
            hasTime = !(hour == 0 && minute == 0)
        }

        // Build cleaned title
        var titleNS = nsInput.mutableCopy() as! NSMutableString

        // Remove the detected date range from the string (if found)
        if let detRange = detectedRange {
            titleNS.replaceCharacters(in: detRange, with: "")
        }

        var titleString = titleNS as String

        // Strip residual time/day patterns via regex
        for pattern in timeRegexPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let nsStr = titleString as NSString
                let matchRange = NSRange(location: 0, length: nsStr.length)
                titleString = regex.stringByReplacingMatches(
                    in: titleString,
                    options: [],
                    range: matchRange,
                    withTemplate: ""
                )
            }
        }

        // Clean up extra whitespace
        titleString = titleString
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        // Fallback: if title is empty after cleanup, use original input
        if titleString.isEmpty {
            titleString = input
        }

        return ParsedEvent(title: titleString, date: detectedDate, hasTime: hasTime)
    }
}
