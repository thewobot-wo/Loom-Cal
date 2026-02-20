import SwiftUI

/// Red horizontal line with dot indicator showing the current time on the timeline.
/// Uses TimelineView(.periodic) to recompute position every 60 seconds.
/// The parent (DayTimelineView) positions this view via .offset(y:).
struct NowIndicatorView: View {
    let pointsPerHour: CGFloat

    var body: some View {
        // TimelineView ensures the offset recomputes every 60 seconds
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let yOffset = currentTimeYOffset(for: context.date)
            ZStack(alignment: .leading) {
                // Red dot on leading edge
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .offset(x: 0, y: yOffset)

                // Red horizontal line spanning the full width
                Rectangle()
                    .fill(Color.red)
                    .frame(height: 1)
                    .offset(y: yOffset)
            }
        }
    }

    /// Computes the y-offset for the given date based on hour and minute.
    private func currentTimeYOffset(for date: Date) -> CGFloat {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return CGFloat(hour * 60 + minute) / 60.0 * pointsPerHour
    }
}

#Preview {
    NowIndicatorView(pointsPerHour: 60)
        .frame(width: 300, height: 1440)
}
