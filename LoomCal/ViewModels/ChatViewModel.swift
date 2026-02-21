import SwiftUI
import ConvexMobile

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading: Bool = true
    @Published var pendingMessageContent: String? = nil    // content of user message awaiting Loom reply
    @Published var isLoomAvailable: Bool = true            // false when timeout fires or send fails
    @Published var timedOutMessageIds: Set<String> = []    // messages that got no reply — shows retry bubble

    private var subscriptionTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?

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

                // If a new assistant message arrived, clear pending state and timeout
                if result.count > previousCount,
                   let lastMessage = result.last,
                   lastMessage.role == "assistant" {
                    self.pendingMessageContent = nil
                    self.timeoutTask?.cancel()
                    self.timeoutTask = nil
                    // Loom replied successfully — mark available
                    if !self.isLoomAvailable {
                        self.isLoomAvailable = true
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
    }

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
                // Mutation succeeded — start the 8-second reply timeout
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

    private func startReplyTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task {
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            // No reply arrived within 8 seconds
            self.isLoomAvailable = false
            if let content = self.pendingMessageContent {
                self.timedOutMessageIds.insert(content)
            }
            self.pendingMessageContent = nil
        }
    }
}
