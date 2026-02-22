import SwiftUI

/// TaskDetailView provides full editing of a task plus completion toggle and alert-based delete.
/// Pre-fills all fields from the task at init time using State(initialValue:) pattern.
struct TaskDetailView: View {
    let task: LoomTask
    @ObservedObject var taskViewModel: TaskViewModel
    @Binding var isPresented: Bool

    @Environment(\.dismiss) private var dismiss

    // MARK: - State (pre-filled from task)

    @State private var editTitle: String
    @State private var editPriority: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var hasDueTime: Bool
    @State private var editNotes: String
    @State private var showDeleteAlert: Bool = false
    @State private var saveError: String? = nil

    // MARK: - Init

    init(task: LoomTask, taskViewModel: TaskViewModel, isPresented: Binding<Bool>) {
        self.task = task
        self.taskViewModel = taskViewModel
        self._isPresented = isPresented

        self._editTitle = State(initialValue: task.title)
        self._editPriority = State(initialValue: task.priority)
        self._editNotes = State(initialValue: task.notes ?? "")

        if let dueDateMs = task.dueDate {
            let date = Date(timeIntervalSince1970: TimeInterval(dueDateMs) / 1000)
            self._hasDueDate = State(initialValue: true)
            self._dueDate = State(initialValue: date)
            self._hasDueTime = State(initialValue: task.hasDueTime)
        } else {
            self._hasDueDate = State(initialValue: false)
            self._dueDate = State(initialValue: Date())
            self._hasDueTime = State(initialValue: false)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // Section: Details
                Section("Details") {
                    TextField("Title", text: $editTitle)

                    Picker("Priority", selection: $editPriority) {
                        Text("High").tag("high")
                        Text("Medium").tag("medium")
                        Text("Low").tag("low")
                    }
                    .pickerStyle(.segmented)

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

                    TextField("Notes", text: $editNotes, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Section: Actions
                Section("Actions") {
                    Button(task.completed ? "Mark Incomplete" : "Mark Complete") {
                        toggleComplete()
                    }
                    .foregroundStyle(task.completed ? Color.secondary : LoomColors.interactiveText)

                    Button("Delete Task", role: .destructive) {
                        showDeleteAlert = true
                    }
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
            .navigationTitle("Task Details")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .disabled(editTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            // Use .alert — more reliable in nested sheet contexts (per project pattern)
            .alert("Delete Task", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    deleteTask()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This task will be permanently deleted.")
            }
        }
    }

    // MARK: - Actions

    private func toggleComplete() {
        Task {
            do {
                try await taskViewModel.toggleComplete(task: task)
                isPresented = false
            } catch {
                saveError = "Failed to update task: \(error.localizedDescription)"
            }
        }
    }

    private func deleteTask() {
        Task {
            do {
                try await taskViewModel.deleteTask(id: task._id)
                isPresented = false
            } catch {
                saveError = "Failed to delete task: \(error.localizedDescription)"
            }
        }
    }

    private func saveChanges() {
        let trimmedTitle = editTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        // Detect changed fields (only pass what changed to updateTask)
        let newTitle: String? = (trimmedTitle != task.title) ? trimmedTitle : nil
        let newPriority: String? = (editPriority != task.priority) ? editPriority : nil

        // Compute final due date
        let finalDueDate: Date?
        if hasDueDate {
            finalDueDate = hasDueTime ? dueDate : Calendar.current.startOfDay(for: dueDate)
        } else {
            finalDueDate = nil
        }

        // Check if due date changed
        let originalDueDateMs = task.dueDate
        let finalDueDateMs = finalDueDate.map { Int($0.timeIntervalSince1970 * 1000) }
        let dueDateChanged = finalDueDateMs != originalDueDateMs
        let newDueDate: Date?? = dueDateChanged ? .some(finalDueDate) : .none

        let newHasDueTime: Bool? = {
            let targetHasDueTime = hasDueDate && hasDueTime
            return targetHasDueTime != task.hasDueTime ? targetHasDueTime : nil
        }()

        let trimmedNotes = editNotes.trimmingCharacters(in: .whitespaces)
        let newNotes: String? = (trimmedNotes != (task.notes ?? "")) ? (trimmedNotes.isEmpty ? nil : trimmedNotes) : nil

        // Only call update if something actually changed
        guard newTitle != nil || newPriority != nil || dueDateChanged || newHasDueTime != nil || newNotes != nil else {
            dismiss()
            return
        }

        Task {
            do {
                try await taskViewModel.updateTask(
                    id: task._id,
                    title: newTitle,
                    priority: newPriority,
                    dueDate: newDueDate ?? nil,
                    hasDueTime: newHasDueTime,
                    notes: newNotes
                )
                isPresented = false
            } catch {
                saveError = "Failed to save: \(error.localizedDescription)"
            }
        }
    }
}
