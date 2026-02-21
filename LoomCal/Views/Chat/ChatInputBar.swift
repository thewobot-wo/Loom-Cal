import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    let isEnabled: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField(
                isEnabled ? "Message Loom..." : "Loom is offline",
                text: $text
            )
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .disabled(!isEnabled)
            .onSubmit {
                if isEnabled && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    onSend()
                }
            }

            // Send button
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isEnabled
                            ? Color.gray
                            : Color.accentColor
                    )
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isEnabled)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
