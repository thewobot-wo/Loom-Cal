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
            Form {
                // Section 0: Quick NL Entry
                Section("Quick Entry") {
                    HStack {
                        TextField("e.g. Buy groceries by Friday", text: $nlInput)
                            .onSubmit { parseAndFillTask() }
                            .disabled(isParsing)
                        if isParsing {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }

                // Section 1: Title
                Section {
                    TextField("Task name", text: $title)
                }

                // Section 2: Priority
                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        Text("High").tag("high")
                        Text("Medium").tag("medium")
                        Text("Low").tag("low")
                    }
                    .pickerStyle(.segmented)
                }

                // Section 3: Due date
                Section("Due Date") {
                    Toggle("Due date", isOn: $hasDueDate.animation())

                    if hasDueDate {
                        DatePicker(
                            "Date",
                            selection: $dueDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)

                        Toggle("Specific time", isOn: $hasDueTime.animation())

                        if hasDueTime {
                            DatePicker(
                                "Time",
                                selection: $dueDate,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.compact)
                        }
                    }
                }

                // Section 4: Notes (optional)
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Error display
                if let error = saveError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("New Task")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTask() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
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
