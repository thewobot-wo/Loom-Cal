import SwiftUI
import ConvexMobile

// Proof-of-concept view demonstrating:
// 1. ConvexClient connects to the deployed backend
// 2. Subscription to events:list works with async/await pattern
// 3. LoomEvent Decodable struct decodes correctly including @ConvexInt fields
// Source: https://docs.convex.dev/quickstart/swift (Pattern 3: async/await subscription)
struct ContentView: View {
    @State private var events: [LoomEvent] = []
    @State private var connectionStatus: String = "Connecting..."

    var body: some View {
        NavigationStack {
            VStack {
                Text(connectionStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                if events.isEmpty {
                    Spacer()
                    Text("No events yet")
                        .foregroundStyle(.secondary)
                    Text("Add events via Convex Dashboard to test real-time sync")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Spacer()
                } else {
                    List(events, id: \._id) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title)
                                .font(.headline)
                            HStack {
                                Text("Start: \(event.start)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(event.duration) min")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Loom Cal")
        }
        .task {
            connectionStatus = "Connected"
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
}
