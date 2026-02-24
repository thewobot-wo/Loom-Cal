import SwiftUI
import MarkdownUI

struct ChatBubbleView: View {
    let message: ChatMessage
    @ObservedObject var voiceService: VoiceService
    var onPlayTap: (() -> Void)?

    var isUser: Bool { message.role == "user" }

    private var isThisPlaying: Bool {
        voiceService.playingMessageId == message._id
    }

    private var isThisLoading: Bool {
        voiceService.isLoadingAudio && voiceService.playingMessageId == nil
    }

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

                // Play/pause button for assistant messages with audio
                if !isUser, message.audioUrl != nil {
                    Button {
                        onPlayTap?()
                    } label: {
                        HStack(spacing: 4) {
                            if isThisLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: isThisPlaying ? "pause.circle.fill" : "play.circle.fill")
                            }
                            if isThisPlaying {
                                Text("Playing")
                                    .font(.caption2)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 4)
                }
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }
}
