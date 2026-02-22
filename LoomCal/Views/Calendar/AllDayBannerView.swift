import SwiftUI

/// Horizontal strip of all-day event pills above the time grid.
/// Collapses to zero height when there are no all-day events.
struct AllDayBannerView: View {
    let events: [LoomEvent]

    var body: some View {
        if events.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(events, id: \._id) { event in
                        Text(event.title)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LoomColors.eventAccent.opacity(0.12))
                            )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .background(.background)
            Divider()
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        // Non-empty state
        let nowMs = Int(Date().timeIntervalSince1970 * 1000)
        let makeEvent: (String) -> LoomEvent = { title in
            try! JSONDecoder().decode(LoomEvent.self, from: """
            {
              "_id": "\(title)",
              "calendarId": "personal",
              "title": "\(title)",
              "start": \(nowMs),
              "duration": 1440,
              "timezone": "America/New_York",
              "isAllDay": true
            }
            """.data(using: .utf8)!)
        }

        AllDayBannerView(events: [makeEvent("Team Offsite"), makeEvent("Conference Day 1")])

        // Empty state — renders nothing
        AllDayBannerView(events: [])
            .border(Color.red, width: 1)
    }
}
