import Foundation
import UserNotifications

/// Singleton service for scheduling local notifications for events and tasks.
/// Inherits NSObject for UNUserNotificationCenterDelegate conformance, which is
/// required to display notification banners while the app is in the foreground.
final class NotificationService: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let leadTimeKey = "notificationLeadMinutes"

    /// Lead time in minutes before an event to fire the notification.
    var eventLeadMinutes: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: leadTimeKey)
            return stored > 0 ? stored : 15
        }
        set {
            UserDefaults.standard.set(newValue, forKey: leadTimeKey)
        }
    }

    private override init() {
        super.init()
        // Set delegate so notifications display even when the app is in the foreground.
        center.delegate = self
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Allow banners + sound while the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Permission

    /// Requests notification authorization. Safe to call multiple times — no-ops if already determined.
    func requestPermission() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            print("[NotificationService] Permission \(granted ? "granted" : "denied")")
        } catch {
            print("[NotificationService] Permission error: \(error)")
        }
    }

    // MARK: - Event Notifications

    /// Cancels existing event notifications and schedules new ones for upcoming events.
    /// Only schedules for non-all-day events starting within the next 48 hours.
    func rescheduleEventNotifications(_ events: [LoomEvent]) {
        let prefix = "event-"
        removeNotifications(withPrefix: prefix)

        let now = Date()
        let leadMinutes = eventLeadMinutes
        let cutoff = now.addingTimeInterval(48 * 60 * 60)

        for event in events {
            guard !event.isAllDay else { continue }

            let startDate = Date(timeIntervalSince1970: TimeInterval(event.start) / 1000)
            let fireDate = startDate.addingTimeInterval(TimeInterval(-leadMinutes * 60))

            guard fireDate > now, startDate <= cutoff else { continue }

            let content = UNMutableNotificationContent()
            content.title = event.title
            content.body = formatEventBody(startDate: startDate, leadMinutes: leadMinutes)
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: "\(prefix)\(event._id)",
                content: content,
                trigger: trigger
            )
            center.add(request) { error in
                if let error {
                    print("[NotificationService] Failed to schedule event: \(error)")
                }
            }
        }
    }

    // MARK: - Task Notifications

    /// Cancels existing task notifications and schedules new ones for incomplete tasks with due dates.
    /// Tasks with hasDueTime=true fire at the due time; hasDueTime=false fire at 9:00 AM on the due date.
    func rescheduleTaskNotifications(_ tasks: [LoomTask]) {
        let prefix = "task-"
        removeNotifications(withPrefix: prefix)

        let now = Date()

        for task in tasks {
            guard !task.completed, let dueDateMs = task.dueDate else { continue }

            let dueDate = Date(timeIntervalSince1970: TimeInterval(dueDateMs) / 1000)

            let fireDate: Date
            if task.hasDueTime {
                fireDate = dueDate
            } else {
                var components = Calendar.current.dateComponents(
                    [.year, .month, .day],
                    from: dueDate
                )
                components.hour = 9
                components.minute = 0
                fireDate = Calendar.current.date(from: components) ?? dueDate
            }

            guard fireDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = task.title
            content.body = task.hasDueTime ? "Due at \(formatTime(fireDate))" : "Due today"
            content.sound = .default

            let triggerComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

            let request = UNNotificationRequest(
                identifier: "\(prefix)\(task._id)",
                content: content,
                trigger: trigger
            )
            center.add(request) { error in
                if let error {
                    print("[NotificationService] Failed to schedule task: \(error)")
                }
            }
        }
    }

    // MARK: - Helpers

    private func removeNotifications(withPrefix prefix: String) {
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            if !ids.isEmpty {
                self.center.removePendingNotificationRequests(withIdentifiers: ids)
            }
        }
    }

    private func formatEventBody(startDate: Date, leadMinutes: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let timeStr = formatter.string(from: startDate)
        return "Starts at \(timeStr) (in \(leadMinutes) min)"
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
