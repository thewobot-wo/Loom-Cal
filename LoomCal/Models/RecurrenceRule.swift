import Foundation

// MARK: - Weekday

/// Days of the week with RRULE abbreviation mapping.
enum Weekday: String, CaseIterable, Comparable, Hashable {
    case monday = "MO"
    case tuesday = "TU"
    case wednesday = "WE"
    case thursday = "TH"
    case friday = "FR"
    case saturday = "SA"
    case sunday = "SU"

    /// Calendar weekday number (1 = Sunday, 2 = Monday, ... 7 = Saturday).
    var calendarWeekday: Int {
        switch self {
        case .sunday:    return 1
        case .monday:    return 2
        case .tuesday:   return 3
        case .wednesday: return 4
        case .thursday:  return 5
        case .friday:    return 6
        case .saturday:  return 7
        }
    }

    /// Create from Calendar weekday number (1 = Sunday ... 7 = Saturday).
    static func from(calendarWeekday: Int) -> Weekday? {
        Self.allCases.first { $0.calendarWeekday == calendarWeekday }
    }

    /// Sorted by calendar order (Monday first for display).
    static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        let order: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
        guard let l = order.firstIndex(of: lhs), let r = order.firstIndex(of: rhs) else { return false }
        return l < r
    }
}

// MARK: - RecurrenceFrequency

enum RecurrenceFrequency: String {
    case daily = "DAILY"
    case weekly = "WEEKLY"
    case monthly = "MONTHLY"
}

// MARK: - RecurrenceRule

/// Represents a recurrence pattern compatible with RFC 5545 RRULE (common subset).
/// Supports DAILY, WEEKLY, MONTHLY with INTERVAL, BYDAY, BYMONTHDAY, UNTIL, COUNT.
struct RecurrenceRule: Equatable {
    let frequency: RecurrenceFrequency
    var interval: Int = 1
    var byDay: Set<Weekday> = []
    var byMonthDay: Int? = nil
    var until: Date? = nil
    var count: Int? = nil

    // MARK: - Factory Methods

    static func daily(interval: Int = 1) -> RecurrenceRule {
        RecurrenceRule(frequency: .daily, interval: interval)
    }

    static func weekly(days: Set<Weekday>, interval: Int = 1) -> RecurrenceRule {
        RecurrenceRule(frequency: .weekly, interval: interval, byDay: days)
    }

    static func weekdays() -> RecurrenceRule {
        RecurrenceRule(frequency: .weekly, interval: 1,
                       byDay: [.monday, .tuesday, .wednesday, .thursday, .friday])
    }

    static func monthly(dayOfMonth: Int, interval: Int = 1) -> RecurrenceRule {
        RecurrenceRule(frequency: .monthly, interval: interval, byMonthDay: dayOfMonth)
    }

    // MARK: - RRULE Parsing

    /// Parse an RRULE string into a RecurrenceRule. Returns nil if FREQ is missing or unsupported.
    static func from(rrule: String) -> RecurrenceRule? {
        var parts: [String: String] = [:]
        for component in rrule.split(separator: ";") {
            let kv = component.split(separator: "=", maxSplits: 1)
            guard kv.count == 2 else { continue }
            parts[String(kv[0])] = String(kv[1])
        }

        guard let freqStr = parts["FREQ"],
              let frequency = RecurrenceFrequency(rawValue: freqStr) else {
            return nil
        }

        var rule = RecurrenceRule(frequency: frequency)

        if let intervalStr = parts["INTERVAL"], let interval = Int(intervalStr), interval > 0 {
            rule.interval = interval
        }

        if let byDayStr = parts["BYDAY"] {
            let days = byDayStr.split(separator: ",").compactMap { Weekday(rawValue: String($0)) }
            rule.byDay = Set(days)
        }

        if let byMonthDayStr = parts["BYMONTHDAY"], let day = Int(byMonthDayStr) {
            rule.byMonthDay = day
        }

        if let untilStr = parts["UNTIL"] {
            rule.until = parseUntilDate(untilStr)
        }

        if let countStr = parts["COUNT"], let count = Int(countStr), count > 0 {
            rule.count = count
        }

        return rule
    }

