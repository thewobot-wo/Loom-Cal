import SwiftUI

/// Loom's Seurat-inspired warm color palette.
/// Replaces system .blue/.orange with intentional coral/gold/sage tones.
enum LoomColors {
    // MARK: - Core Palette

    /// Warm coral — primary accent for today highlights, selected dates
    static let coral = Color(red: 0.87, green: 0.45, blue: 0.35)

    /// Warm gold — secondary accent for time-block events
    static let gold = Color(red: 0.85, green: 0.72, blue: 0.40)

    /// Muted sage — tertiary accent for task indicators
    static let sage = Color(red: 0.55, green: 0.72, blue: 0.55)

    /// Blue-gray — default event color
    static let eventDefault = Color(red: 0.55, green: 0.65, blue: 0.78)

    // MARK: - Semantic Aliases

    /// Today number text, today circle stroke
    static let todayAccent = coral

    /// Selected date circle fill
    static let selectedDateFill = coral

    /// Default calendar event accent bar + background tint
    static let eventAccent = eventDefault

    /// Time-block event accent bar (task-linked events)
    static let timeBlockAccent = gold

    /// Event dot on mini-month calendar
    static let eventDot = coral

    /// Task dot on calendar headers
    static let taskDot = gold

    /// "Show all" links, undo buttons, count badges
    static let interactiveText = coral

    // MARK: - Platform Backgrounds

    /// Sidebar background on macOS, system background on iOS
    static var sidebarBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(.systemBackground)
        #endif
    }

    /// Main content background
    static var contentBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(.systemBackground)
        #endif
    }
}

// MARK: - UIKit Color Equivalents (iOS only)

#if canImport(UIKit)
import UIKit

extension LoomColors {
    static let coralUI = UIColor(red: 0.87, green: 0.45, blue: 0.35, alpha: 1.0)
    static let eventDefaultUI = UIColor(red: 0.55, green: 0.65, blue: 0.78, alpha: 1.0)
}
#endif
