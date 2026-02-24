import SwiftUI

/// Preset recurrence options for the creation picker.
enum RecurrencePreset: String, CaseIterable, Identifiable {
    case never = "Never"
    case daily = "Daily"
    case weekdays = "Weekdays"
    case weekly = "Weekly"
    case monthly = "Monthly"

    var id: String { rawValue }

    /// Convert to a RecurrenceRule for the given event date.
    func toRule(for date: Date) -> RecurrenceRule? {
        let cal = Calendar.current
        switch self {
        case .never:
            return nil
        case .daily:
            return .daily()
        case .weekdays:
            return .weekdays()
        case .weekly:
            let wd = cal.component(.weekday, from: date)
            if let day = Weekday.from(calendarWeekday: wd) {
                return .weekly(days: [day])
            }
            return .weekly(days: [.monday])
        case .monthly:
            let day = cal.component(.day, from: date)
            return .monthly(dayOfMonth: day)
        }
    }
}

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
    @State private var selectedRecurrence: RecurrencePreset = .never
    @State private var saveError: String? = nil
    @State private var showDetails: Bool = false
    @State private var hasParsed: Bool = false

    @FocusState private var isNLInputFocused: Bool

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
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: NL Hero Input
                    VStack(spacing: 0) {
                        TextField("Dentist 3pm, Team lunch tomorrow...", text: $nlInput)
                            .textFieldStyle(.plain)
                            .font(.title2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 10)
                            .focused($isNLInputFocused)
                            .onSubmit { parseAndFill() }
                            .disabled(isParsing)

                        Rectangle()
                            .fill(isParsing ? LoomColors.gold : LoomColors.eventDefault)
                            .frame(height: 2)
                            .padding(.horizontal, 20)
                            .animation(.easeInOut(duration: 0.3), value: isParsing)
                    }

                    // Parsing indicator
                    if isParsing {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Parsing...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 10)
                        .transition(.opacity)
                    }

                    // MARK: Parsed Summary Card
                    if hasParsed && !title.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(title)
                                .font(.headline)
                                .fontWeight(.semibold)

                            HStack(spacing: 16) {
                                Label(eventDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                                      systemImage: "calendar")
                                if !isAllDay {
                                    Label(startTime.formatted(.dateTime.hour().minute()),
                                          systemImage: "clock")
                                } else {
                                    Label("All Day", systemImage: "sun.max")
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                            if selectedRecurrence != .never,
                               let rule = selectedRecurrence.toRule(for: eventDate) {
                                Label(rule.displayDescription, systemImage: "repeat")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(LoomColors.eventDefault.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // MARK: Details Disclosure
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showDetails.toggle()
                        }
                    } label: {
                        HStack {
                            Text("Details")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.tertiary)
                                .textCase(.uppercase)
                            Spacer()
                            Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                    }
                    .buttonStyle(.plain)

                    if showDetails {
                        VStack(spacing: 16) {
                            // Title field
                            VStack(alignment: .leading, spacing: 4) {
                                Text("TITLE")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.tertiary)
                                TextField("Event title", text: $title)
                                    .textFieldStyle(.plain)
                                    .font(.body)
                            }

                            // Date picker
                            DatePicker("Date", selection: $eventDate, displayedComponents: .date)
                                .datePickerStyle(.compact)

                            // Time pickers (when not all-day)
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

                            // All-day toggle
                            Toggle("All Day", isOn: $isAllDay)
                                .tint(LoomColors.coral)

                            // Recurrence picker
                            HStack {
                                Text("Repeat")
                                Spacer()
                                Picker("Repeat", selection: $selectedRecurrence) {
                                    ForEach(RecurrencePreset.allCases) { preset in
                                        Text(preset.rawValue).tag(preset)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(selectedRecurrence == .never ? .secondary : LoomColors.coral)
                            }
                        }
                        .padding(.horizontal, 20)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // MARK: Error
                    if let error = saveError {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                    }
                }
                .padding(.bottom, 20)
            }
            .scrollContentBackground(.hidden)
            .background(LoomColors.contentBackground)
            .navigationTitle("New Event")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { saveEvent() }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(title.isEmpty ? Color.gray : LoomColors.coral)
                        .disabled(title.isEmpty)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isNLInputFocused = true
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isParsing)
            .animation(.easeInOut(duration: 0.25), value: hasParsed)
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
            hasParsed = true

            // Auto-expand details after parsing
            withAnimation(.easeInOut(duration: 0.25)) {
                showDetails = true
            }
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

        let rrule = selectedRecurrence.toRule(for: eventDate)?.toRRULE()

        Task {
            do {
                try await viewModel.createEvent(
                    title: title,
                    start: finalStart,
                    durationMinutes: isAllDay ? 1440 : durationMinutes,
                    isAllDay: isAllDay,
                    rrule: rrule
                )
                isPresented = false
            } catch {
                saveError = "Failed to create event: \(error.localizedDescription)"
            }
        }
    }
}
