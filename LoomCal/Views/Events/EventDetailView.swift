import SwiftUI

/// Edit mode for recurring event operations.
enum RecurrenceEditMode {
    case single  // Edit/delete this occurrence only
    case all     // Edit/delete the entire series
}

/// EventDetailView shows a read-only summary of a calendar event.
/// Edit opens EventEditView, Delete uses an alert for reliability in nested sheets.
struct EventDetailView: View {
    let event: LoomEvent
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var isPresented: Bool

    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @State private var showEditChoiceAlert = false
    @State private var editMode: RecurrenceEditMode = .all

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

                // Recurrence badge
                if event.isRecurring,
                   let rruleStr = event.rrule,
                   let rule = RecurrenceRule.from(rrule: rruleStr) {
                    HStack {
                        Image(systemName: "repeat")
                            .foregroundStyle(.secondary)
                        Text(rule.displayDescription)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack {
                    Button("Edit") {
                        if event.isRecurring || event.isVirtualOccurrence {
                            showEditChoiceAlert = true
                        } else {
                            showEditSheet = true
                        }
                    }
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
            // Delete alert — branches for recurring vs non-recurring
            .alert(
                (event.isRecurring || event.isVirtualOccurrence) ? "Delete Recurring Event?" : "Delete Event?",
                isPresented: $showDeleteAlert
            ) {
                if event.isRecurring || event.isVirtualOccurrence {
                    Button("This Event", role: .destructive) {
                        Task {
                            try? await viewModel.addExceptionDate(
                                event: event,
                                occurrenceDate: startDate
                            )
                            isPresented = false
                        }
                    }
                    Button("All Events", role: .destructive) {
                        Task {
                            try? await viewModel.deleteRecurringSeries(event: event)
                            isPresented = false
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } else {
                    Button("Delete", role: .destructive) {
                        Task {
                            try? await viewModel.deleteEvent(id: event._id)
                            isPresented = false
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }
            } message: {
                if event.isRecurring || event.isVirtualOccurrence {
                    Text("Do you want to delete this event or all events in the series?")
                } else {
                    Text("\"\(event.title)\" will be permanently deleted.")
                }
            }
            // Edit choice alert — for recurring events
            .alert("Edit Recurring Event?", isPresented: $showEditChoiceAlert) {
                Button("This Event") {
                    editMode = .single
                    showEditSheet = true
                }
                Button("All Events") {
                    editMode = .all
                    showEditSheet = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Do you want to edit this event or all events in the series?")
            }
            .sheet(isPresented: $showEditSheet) {
                EventEditView(
                    event: event,
                    viewModel: viewModel,
                    isPresented: $showEditSheet,
                    isDetailPresented: $isPresented,
                    editMode: (event.isRecurring || event.isVirtualOccurrence) ? editMode : .all
                )
            }
        }
    }
}
