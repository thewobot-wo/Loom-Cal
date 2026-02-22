import SwiftUI
import ConvexMobile

@MainActor
class TaskViewModel: ObservableObject {
    @Published var tasks: [LoomTask] = []
    @Published var isLoading: Bool = true

    /// ID of the task to highlight after a Loom action mutation — drives flash animation in views.
    /// Automatically cleared after 2 seconds by flashHighlight(taskId:).
    @Published var highlightedTaskId: String? = nil

    private var subscriptionTask: Task<Void, Never>?

    func startSubscription() {
        subscriptionTask?.cancel()
        subscriptionTask = Task {
            for await result: [LoomTask] in convex
                .subscribe(to: "tasks:list")
                .replaceError(with: [])
                .values
            {
                guard !Task.isCancelled else { break }
                self.tasks = result
                self.isLoading = false
            }
        }
    }

    func stopSubscription() {
        subscriptionTask?.cancel()
        subscriptionTask = nil
    }

    // MARK: - Date Filtering

    /// All tasks due on the given calendar day (with or without time)
    func tasks(dueOn date: Date) -> [LoomTask] {
        let dayStart = Calendar.current.startOfDay(for: date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
        return tasks.filter { task in
            guard let ms = task.dueDate else { return false }
            let d = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
            return d >= dayStart && d < dayEnd
        }
    }

    /// Tasks due on given day that have a specific time
    func tasksWithTime(dueOn date: Date) -> [LoomTask] {
        tasks(dueOn: date).filter { $0.hasDueTime }
    }

    /// Tasks due on given day without a specific time (appear at top)
    func unscheduledTasks(dueOn date: Date) -> [LoomTask] {
        tasks(dueOn: date).filter { !$0.hasDueTime }
    }

    /// All incomplete tasks with a past due date
    func overdueTasks() -> [LoomTask] {
        let now = Date()
        return tasks.filter { task in
            guard !task.completed, let ms = task.dueDate else { return false }
            let d = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
            return d < Calendar.current.startOfDay(for: now)
        }
    }

    /// All incomplete tasks (active task list)
    var activeTasks: [LoomTask] {
        tasks.filter { !$0.completed }
    }

    /// All completed tasks (completed section)
    var completedTasks: [LoomTask] {
        tasks.filter { $0.completed }
    }

    // MARK: - CRUD Mutations

    func createTask(
        title: String,
        priority: String = "low",
        dueDate: Date? = nil,
        hasDueTime: Bool = false,
        notes: String? = nil
    ) async throws {
        var args: [String: ConvexEncodable?] = [
            "title": title,
            "priority": priority,
            "hasDueTime": hasDueTime,
            "completed": false
        ]
        if let dueDate {
            args["dueDate"] = Int(dueDate.timeIntervalSince1970 * 1000)
        }
        if let notes { args["notes"] = notes }
        try await convex.mutation("tasks:create", with: args)
    }

    func updateTask(
        id: String,
        title: String? = nil,
        priority: String? = nil,
        dueDate: Date? = nil,
        hasDueTime: Bool? = nil,
        completed: Bool? = nil,
        notes: String? = nil
    ) async throws {
        var args: [String: ConvexEncodable?] = ["id": id]
        if let title { args["title"] = title }
        if let priority { args["priority"] = priority }
        if let dueDate { args["dueDate"] = Int(dueDate.timeIntervalSince1970 * 1000) }
        if let hasDueTime { args["hasDueTime"] = hasDueTime }
        if let completed { args["completed"] = completed }
        if let notes { args["notes"] = notes }
        try await convex.mutation("tasks:update", with: args)
    }

    func toggleComplete(task: LoomTask) async throws {
        try await updateTask(id: task._id, completed: !task.completed)
    }

    func deleteTask(id: String) async throws {
        let args: [String: ConvexEncodable?] = ["id": id]
        try await convex.mutation("tasks:remove", with: args)
    }

    // MARK: - Highlight Feedback

    /// Highlights a task briefly (2 seconds) to draw attention after a Loom action mutation.
    /// Views observe highlightedTaskId to apply a visual emphasis.
    func flashHighlight(taskId: String) {
        highlightedTaskId = taskId
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                self.highlightedTaskId = nil
            }
        }
    }

    /// Create a time-block event linked to a task
    func createTimeBlock(for task: LoomTask, at date: Date) async throws {
        let startMs = Int(date.timeIntervalSince1970 * 1000)
        let args: [String: ConvexEncodable?] = [
            "calendarId": "personal",
            "title": task.title,
            "start": startMs,
            "duration": 60,  // default 1 hour
            "timezone": TimeZone.current.identifier,
            "isAllDay": false,
            "taskId": task._id
        ]
        try await convex.mutation("events:create", with: args)
    }
}