    /// Parse UNTIL date from RRULE (formats: YYYYMMDDTHHmmssZ or YYYYMMDD).
    private static func parseUntilDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")

        // Try full UTC datetime: 20260301T120000Z
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        if let date = formatter.date(from: string) { return date }

        // Try date-only: 20260301
        formatter.dateFormat = "yyyyMMdd"
        if let date = formatter.date(from: string) { return date }

        return nil
    }

    // MARK: - Display

    /// Human-readable description of the recurrence rule for UI display.
    var displayDescription: String {
        let intervalPrefix: String
        switch frequency {
        case .daily:
            if interval == 1 {
                intervalPrefix = "Repeats daily"
            } else {
                intervalPrefix = "Repeats every \(interval) days"
            }
            return intervalPrefix

        case .weekly:
            if interval == 1 {
                intervalPrefix = "Repeats weekly"
            } else {
                intervalPrefix = "Repeats every \(interval) weeks"
            }
            if byDay.isEmpty {
                return intervalPrefix
            }
            let dayNames = byDay.sorted().map { day -> String in
                switch day {
                case .monday: return "Mon"
                case .tuesday: return "Tue"
                case .wednesday: return "Wed"
                case .thursday: return "Thu"
                case .friday: return "Fri"
                case .saturday: return "Sat"
                case .sunday: return "Sun"
                }
            }
            // Check for weekdays shorthand
            if byDay == Set([.monday, .tuesday, .wednesday, .thursday, .friday]) {
                return "Repeats on weekdays"
            }
            return "\(intervalPrefix) on \(dayNames.joined(separator: ", "))"

        case .monthly:
            if interval == 1 {
                intervalPrefix = "Repeats monthly"
            } else {
                intervalPrefix = "Repeats every \(interval) months"
            }
            if let day = byMonthDay {
                return "\(intervalPrefix) on the \(ordinal(day))"
            }
            return intervalPrefix
        }
    }

    /// Ordinal suffix for day of month (1st, 2nd, 3rd, 4th...).
    private func ordinal(_ n: Int) -> String {
        let suffix: String
        let ones = n % 10
        let tens = (n / 10) % 10
        if tens == 1 {
            suffix = "th"
        } else {
            switch ones {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }

    // MARK: - RRULE Generation

    /// Generate an RRULE string from this rule.
    func toRRULE() -> String {
        var components = ["FREQ=\(frequency.rawValue)"]

        if interval > 1 {
            components.append("INTERVAL=\(interval)")
        }

        if !byDay.isEmpty {
            let sorted = byDay.sorted().map(\.rawValue)
            components.append("BYDAY=\(sorted.joined(separator: ","))")
        }

        if let day = byMonthDay {
            components.append("BYMONTHDAY=\(day)")
        }

        if let until {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            components.append("UNTIL=\(formatter.string(from: until))")
        }

        if let count {
            components.append("COUNT=\(count)")
        }

        return components.joined(separator: ";")
    }

    // MARK: - Date Expansion

    /// Generate occurrence dates from `startDate` through `endDate`, excluding exception dates.
    /// Capped at 365 occurrences as a safety limit.
    func occurrences(from startDate: Date, through endDate: Date, excluding exceptionDates: [Date] = []) -> [Date] {
        let cal = Calendar.current
        let maxOccurrences = 365
        var results: [Date] = []
        var totalGenerated = 0

        // Exception dates normalized to start of day for comparison
        let exceptionStarts = Set(exceptionDates.map { cal.startOfDay(for: $0) })

        switch frequency {
        case .daily:
            var current = startDate
            while current <= endDate && totalGenerated < maxOccurrences {
                if let count, totalGenerated >= count { break }
                if let until, current > until { break }

                if !exceptionStarts.contains(cal.startOfDay(for: current)) {
                    results.append(current)
                }
                totalGenerated += 1
                guard let next = cal.date(byAdding: .day, value: interval, to: current) else { break }
                current = next
            }

        case .weekly:
            let effectiveDays: Set<Weekday>
            if byDay.isEmpty {
                // Default to the weekday of startDate
                let wd = cal.component(.weekday, from: startDate)
                if let day = Weekday.from(calendarWeekday: wd) {
                    effectiveDays = [day]
                } else {
                    effectiveDays = []
                }
            } else {
                effectiveDays = byDay
            }

            // Find the Monday of the week containing startDate
            var weekStart = cal.startOfDay(for: startDate)
            let startWeekday = cal.component(.weekday, from: weekStart)
            // Shift to Monday (weekday 2). If Sunday (1), go back 6 days; otherwise back (weekday - 2) days.
            let daysToMonday = startWeekday == 1 ? 6 : (startWeekday - 2)
            weekStart = cal.date(byAdding: .day, value: -daysToMonday, to: weekStart) ?? weekStart

            var currentWeekMonday = weekStart
            while currentWeekMonday <= endDate && totalGenerated < maxOccurrences {
                for day in effectiveDays.sorted() {
                    // Monday = 0 offset, Tuesday = 1, etc.
                    let dayOffset = day.calendarWeekday >= 2 ? day.calendarWeekday - 2 : 5 + day.calendarWeekday
                    guard let date = cal.date(byAdding: .day, value: dayOffset, to: currentWeekMonday) else { continue }

                    // Apply the time of day from the original startDate
                    let timeComponents = cal.dateComponents([.hour, .minute, .second], from: startDate)
                    guard let dateWithTime = cal.date(bySettingHour: timeComponents.hour ?? 0,
                                                      minute: timeComponents.minute ?? 0,
                                                      second: timeComponents.second ?? 0,
                                                      of: date) else { continue }

                    // Must be on or after the original start and within range
                    guard dateWithTime >= startDate, dateWithTime <= endDate else { continue }
                    if let count, totalGenerated >= count { break }
                    if let until, dateWithTime > until { break }

                    if !exceptionStarts.contains(cal.startOfDay(for: dateWithTime)) {
                        results.append(dateWithTime)
                    }
                    totalGenerated += 1
                }

                if let count, totalGenerated >= count { break }

                guard let nextWeek = cal.date(byAdding: .weekOfYear, value: interval, to: currentWeekMonday) else { break }
                currentWeekMonday = nextWeek
            }

        case .monthly:
            let targetDay = byMonthDay ?? cal.component(.day, from: startDate)
            var components = cal.dateComponents([.year, .month], from: startDate)
            let timeComps = cal.dateComponents([.hour, .minute, .second], from: startDate)

            while totalGenerated < maxOccurrences {
                if let count, totalGenerated >= count { break }

                // Clamp day to last day of month
                guard let year = components.year, let month = components.month else { break }
                let range = cal.range(of: .day, in: .month, for: cal.date(from: components) ?? startDate)
                let clampedDay = min(targetDay, range?.count ?? targetDay)

                let dateComps = DateComponents(year: year, month: month, day: clampedDay,
                                               hour: timeComps.hour, minute: timeComps.minute, second: timeComps.second)
                guard let date = cal.date(from: dateComps) else { break }

                if date > endDate { break }
                if let until, date > until { break }

                if date >= startDate {
                    if !exceptionStarts.contains(cal.startOfDay(for: date)) {
                        results.append(date)
                    }
                    totalGenerated += 1
                }

                // Advance by interval months
                guard let nextMonth = cal.date(byAdding: .month, value: interval, to: date) else { break }
                components = cal.dateComponents([.year, .month], from: nextMonth)
            }
        }

        return results
    }
}
