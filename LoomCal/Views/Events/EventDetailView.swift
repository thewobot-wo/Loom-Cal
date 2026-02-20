import SwiftUI

/// EventDetailView shows a read-only summary of a calendar event.
/// It provides Edit (opens EventEditView) and Delete (with confirmationDialog) actions.
/// Presented as a sheet when the user taps an event card in DayTimelineView.
struct EventDetailView: View {
    let event: LoomEvent
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var isPresented: Bool

    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false

    // MARK: - Computed formatting

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        let startDate = Date(timeIntervalSince1970: TimeInterval(event.start) / 1000)
        return formatter.string(from: startDate)
    }

    private var formattedTimeRange: String {
        guard !event.isAllDay else { return "All Day" }
        let startDate = Date(timeIntervalSince1970: TimeInterval(event.start) / 1000)
        let endDate = startDate.addingTimeInterval(TimeInterval(event.duration) * 60)

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // Event title — large, bold
                Text(event.title)
                    .font(.title2)
                    .bold()

                // Date
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                    Text(formattedDate)
                        .foregroundStyle(.primary)
                }

                // Time range (or All Day indicator)
                if event.isAllDay {
                    Label("All Day", systemImage: "sun.max")
                        .foregroundStyle(.secondary)
                } else {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text(formattedTimeRange)
                            .foregroundStyle(.primary)
                    }
                }

                Spacer()

                // Action buttons
                HStack {
                    Button("Edit") {
                        showEditSheet = true
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Delete", role: .destructive) {
                        showDeleteConfirm = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .navigationTitle("Event Details")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .confirmationDialog(
                "Delete this event?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task {
                        try? await viewModel.deleteEvent(id: event._id)
                        isPresented = false
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("\"\(event.title)\" will be permanently deleted.")
            }
            .sheet(isPresented: $showEditSheet) {
                EventEditView(
                    event: event,
                    viewModel: viewModel,
                    isPresented: $showEditSheet,
                    isDetailPresented: $isPresented
                )
            }
        }
    }
}
