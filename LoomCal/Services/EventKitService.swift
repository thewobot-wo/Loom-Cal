import EventKit
import SwiftUI

@MainActor
class EventKitService: ObservableObject {
    let store = EKEventStore()

    @Published var authStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @Published var availableCalendars: [EKCalendar] = []
    @Published var selectedCalendarIdentifiers: Set<String> = []

    var isAuthorized: Bool { authStatus == .fullAccess }

    // MARK: - Permission

    func requestAccess() async {
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .notDetermined else {
            authStatus = status
            if status == .fullAccess {
                loadCalendars()
            }
            return
        }
        do {
            let granted = try await store.requestFullAccessToEvents()
            authStatus = granted ? .fullAccess : .denied
            if granted {
                loadCalendars()
            }
        } catch {
            // System-level restriction (MDM, etc.) — treat as denied
            authStatus = .denied
        }
        // On denial: app continues with Convex-only events. No retry, no nag.
    }

    // MARK: - Calendar Discovery

    func loadCalendars() {
        guard isAuthorized else { return }
        availableCalendars = store.calendars(for: .event)
        loadSelectedCalendars()
    }

    // MARK: - Calendar Visibility (UserDefaults)

    private let selectedCalendarsKey = "selectedAppleCalendarIdentifiers"

    func loadSelectedCalendars() {
        if let saved = UserDefaults.standard.array(forKey: selectedCalendarsKey) as? [String] {
            selectedCalendarIdentifiers = Set(saved)
        } else {
            // First time: select all calendars by default
            selectedCalendarIdentifiers = Set(availableCalendars.map { $0.calendarIdentifier })
            saveSelectedCalendars()
        }
    }

    func toggleCalendar(_ calendar: EKCalendar) {
        if selectedCalendarIdentifiers.contains(calendar.calendarIdentifier) {
            selectedCalendarIdentifiers.remove(calendar.calendarIdentifier)
        } else {
            selectedCalendarIdentifiers.insert(calendar.calendarIdentifier)
        }
        saveSelectedCalendars()
    }

    func saveSelectedCalendars() {
        UserDefaults.standard.set(Array(selectedCalendarIdentifiers), forKey: selectedCalendarsKey)
    }

    // MARK: - Event Fetching

    func fetchEvents(from startDate: Date, to endDate: Date) -> [EKEvent] {
        guard isAuthorized else { return [] }
        let calendars = availableCalendars.filter {
            selectedCalendarIdentifiers.contains($0.calendarIdentifier)
        }
        guard !calendars.isEmpty else { return [] }
        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        return store.events(matching: predicate)
    }
}
