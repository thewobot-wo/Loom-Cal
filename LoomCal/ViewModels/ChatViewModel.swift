import SwiftUI
import ConvexMobile

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading: Bool = true
    @Published var pendingMessageContent: String? = nil    // content of user message awaiting Loom reply
    @Published var isLoomAvailable: Bool = true            // false when timeout fires or send fails
    @Published var timedOutMessageIds: Set<String> = []    // messages that got no reply — shows retry bubble

    // MARK: - Voice

    let voiceService = VoiceService()
    @AppStorage("loomVoiceEnabled") var voiceEnabled: Bool = false

    // MARK: - Undo Context

    /// Tracks state for the undo window after a confirmed action or daily plan.
    struct UndoContext: Equatable {
        let displaySummary: String     // Summary text for the undo banner
        let messageId: String          // Chat message ID to mark as "undone"
        let action: LoomAction?        // For single-action reverse (nil for daily plans)
        let createdId: String?         // Single created item ID (single actions)
        let createdIds: [String]       // Batch created item IDs (daily plans)
        let isDailyPlan: Bool

        /// Convenience init for single-action undo (backward compat with existing flow).
        init(action: LoomAction, messageId: String, createdId: String?) {
            self.displaySummary = action.displaySummary
            self.messageId = messageId
            self.action = action
            self.createdId = createdId
            self.createdIds = []
            self.isDailyPlan = false
        }

        /// Init for daily plan batch undo.
        init(displaySummary: String, messageId: String, createdIds: [String]) {
            self.displaySummary = displaySummary
            self.messageId = messageId
            self.action = nil
            self.createdId = nil
            self.createdIds = createdIds
            self.isDailyPlan = true
        }
    }

    // MARK: - Action State

    /// Active undo context — set after a successful action confirmation.
    /// Cleared when the undo timer expires or undoAction() is called.
    @Published var activeUndoAction: UndoContext? = nil

    /// Countdown remaining for the undo window (seconds).
    @Published var undoSecondsRemaining: Int = 0

    // MARK: - ViewModel References

    /// Set by ContentView.onAppear to allow action execution via existing CRUD methods.
    var calendarViewModel: CalendarViewModel?
    var taskViewModel: TaskViewModel?

    // MARK: - Private

    private var subscriptionTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var undoTask: Task<Void, Never>?

    // MARK: - Subscription

    func startSubscription() {
        subscriptionTask?.cancel()
        subscriptionTask = Task {
            for await result: [ChatMessage] in convex
                .subscribe(to: "chatMessages:list")
                .replaceError(with: [])
                .values
            {
                guard !Task.isCancelled else { break }
                let previousCount = self.messages.count
                self.messages = result
                self.isLoading = false

                // If a new assistant or pending_action message arrived, clear pending state and timeout
                if result.count > previousCount,
                   let lastMessage = result.last,
                   (lastMessage.role == "assistant" || lastMessage.role == "pending_action") {
                    self.pendingMessageContent = nil
                    self.timeoutTask?.cancel()
                    self.timeoutTask = nil
                    // Clear timed-out message IDs — Loom is responding
                    self.timedOutMessageIds.removeAll()
                    // Loom replied successfully — mark available
                    if !self.isLoomAvailable {
                        self.isLoomAvailable = true
                    }
                    // Auto-play TTS when voice is enabled and message has audio
                    if self.voiceEnabled,
                       lastMessage.role == "assistant",
                       let audioUrl = lastMessage.audioUrl {
                        self.voiceService.play(url: audioUrl, messageId: lastMessage._id)
                    }
                }
            }
        }
    }

    func stopSubscription() {
        subscriptionTask?.cancel()
        subscriptionTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        undoTask?.cancel()
        undoTask = nil
    }

    // MARK: - Send

    func sendMessage(_ content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Set pending state immediately (optimistic)
        self.pendingMessageContent = trimmed

        let args: [String: ConvexEncodable?] = [
            "role": "user",
            "content": trimmed
        ]
        Task {
            do {
                try await convex.mutation("chatMessages:send", with: args)
                // Mutation succeeded — start the reply timeout
                self.startReplyTimeout()
            } catch {
                // Mutation failed — Loom/Convex unreachable
                self.isLoomAvailable = false
                self.pendingMessageContent = nil
            }
        }
    }

    func retryMessage(_ content: String) {
        // Remove from timed-out set and resend
        timedOutMessageIds.removeAll()  // Clear all timeouts on retry
        isLoomAvailable = true
        sendMessage(content)
    }

    /// Clear all chat messages.
    func clearChat() {
        Task {
            try? await convex.mutation("chatMessages:clearAll", with: [:])
        }
    }

    /// Toggle play/pause for a message's TTS audio.
    func playMessage(_ message: ChatMessage) {
        guard let audioUrl = message.audioUrl else { return }
        voiceService.togglePlayPause(url: audioUrl, messageId: message._id)
    }

    private func startReplyTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task {
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            // No reply arrived within 30 seconds (tool calls can be slow)
            self.isLoomAvailable = false
            if let content = self.pendingMessageContent {
                self.timedOutMessageIds.insert(content)
            }
            self.pendingMessageContent = nil
        }
    }

    // MARK: - Action Lifecycle

    /// Confirms a pending action: executes the mutation FIRST via CalendarViewModel or TaskViewModel,
    /// then marks it confirmed in Convex only on success, and starts the undo timer.
    func confirmAction(_ message: ChatMessage) {
        guard message.isPendingAction,
              let action = message.decodedAction
        else { return }

        // Guard: verify required ViewModel is available before attempting execution
        if action.isEventAction && calendarViewModel == nil {
            Task {
                let errorArgs: [String: ConvexEncodable?] = [
                    "role": "assistant",
                    "content": "Calendar isn't ready yet — please wait a moment and try again."
                ]
                try? await convex.mutation("chatMessages:send", with: errorArgs)
            }
            return
        }
        if action.isTaskAction && taskViewModel == nil {
            Task {
                let errorArgs: [String: ConvexEncodable?] = [
                    "role": "assistant",
                    "content": "Tasks aren't ready yet — please wait a moment and try again."
                ]
                try? await convex.mutation("chatMessages:send", with: errorArgs)
            }
            return
        }

        Task {
            do {
                // 1. Execute the action mutation FIRST — capture created ID if applicable
                let createdId = try await self.executeAction(action)

                // 2. Mark confirmed in Convex ONLY after successful execution
                let statusArgs: [String: ConvexEncodable?] = [
                    "id": message._id,
                    "actionStatus": "confirmed"
                ]
                try await convex.mutation("chatMessages:updateActionStatus", with: statusArgs)

                // 3. Start undo timer (not started for delete actions — data is gone)
                if !action.isDelete {
                    let context = UndoContext(action: action, messageId: message._id, createdId: createdId)
                    self.startUndoTimer(for: context)
                }

            } catch {
                // Execution failed — mark as failed (leave card actionable for retry)
                let failArgs: [String: ConvexEncodable?] = [
                    "id": message._id,
                    "actionStatus": "cancelled"
                ]
                try? await convex.mutation("chatMessages:updateActionStatus", with: failArgs)

                // Surface the failure as an assistant error message
                let errorArgs: [String: ConvexEncodable?] = [
                    "role": "assistant",
                    "content": "I couldn't complete that action — please try again."
                ]
                try? await convex.mutation("chatMessages:send", with: errorArgs)
            }
        }
    }

    /// Cancels a pending action without executing the mutation.
    func cancelAction(_ message: ChatMessage) {
        Task {
            let args: [String: ConvexEncodable?] = [
                "id": message._id,
                "actionStatus": "cancelled"
            ]
            try? await convex.mutation("chatMessages:updateActionStatus", with: args)
        }
    }

    // MARK: - Daily Plan Lifecycle

    /// Approves a daily plan: batch-creates all proposed time blocks as events,
    /// marks the plan confirmed, and starts a batch undo timer.
    func approveDailyPlan(_ message: ChatMessage) {
        guard message.isDailyPlan,
              let plan = message.decodedPlan,
              let calVM = calendarViewModel
        else { return }

        Task {
            do {
                let beforeIds = Set(calVM.events.map { $0._id })

                // Create each proposed time block as an event
                for block in plan.payload.blocks {
                    try await calVM.createEvent(
                        title: block.title,
                        start: block.startDate,
                        durationMinutes: block.duration,
                        isAllDay: false
                    )
                }

                // Wait for subscription to reflect new events, then collect IDs
                try? await Task.sleep(for: .seconds(2))
                let afterIds = Set(calVM.events.map { $0._id })
                let createdIds = Array(afterIds.subtracting(beforeIds))

                // Mark confirmed
                let statusArgs: [String: ConvexEncodable?] = [
                    "id": message._id,
                    "actionStatus": "confirmed"
                ]
                try await convex.mutation("chatMessages:updateActionStatus", with: statusArgs)

                // Navigate to today and flash highlights
                calVM.navigateToDate(Date())
                for id in createdIds {
                    calVM.flashHighlight(eventId: id)
                }

                // Start batch undo timer
                let context = UndoContext(
                    displaySummary: plan.displaySummary,
                    messageId: message._id,
                    createdIds: createdIds
                )
                self.startUndoTimer(for: context)

            } catch {
                let failArgs: [String: ConvexEncodable?] = [
                    "id": message._id,
                    "actionStatus": "cancelled"
                ]
                try? await convex.mutation("chatMessages:updateActionStatus", with: failArgs)

                let errorArgs: [String: ConvexEncodable?] = [
                    "role": "assistant",
                    "content": "I couldn't create the schedule — please try again."
                ]
                try? await convex.mutation("chatMessages:send", with: errorArgs)
            }
        }
    }

    /// Rejects a daily plan without creating any events.
    func rejectDailyPlan(_ message: ChatMessage) {
        cancelAction(message)
    }

    /// Reverses the most recent confirmed action within the undo window.
    /// For create actions: deletes the created item.
    /// For update actions with previousValues: patches back to previous state.
    func undoAction() {
        guard let undo = activeUndoAction else { return }
        undoTask?.cancel()
        activeUndoAction = nil
        undoSecondsRemaining = 0

        Task {
            // Mark as undone in Convex
            let statusArgs: [String: ConvexEncodable?] = [
                "id": undo.messageId,
                "actionStatus": "undone"
            ]
            try? await convex.mutation("chatMessages:updateActionStatus", with: statusArgs)

            // Reverse the action
            do {
                if undo.isDailyPlan {
                    // Batch undo — delete all created events
                    for id in undo.createdIds {
                        try? await calendarViewModel?.deleteEvent(id: id)
                    }
                } else if let action = undo.action {
                    try await self.reverseAction(action, createdId: undo.createdId)
                }
            } catch {
                // Undo failed — log silently (no user-facing error for undo)
            }
        }
    }

    // MARK: - Private: Action Execution

    /// Executes the mutation corresponding to the action type.
    /// Returns the ID of the newly created item (for create actions) or nil.
    private func executeAction(_ action: LoomAction) async throws -> String? {
        switch action.type {

        case "create_event":
            guard let calVM = calendarViewModel else { return nil }
            let title = action.payload["title"]?.stringValue ?? "New Event"
            let startMs = action.payload["start"]?.intValue ?? Int(Date().timeIntervalSince1970 * 1000)
            let duration = action.payload["duration"]?.intValue ?? 60
            let isAllDay = action.payload["isAllDay"]?.boolValue ?? false
            let startDate = Date(timeIntervalSince1970: TimeInterval(startMs) / 1000)

            // Snapshot before to diff for new ID
            let before = Set(calVM.events.map { $0._id })
            try await calVM.createEvent(
                title: title,
                start: startDate,
                durationMinutes: duration,
                isAllDay: isAllDay
            )
            // Navigate to event date and try to identify new event ID
            calVM.navigateToDate(startDate)
            let newId = await waitForNewEventId(in: calVM, excluding: before)
            if let id = newId { calVM.flashHighlight(eventId: id) }
            return newId

        case "update_event":
            guard let calVM = calendarViewModel,
                  let id = action.payload["id"]?.stringValue
            else { return nil }
            let title = action.payload["title"]?.stringValue
            let startMs = action.payload["start"]?.intValue
            let startDate = startMs.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
            let duration = action.payload["duration"]?.intValue
            try await calVM.updateEvent(id: id, title: title, start: startDate, durationMinutes: duration)
            calVM.flashHighlight(eventId: id)
            if let d = startDate { calVM.navigateToDate(d) }
            return nil

        case "delete_event":
            guard let calVM = calendarViewModel,
                  let id = action.payload["id"]?.stringValue
            else { return nil }
            try await calVM.deleteEvent(id: id)
            return nil

        case "create_task":
            guard let taskVM = taskViewModel else { return nil }
            let title = action.payload["title"]?.stringValue ?? "New Task"
            let priority = action.payload["priority"]?.stringValue ?? "medium"
            let hasDueTime = action.payload["hasDueTime"]?.boolValue ?? false
            let dueDateMs = action.payload["dueDate"]?.intValue
            let dueDate = dueDateMs.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
            let notes = action.payload["notes"]?.stringValue

            let before = Set(taskVM.tasks.map { $0._id })
            try await taskVM.createTask(
                title: title,
                priority: priority,
                dueDate: dueDate,
                hasDueTime: hasDueTime,
                notes: notes
            )
            let newId = await waitForNewTaskId(in: taskVM, excluding: before)
            if let id = newId { taskVM.flashHighlight(taskId: id) }
            return newId

        case "update_task":
            guard let taskVM = taskViewModel,
                  let id = action.payload["id"]?.stringValue
            else { return nil }
            let title = action.payload["title"]?.stringValue
            let priority = action.payload["priority"]?.stringValue
            let hasDueTime = action.payload["hasDueTime"]?.boolValue
            let completed = action.payload["completed"]?.boolValue
            let dueDateMs = action.payload["dueDate"]?.intValue
            let dueDate = dueDateMs.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
            let notes = action.payload["notes"]?.stringValue
            try await taskVM.updateTask(
                id: id,
                title: title,
                priority: priority,
                dueDate: dueDate,
                hasDueTime: hasDueTime,
                completed: completed,
                notes: notes
            )
            taskVM.flashHighlight(taskId: id)
            return nil

        case "delete_task":
            guard let taskVM = taskViewModel,
                  let id = action.payload["id"]?.stringValue
            else { return nil }
            try await taskVM.deleteTask(id: id)
            return nil

        default:
            return nil
        }
    }

    /// Reverses a confirmed action (used by undoAction).
    private func reverseAction(_ action: LoomAction, createdId: String?) async throws {
        switch action.type {

        case "create_event":
            guard let calVM = calendarViewModel,
                  let id = createdId
            else { return }
            try await calVM.deleteEvent(id: id)

        case "create_task":
            guard let taskVM = taskViewModel,
                  let id = createdId
            else { return }
            try await taskVM.deleteTask(id: id)

        case "update_event":
            guard let calVM = calendarViewModel,
                  let prev = action.previousValues,
                  let id = prev["id"]?.stringValue ?? action.payload["id"]?.stringValue
            else { return }
            let title = prev["title"]?.stringValue
            let startMs = prev["start"]?.intValue
            let startDate = startMs.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
            let duration = prev["duration"]?.intValue
            try await calVM.updateEvent(id: id, title: title, start: startDate, durationMinutes: duration)

        case "update_task":
            guard let taskVM = taskViewModel,
                  let prev = action.previousValues,
                  let id = prev["id"]?.stringValue ?? action.payload["id"]?.stringValue
            else { return }
            let title = prev["title"]?.stringValue
            let priority = prev["priority"]?.stringValue
            let hasDueTime = prev["hasDueTime"]?.boolValue
            let completed = prev["completed"]?.boolValue
            let dueDateMs = prev["dueDate"]?.intValue
            let dueDate = dueDateMs.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
            let notes = prev["notes"]?.stringValue
            try await taskVM.updateTask(
                id: id, title: title, priority: priority, dueDate: dueDate,
                hasDueTime: hasDueTime, completed: completed, notes: notes
            )

        default:
            break  // Delete undo not supported in Phase 5
        }
    }

    // MARK: - Private: Undo Timer

    func startUndoTimer(for context: UndoContext) {
        activeUndoAction = context
        undoSecondsRemaining = 5
        undoTask?.cancel()
        undoTask = Task {
            for secondsLeft in stride(from: 4, through: 0, by: -1) {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.undoSecondsRemaining = secondsLeft
            }
            // Timer expired — clear undo state
            guard !Task.isCancelled else { return }
            self.activeUndoAction = nil
            self.undoSecondsRemaining = 0
        }
    }

    // MARK: - Private: New Item Detection

    /// Waits up to 3 seconds for a new event to appear in the subscription that's not in `existing`.
    private func waitForNewEventId(in calVM: CalendarViewModel, excluding existing: Set<String>) async -> String? {
        for _ in 0..<6 {
            try? await Task.sleep(for: .milliseconds(500))
            if let newEvent = calVM.events.first(where: { !existing.contains($0._id) }) {
                return newEvent._id
            }
        }
        return nil
    }

    /// Waits up to 3 seconds for a new task to appear in the subscription that's not in `existing`.
    private func waitForNewTaskId(in taskVM: TaskViewModel, excluding existing: Set<String>) async -> String? {
        for _ in 0..<6 {
            try? await Task.sleep(for: .milliseconds(500))
            if let newTask = taskVM.tasks.first(where: { !existing.contains($0._id) }) {
                return newTask._id
            }
        }
        return nil
    }
}
