import SwiftUI

/// EventEditView provides an editable form pre-filled with the existing event's data.
/// On save, it calls viewModel.updateEvent() with only the changed fields.
/// Presented as a nested sheet from EventDetailView.
struct EventEditView: View {
    let event: LoomEvent
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var isPresented: Bool
    /// Binding to the parent EventDetailView's isPresented — dismiss both on successful save.
    @Binding var isDetailPresented: Bool

    @Environment(\.dismiss) private var dismiss

    // MARK: - State (pre-filled from event)

    @State private var title: String
    @State private var eventDate: Date
    @State private var startTime: Date
    @State private var durationMinutes: Int
    @State private var isAllDay: Bool
    @State private var saveError: String? = nil

    // MARK: - Duration options

    private let durationOptions: [(label: String, minutes: Int)] = [
        ("15 min", 15),
        ("30 min", 30),
        ("45 min", 45),
        ("1 hour", 60),
        ("1.5 hours", 90),
        ("2 hours", 120)
    ]

    // MARK: - Init

    init(
        event: LoomEvent,
        viewModel: CalendarViewModel,
        isPresented: Binding<Bool>,
        isDetailPresented: Binding<Bool>
    ) {
        self.event = event
        self.viewModel = viewModel
        self._isPresented = isPresented
        self._isDetailPresented = isDetailPresented

        // Pre-fill all fields from the existing event
        let startDate = Date(timeIntervalSince1970: TimeInterval(event.start) / 1000)
        self._title = State(initialValue: event.title)
        self._eventDate = State(initialValue: startDate)
        self._startTime = State(initialValue: startDate)
        self._durationMinutes = State(initialValue: event.duration)
        self._isAllDay = State(initialValue: event.isAllDay)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // Detail fields only — no NL input field (edit context, not creation)
                Section("Details") {
                    TextField("Title", text: $title)

                    DatePicker("Date", selection: $eventDate, displayedComponents: .date)
                        .datePickerStyle(.compact)

                    if !isAllDay {
                        DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)

                        Picker("Duration", selection: $durationMinutes) {
                            ForEach(durationOptions, id: \.minutes) { option in
                                Text(option.label).tag(option.minutes)
                            }
                        }
                    }

                    Toggle("All Day", isOn: $isAllDay)
                }

                if let error = saveError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    // MARK: - Actions

    /// Compares current values against the original event and calls updateEvent() for changed fields.
    private func saveChanges() {
        // Combine date + time fields into final start Date
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: eventDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: startTime)

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = isAllDay ? 0 : (timeComponents.hour ?? 0)
        combined.minute = isAllDay ? 0 : (timeComponents.minute ?? 0)
        combined.second = 0

        let finalStart = calendar.date(from: combined) ?? eventDate
        let originalStart = Date(timeIntervalSince1970: TimeInterval(event.start) / 1000)

        // Build changed-fields-only update call
        let newTitle: String? = (title != event.title) ? title : nil
        let newStart: Date? = (abs(finalStart.timeIntervalSince(originalStart)) > 30) ? finalStart : nil
        let newDuration: Int? = (durationMinutes != event.duration) ? durationMinutes : nil

        Task {
            do {
                try await viewModel.updateEvent(
                    id: event._id,
                    title: newTitle,
                    start: newStart,
                    durationMinutes: newDuration
                )
                // Dismiss both the edit sheet and the parent detail sheet
                isDetailPresented = false
                dismiss()
            } catch {
                saveError = "Failed to save: \(error.localizedDescription)"
                print("[EventEditView] updateEvent error: \(error)")
            }
        }
    }
}
