import SwiftUI

/// TaskCreationView presents a sheet for creating new tasks.
/// Sections: title (required), priority picker, optional due date + optional time, optional notes.
struct TaskCreationView: View {
    @ObservedObject var taskViewModel: TaskViewModel
    @Binding var isPresented: Bool
    var prefilledDate: Date?

    // MARK: - State

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
