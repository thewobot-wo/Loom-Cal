import SwiftUI
import ConvexMobile

// Phase 1 proof-of-concept dashboard demonstrating:
// 1. ConvexClient connects and events:list subscription works in real-time
// 2. EventKit permission request fires on launch with graceful denial handling
// 3. Both Convex and Apple Calendar data sources coexist without conflict
// Proper calendar UI is Phase 2's responsibility — this view is intentionally minimal.
struct ContentView: View {
    @State private var events: [LoomEvent] = []
    @EnvironmentObject var eventKitService: EventKitService

    var body: some View {
        NavigationStack {
            List {
                // Convex events section
                Section("Convex Events") {
                    if events.isEmpty {
                        Text("No events yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(events, id: \._id) { event in
                            VStack(alignment: .leading) {
                                Text(event.title)
                                    .font(.headline)
                                Text("Duration: \(event.duration) min")
                                    .font(.caption)
                            }
                        }
                    }
                }

                // EventKit status section
                Section("Apple Calendar") {
                    switch eventKitService.authStatus {
                    case .fullAccess:
                        let todayEvents = eventKitService.fetchEvents(
                            from: Calendar.current.startOfDay(for: Date()),
                            to: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
                        )
                        Text("\(todayEvents.count) events today")
                        Text("\(eventKitService.selectedCalendarIdentifiers.count) calendars selected")
                            .font(.caption)
                    case .denied, .restricted, .writeOnly:
                        Text("Calendar access not granted")
                            .foregroundStyle(.secondary)
                        Text("Loom Cal works with Convex events only")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .notDetermined:
                        Text("Requesting access...")
                            .foregroundStyle(.secondary)
                    @unknown default:
                        Text("Unknown status")
                    }
                }
            }
            .navigationTitle("Loom Cal")
        }
        .task {
            // Request EventKit access
            await eventKitService.requestAccess()
        }
        .task {
            // Subscribe to Convex events
            for await result: [LoomEvent] in convex
                .subscribe(to: "events:list")
                .replaceError(with: [])
                .values
            {
                self.events = result
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(EventKitService())
}
