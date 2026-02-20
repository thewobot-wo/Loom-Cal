import SwiftUI

/// EventDetailView shows a read-only summary of a calendar event.
/// Edit opens EventEditView, Delete uses an alert for reliability in nested sheets.
struct EventDetailView: View {
    let event: LoomEvent
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var isPresented: Bool

    @State private var showEditSheet = false
    @State private var showDeleteAlert = false

    // MARK: - Computed

    private var startDate: Date {
        Date(timeIntervalSince1970: TimeInterval(event.start) / 1000)
    }

    private var formattedDate: String {
        startDate.formatted(date: .complete, time: .omitted)
    }

    private var formattedTimeRange: String {
        guard !event.isAllDay else { return "All Day" }
        let endDate = startDate.addingTimeInterval(TimeInterval(event.duration) * 60)
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(event.title)
                    .font(.title2)
                    .bold()

                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                    Text(formattedDate)
                }

                if event.isAllDay {
                    Label("All Day", systemImage: "sun.max")
                        .foregroundStyle(.secondary)
                } else {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text(formattedTimeRange)
                    }
                }

                Spacer()

                HStack {
                    Button("Edit") { showEditSheet = true }
                        .buttonStyle(.bordered)

                    Spacer()

                    Button("Delete", role: .destructive) { showDeleteAlert = true }
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
                    Button("Done") { isPresented = false }
                }
            }
            // Use .alert instead of .confirmationDialog — more reliable in nested sheets
            .alert("Delete Event?", isPresented: $showDeleteAlert) {
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
