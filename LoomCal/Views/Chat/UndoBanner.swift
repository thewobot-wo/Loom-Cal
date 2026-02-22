import SwiftUI

// MARK: - UndoBanner

/// A persistent strip shown at the bottom of chat above the input bar during the undo window.
/// Shows a summary of the confirmed action, a countdown timer, and an Undo button.
/// Appears/disappears with a slide-from-bottom + fade transition.
struct UndoBanner: View {
    let displaySummary: String
    let secondsRemaining: Int
    var onUndo: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            Text(displaySummary)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Button {
                onUndo()
            } label: {
                Text("Undo (\(secondsRemaining)s)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.15))
        )
        .padding(.horizontal, 12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

#Preview {
    VStack {
        Spacer()
        UndoBanner(
            displaySummary: "Created: Dentist appointment",
            secondsRemaining: 4,
            onUndo: {}
        )
        .padding(.bottom, 8)
    }
    .background(Color(.systemBackground))
}
