import SwiftUI

/// EventCreationView presents a sheet for creating new calendar events.
/// The top section provides a natural language text field (e.g. "Dentist 3pm").
/// Typing in the NL field and pressing Return parses the input and pre-fills the detail fields.
/// The detail section exposes manual controls for title, date, time, duration, and all-day toggle.
struct EventCreationView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var isPresented: Bool

    /// Optional pre-filled date (e.g. from long-press on mini month).
    var prefilledDate: Date?

    // MARK: - State

    @State private var nlInput: String = ""
    @State private var title: String = ""
    @State private var eventDate: Date
    @State private var startTime: Date = Date()
    @State private var durationMinutes: Int = 60   // Default: 1 hour per locked decision
    @State private var isAllDay: Bool = false
    @State private var saveError: String? = nil

    // MARK: - Init

    init(viewModel: CalendarViewModel, isPresented: Binding<Bool>, prefilledDate: Date? = nil) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self.prefilledDate = prefilledDate
        // Initialize eventDate from prefilledDate if provided, otherwise today
        self._eventDate = State(initialValue: prefilledDate ?? Date())
    }

    // MARK: - Duration options

    private let durationOptions: [(label: String, minutes: Int)] = [
        ("15 min", 15),
        ("30 min", 30),
        ("45 min", 45),
        ("1 hour", 60),
        ("1.5 hours", 90),
        ("2 hours", 120)
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // Natural language input section
                Section {
                    TextField("Dentist 3pm, Team lunch tomorrow...", text: $nlInput)
                        .font(.title3)
                        .onSubmit {
                            parseAndFill()
                        }
                }

                // Manual detail fields section
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
            .navigationTitle("New Event")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        saveEvent()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    // MARK: - Actions

    /// Parses the NL input and fills detail fields.
    private func parseAndFill() {
        guard !nlInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let parsed = NLEventParser.parse(nlInput)

        // Apply title if detected
        if !parsed.title.isEmpty {
            title = parsed.title
        }

        // Apply date/time from parsed result
        if let parsedDate = parsed.date {
            if parsed.hasTime {
                // Detected both date and time — set both fields
                eventDate = parsedDate
                startTime = parsedDate
            } else {
                // Date only, no specific time — set date only
                eventDate = parsedDate
            }
        }
    }

    /// Combines the date and time fields and calls viewModel.createEvent().
    private func saveEvent() {
        // Combine eventDate (day) and startTime (hour/minute) into a single Date
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

        Task {
            do {
                try await viewModel.createEvent(
                    title: title,
                    start: finalStart,
                    durationMinutes: durationMinutes,
                    isAllDay: isAllDay
                )
                isPresented = false
            } catch {
                saveError = "Failed to create event: \(error.localizedDescription)"
                print("[EventCreationView] createEvent error: \(error)")
            }
        }
    }
}
