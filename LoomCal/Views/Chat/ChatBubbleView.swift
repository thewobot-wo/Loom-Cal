import SwiftUI
import MarkdownUI

struct ChatBubbleView: View {
    let message: ChatMessage

    var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 2) {
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
