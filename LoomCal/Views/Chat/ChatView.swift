import SwiftUI

struct ChatView: View {
    @ObservedObject var chatViewModel: ChatViewModel
    @State private var inputText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Offline banner
            if !chatViewModel.isLoomAvailable {
                HStack {
                    Image(systemName: "wifi.slash")
                    Text("Loom is offline")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.orange)
            }

            // Message list or empty state
            if chatViewModel.messages.isEmpty && !chatViewModel.isLoading {
                // Empty state: suggestion chips
                Spacer()
                SuggestionChipsView { suggestion in
                    inputText = ""
                    chatViewModel.sendMessage(suggestion)
                }
                Spacer()
            } else {
                // Message list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(groupedMessages) { group in
                                // Time gap header
                                Text(group.timestamp)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)

                                ForEach(group.messages) { message in
                                    if message.isDailyPlan {
                                        DailyPlanCard(
                                            message: message,
                                            onApprove: { chatViewModel.approveDailyPlan(message) },
                                            onReject: { chatViewModel.rejectDailyPlan(message) }
                                        )
                                        .id(message.id)
                                    } else if message.role == "pending_action" {
                                        ActionConfirmationCard(
                                            message: message,
                                            onConfirm: { chatViewModel.confirmAction(message) },
                                            onCancel: { chatViewModel.cancelAction(message) }
                                        )
                                        .id(message.id)
                                    } else {
                                        ChatBubbleView(
                                            message: message,
                                            voiceService: chatViewModel.voiceService,
                                            onPlayTap: { chatViewModel.playMessage(message) }
                                        )
                                        .id(message.id)
                                    }
                                }
                            }

                            // Timeout error bubble
                            if !chatViewModel.timedOutMessageIds.isEmpty {
                                timeoutBubble
                            }

                            // Typing indicator (pending reply)
                            if chatViewModel.pendingMessageContent != nil {
                                TypingIndicatorView()
                                    .id("typing-indicator")
                                    .transition(.opacity)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                    }
                    .defaultScrollAnchor(.bottom)
                    .scrollDismissesKeyboard(.interactively)
                    .onTapGesture {
                        #if canImport(UIKit)
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        #endif
                    }
                    .onChange(of: chatViewModel.messages.count) {
                        withAnimation {
                            if let lastId = chatViewModel.messages.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: chatViewModel.pendingMessageContent) { _, newValue in
                        if newValue != nil {
                            withAnimation {
                                proxy.scrollTo("typing-indicator", anchor: .bottom)
                            }
                        }
                    }
                }
            }

            // Undo banner — appears above divider during the undo window
            if let undo = chatViewModel.activeUndoAction {
                UndoBanner(
                    displaySummary: undo.displaySummary,
                    secondsRemaining: chatViewModel.undoSecondsRemaining,
                    onUndo: { chatViewModel.undoAction() }
                )
                .animation(.easeInOut(duration: 0.2), value: chatViewModel.activeUndoAction != nil)
                .padding(.bottom, 4)
            }

            Divider()

            // Voice toggle + Input bar
            HStack {
                Spacer()
                Button {
                    chatViewModel.voiceEnabled.toggle()
                } label: {
                    Image(systemName: chatViewModel.voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.caption)
                        .foregroundStyle(chatViewModel.voiceEnabled ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing)
                .padding(.top, 4)
            }

            ChatInputBar(
                text: $inputText,
                isEnabled: chatViewModel.isLoomAvailable,
                onSend: {
                    let content = inputText
                    inputText = ""
                    chatViewModel.sendMessage(content)
                }
            )
        }
    }

    // MARK: - Timeout Error Bubble

    private var timeoutBubble: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Loom didn't respond. Tap to retry.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .onTapGesture {
                        if let lastUserMessage = chatViewModel.messages.last(where: { $0.role == "user" }) {
                            chatViewModel.retryMessage(lastUserMessage.content)
                        }
                    }
            }

            Spacer(minLength: 60)
        }
    }

    // MARK: - Message Grouping

    private var groupedMessages: [MessageGroup] {
        guard !chatViewModel.messages.isEmpty else { return [] }

        var groups: [MessageGroup] = []
        var currentMessages: [ChatMessage] = []
        var currentTimestamp: Date?
        let threshold: TimeInterval = 300 // 5-minute gap threshold

        for message in chatViewModel.messages {
            let messageDate = Date(timeIntervalSince1970: TimeInterval(message.sentAt) / 1000)

            if let last = currentTimestamp,
               messageDate.timeIntervalSince(last) > threshold {
                // Gap — flush current group
                if !currentMessages.isEmpty {
                    groups.append(MessageGroup(
                        timestamp: formatTimestamp(currentMessages.first!),
                        messages: currentMessages
                    ))
                    currentMessages = []
                }
            }

            if currentMessages.isEmpty {
                currentTimestamp = messageDate
            }
            currentMessages.append(message)
        }

        // Flush remaining
        if !currentMessages.isEmpty {
            groups.append(MessageGroup(
                timestamp: formatTimestamp(currentMessages.first!),
                messages: currentMessages
            ))
        }

        return groups
    }

    private func formatTimestamp(_ message: ChatMessage) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(message.sentAt) / 1000)
        let formatter = DateFormatter()

        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else if Calendar.current.isDateInYesterday(date) {
            formatter.dateFormat = "'Yesterday' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }

        return formatter.string(from: date)
    }
}

// MARK: - MessageGroup

struct MessageGroup: Identifiable {
    let id = UUID()
    let timestamp: String
    let messages: [ChatMessage]
}
