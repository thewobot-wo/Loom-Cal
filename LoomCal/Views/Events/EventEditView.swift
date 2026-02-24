import SwiftUI

/// EventEditView provides an editable form pre-filled with the existing event's data.
/// On save, calls viewModel.updateEvent() with only changed fields.
/// For recurring events, editMode determines whether changes apply to this occurrence or the series.
struct EventEditView: View {
    let event: LoomEvent
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var isPresented: Bool
    @Binding var isDetailPresented: Bool
    let editMode: RecurrenceEditMode

    @Environment(\.dismiss) private var dismiss

    // MARK: - State (pre-filled from event)

    @State private var title: String
    @State private var eventDate: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var isAllDay: Bool
    @State private var saveError: String? = nil

    // MARK: - Init

    init(
        event: LoomEvent,
        viewModel: CalendarViewModel,
        isPresented: Binding<Bool>,
        isDetailPresented: Binding<Bool>,
        editMode: RecurrenceEditMode = .all
    ) {
        self.event = event
        self.viewModel = viewModel
        self._isPresented = isPresented
        self._isDetailPresented = isDetailPresented
        self.editMode = editMode

        let startDate = Date(timeIntervalSince1970: TimeInterval(event.start) / 1000)
        let endDate = startDate.addingTimeInterval(TimeInterval(event.duration) * 60)
        self._title = State(initialValue: event.title)
        self._eventDate = State(initialValue: startDate)
        self._startTime = State(initialValue: startDate)
        self._endTime = State(initialValue: endDate)
        self._isAllDay = State(initialValue: event.isAllDay)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)

                    DatePicker("Date", selection: $eventDate, displayedComponents: .date)
                        .datePickerStyle(.compact)

                    if !isAllDay {
                        DatePicker("Starts", selection: $startTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .onChange(of: startTime) { _, newStart in
                                if endTime <= newStart {
                                    endTime = newStart.addingTimeInterval(3600)
                                }
                            }

                        DatePicker("Ends", selection: $endTime, in: startTime.addingTimeInterval(900)..., displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
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
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .disabled(title.isEmpty)
                }
            }
        }
    }

    // MARK: - Actions

    private func saveChanges() {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: eventDate)
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = isAllDay ? 0 : (startComponents.hour ?? 0)
        combined.minute = isAllDay ? 0 : (startComponents.minute ?? 0)

        let finalStart = calendar.date(from: combined) ?? eventDate
        let originalStart = Date(timeIntervalSince1970: TimeInterval(event.start) / 1000)

        // Compute duration from start/end
        let startMins = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
        let endMins = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)
        let durationMinutes = max(endMins - startMins, 15)

        Task {
            do {
                if editMode == .single && (event.isRecurring || event.isVirtualOccurrence) {
                    // Edit single occurrence: create standalone + add exception to master
                    try await viewModel.editSingleOccurrence(
                        masterEvent: event,
                        occurrenceStartMs: event.start,
                        title: title,
                        start: finalStart,
                        durationMinutes: isAllDay ? 1440 : durationMinutes,
                        isAllDay: isAllDay
                    )
                } else {
                    // Edit all (or non-recurring): update the event directly
                    let targetId = event.masterEventId ?? event._id
                    let newTitle: String? = (title != event.title) ? title : nil
                    let newStart: Date? = (abs(finalStart.timeIntervalSince(originalStart)) > 30) ? finalStart : nil
                    let newDuration: Int? = (durationMinutes != event.duration) ? durationMinutes : nil

                    try await viewModel.updateEvent(
                        id: targetId,
                        title: newTitle,
                        start: newStart,
                        durationMinutes: newDuration
                    )
                }
                isDetailPresented = false
                dismiss()
            } catch {
                saveError = "Failed to save: \(error.localizedDescription)"
            }
        }
    }
}
