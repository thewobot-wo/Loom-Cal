import SwiftUI

/// EventCreationView presents a sheet for creating new calendar events.
/// Top section: natural language text field (e.g. "Dentist 3pm").
/// Detail section: title, date, start time, end time, all-day toggle.
struct EventCreationView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var isPresented: Bool
    var prefilledDate: Date?

    // MARK: - State

    @State private var nlInput: String = ""
    @State private var title: String = ""
    @State private var eventDate: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var isAllDay: Bool = false
    @State private var saveError: String? = nil

    // MARK: - Init

    init(viewModel: CalendarViewModel, isPresented: Binding<Bool>, prefilledDate: Date? = nil) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self.prefilledDate = prefilledDate
        let now = prefilledDate ?? Date()
        self._eventDate = State(initialValue: now)
        self._startTime = State(initialValue: now)
        // Default: 1 hour from start
        self._endTime = State(initialValue: now.addingTimeInterval(3600))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Dentist 3pm, Team lunch tomorrow...", text: $nlInput)
                        .font(.title3)
                        .onSubmit { parseAndFill() }
                }

                Section("Details") {
                    TextField("Title", text: $title)

                    DatePicker("Date", selection: $eventDate, displayedComponents: .date)
                        .datePickerStyle(.compact)

                    if !isAllDay {
                        DatePicker("Starts", selection: $startTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .onChange(of: startTime) { _, newStart in
                                // Keep end time at least 15 min after start
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
            .navigationTitle("New Event")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { saveEvent() }
                        .disabled(title.isEmpty)
                }
            }
        }
    }

    // MARK: - Actions

    private func parseAndFill() {
        guard !nlInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let parsed = NLEventParser.parse(nlInput)
        if !parsed.title.isEmpty { title = parsed.title }
        if let parsedDate = parsed.date {
            eventDate = parsedDate
            if parsed.hasTime {
                startTime = parsedDate
                endTime = parsedDate.addingTimeInterval(3600)
            }
        }
    }

    private func saveEvent() {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: eventDate)
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)

        var combinedStart = DateComponents()
        combinedStart.year = dateComponents.year
        combinedStart.month = dateComponents.month
        combinedStart.day = dateComponents.day
        combinedStart.hour = isAllDay ? 0 : (startComponents.hour ?? 0)
        combinedStart.minute = isAllDay ? 0 : (startComponents.minute ?? 0)

        let finalStart = calendar.date(from: combinedStart) ?? eventDate

        // Compute duration from start/end time difference
        let startMins = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
        let endMins = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)
        let durationMinutes = max(endMins - startMins, 15)

        Task {
            do {
                try await viewModel.createEvent(
                    title: title,
                    start: finalStart,
                    durationMinutes: isAllDay ? 1440 : durationMinutes,
                    isAllDay: isAllDay
                )
                isPresented = false
            } catch {
                saveError = "Failed to create event: \(error.localizedDescription)"
            }
        }
    }
}
