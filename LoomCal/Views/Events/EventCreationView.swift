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
    @State private var isParsing: Bool = false
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
                    HStack {
                        TextField("Dentist 3pm, Team lunch tomorrow...", text: $nlInput)
                            .font(.title3)
                            .onSubmit { parseAndFill() }
                            .disabled(isParsing)
                        if isParsing {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
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
        isParsing = true

        Task {
            let result = await NLParseService.shared.parse(text: nlInput, type: "event")

            if let fields = result?.eventFields, result?.status == "complete" {
                title = fields.title
                isAllDay = fields.isAllDay ?? false

                if let startDate = parseFlexibleDate(fields.start) {
                    eventDate = startDate
                    startTime = startDate
                    let mins = fields.duration ?? 60
                    endTime = startDate.addingTimeInterval(Double(mins) * 60)
                }
            } else {
                // Fallback to local NLEventParser
                let parsed = NLEventParser.parse(nlInput)
                if !parsed.title.isEmpty { title = parsed.title }
                if let date = parsed.date {
                    eventDate = date
                    startTime = date
                    endTime = date.addingTimeInterval(3600)
                    isAllDay = !parsed.hasTime
                }
            }

            isParsing = false
        }
    }

    /// Parse ISO 8601 and common date formats the LLM may return.
    private func parseFlexibleDate(_ string: String) -> Date? {
        // Try ISO8601DateFormatter first (handles timezone offsets)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: string) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: string) { return date }

        // Try common formats without timezone offset
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) { return date }
        }
        return nil
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
