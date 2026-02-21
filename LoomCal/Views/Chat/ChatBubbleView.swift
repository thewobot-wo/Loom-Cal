import SwiftUI
import MarkdownUI

struct ChatBubbleView: View {
    let message: ChatMessage

    var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 60) }

            // Loom avatar — purple circle with "L"
            if !isUser {
                Circle()
                    .fill(Color.purple.gradient)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text("L")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    )
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 2) {
                // Loom name label
                if !isUser {
                    Text("Loom")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Bubble content
                Group {
                    if isUser {
                        Text(message.content)
                            .foregroundStyle(.white)
                    } else {
                        Markdown(message.content)
                            .markdownTextStyle {
                                ForegroundColor(Color.primary)
                            }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isUser ? Color.accentColor : Color.gray.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }
}
