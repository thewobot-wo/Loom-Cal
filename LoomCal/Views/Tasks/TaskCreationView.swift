import SwiftUI

/// TaskCreationView presents a sheet for creating new tasks.
/// Sections: title (required), priority picker, optional due date + optional time, optional notes.
struct TaskCreationView: View {
    @ObservedObject var taskViewModel: TaskViewModel
    @Binding var isPresented: Bool
    var prefilledDate: Date?

    // MARK: - State

    @State private var nlInput: String = ""
    @State private var isParsing: Bool = false
    @State private var title: String = ""
    @State private var priority: String = "low"
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date
    @State private var hasDueTime: Bool = false
    @State private var notes: String = ""
    @State private var saveError: String? = nil
    @State private var showDetails: Bool = false

    enum Field { case nlInput, taskName, notes }
    @FocusState private var focusedField: Field?

    // MARK: - Init

    init(taskViewModel: TaskViewModel, isPresented: Binding<Bool>, prefilledDate: Date? = nil) {
        self.taskViewModel = taskViewModel
        self._isPresented = isPresented
        self.prefilledDate = prefilledDate
        // If a date was prefilled, auto-enable hasDueDate
        if let date = prefilledDate {
            self._hasDueDate = State(initialValue: true)
            self._dueDate = State(initialValue: date)
        } else {
            self._hasDueDate = State(initialValue: false)
            self._dueDate = State(initialValue: Date())
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: NL Hero Input
                    VStack(spacing: 0) {
                        TextField("e.g. Buy groceries by Friday", text: $nlInput)
                            .textFieldStyle(.plain)
                            .font(.title2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 10)
                            .focused($focusedField, equals: .nlInput)
                            .onSubmit { parseAndFillTask() }
                            .disabled(isParsing)

                        Rectangle()
                            .fill(isParsing ? LoomColors.gold : LoomColors.sage)
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

                    // MARK: Task Name (always visible)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TASK NAME")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.tertiary)

                        TextField("Task name", text: $title)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .focused($focusedField, equals: .taskName)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // MARK: Priority Chips
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PRIORITY")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.tertiary)

                        HStack(spacing: 10) {
                            PriorityChip(label: "Low", value: "low", color: LoomColors.sage, selected: priority == "low") {
                                priority = "low"
                            }
                            PriorityChip(label: "Medium", value: "medium", color: LoomColors.gold, selected: priority == "medium") {
                                priority = "medium"
                            }
                            PriorityChip(label: "High", value: "high", color: LoomColors.coral, selected: priority == "high") {
                                priority = "high"
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // MARK: More Details Disclosure
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showDetails.toggle()
                        }
                    } label: {
                        HStack {
                            Text("More Details")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.tertiary)
                                .textCase(.uppercase)

                            // Indicator icons when details have content
                            if hasDueDate {
                                Image(systemName: "calendar")
                                    .font(.caption2)
                                    .foregroundStyle(LoomColors.sage)
                            }
                            if !notes.trimmingCharacters(in: .whitespaces).isEmpty {
                                Image(systemName: "note.text")
                                    .font(.caption2)
                                    .foregroundStyle(LoomColors.sage)
                            }

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
                            // Due date toggle + pickers
                            Toggle("Due date", isOn: $hasDueDate.animation())
                                .tint(LoomColors.coral)

                            if hasDueDate {
                                DatePicker(
                                    "Date",
                                    selection: $dueDate,
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.compact)

                                Toggle("Specific time", isOn: $hasDueTime.animation())
                                    .tint(LoomColors.coral)

                                if hasDueTime {
                                    DatePicker(
                                        "Time",
                                        selection: $dueDate,
                                        displayedComponents: .hourAndMinute
                                    )
                                    .datePickerStyle(.compact)
                                }
                            }

                            // Notes
                            VStack(alignment: .leading, spacing: 4) {
                                Text("NOTES")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.tertiary)

                                TextField("Notes", text: $notes, axis: .vertical)
                                    .textFieldStyle(.plain)
                                    .lineLimit(3...6)
                                    .focused($focusedField, equals: .notes)
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
            .navigationTitle("New Task")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTask() }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(title.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : LoomColors.sage)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    focusedField = .nlInput
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isParsing)
        }
    }

    // MARK: - Actions

    private func parseAndFillTask() {
        guard !nlInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isParsing = true

        Task {
            let result = await NLParseService.shared.parse(text: nlInput, type: "task")

            if let fields = result?.taskFields, result?.status == "complete" {
                title = fields.title
                priority = fields.priority ?? "medium"

                if let dueDateStr = fields.dueDate,
                   let date = parseFlexibleDate(dueDateStr) {
                    hasDueDate = true
                    dueDate = date
                    hasDueTime = fields.hasDueTime ?? false
                } else {
                    hasDueDate = false
                }
            } else {
                // No local fallback for tasks — use raw input as title
                title = nlInput
            }

            isParsing = false

            // Auto-expand details if due date was parsed
            if hasDueDate {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showDetails = true
                }
            }

            // Move focus to task name field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = .taskName
            }
        }
    }

    /// Parse ISO 8601 and common date formats the LLM may return.
    private func parseFlexibleDate(_ string: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: string) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: string) { return date }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }

    private func saveTask() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        // Build final due date
        let finalDueDate: Date?
        if hasDueDate {
            if hasDueTime {
                // Full date + time as selected
                finalDueDate = dueDate
            } else {
                // Date-only: use midnight of the selected day
                finalDueDate = Calendar.current.startOfDay(for: dueDate)
            }
        } else {
            finalDueDate = nil
        }

        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)

        Task {
            do {
                try await taskViewModel.createTask(
                    title: trimmedTitle,
                    priority: priority,
                    dueDate: finalDueDate,
                    hasDueTime: hasDueDate && hasDueTime,
                    notes: trimmedNotes.isEmpty ? nil : trimmedNotes
                )
                isPresented = false
            } catch {
                saveError = "Failed to create task: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Priority Chip

private struct PriorityChip: View {
    let label: String
    let value: String
    let color: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(selected ? .semibold : .regular)
                .foregroundStyle(selected ? .white : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selected ? color : Color.gray.opacity(0.1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: selected)
    }
}
