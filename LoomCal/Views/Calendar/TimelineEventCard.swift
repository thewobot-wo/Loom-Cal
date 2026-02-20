import SwiftUI

/// Fantastical-inspired event card for the day timeline.
/// Displays event title and formatted 12-hour start time.
/// Visual style: rounded rectangle, blue tint, left accent bar, subtle shadow.
struct TimelineEventCard: View {
    let event: LoomEvent
    var onTap: () -> Void = {}

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"   // 12-hour format per locked decision
        return f
    }()

    private var startDate: Date {
        // LoomEvent.start is Int, milliseconds since epoch
        Date(timeIntervalSince1970: TimeInterval(event.start) / 1000)
    }

    private var formattedTime: String {
        Self.timeFormatter.string(from: startDate)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Leading blue accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue)
                    .frame(width: 4)

                // Event content
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(formattedTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

                Spacer(minLength: 0)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.15))
            )
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    // Approximate 60 minutes from now in ms
    let nowMs = Int(Date().timeIntervalSince1970 * 1000)
    let sampleEvent = try! JSONDecoder().decode(LoomEvent.self, from: """
    {
      "_id": "preview-id",
      "calendarId": "personal",
      "title": "Team Standup",
      "start": \(nowMs),
      "duration": 30,
      "timezone": "America/New_York",
      "isAllDay": false
    }
    """.data(using: .utf8)!)

    TimelineEventCard(event: sampleEvent)
        .frame(width: 280, height: 60)
        .padding()
}
