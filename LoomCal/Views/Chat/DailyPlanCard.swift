import SwiftUI

// MARK: - DailyPlanCard

/// Inline card rendered in the chat stream for daily plan proposals.
/// Shows proposed time blocks with Approve/Reject buttons while pending,
/// and collapses to a compact status line after resolution.
struct DailyPlanCard: View {
    let message: ChatMessage
    var onApprove: () -> Void = {}
    var onReject: () -> Void = {}

    private var plan: DailyPlanProposal? {
        message.decodedPlan
    }

    private var actionStatus: String {
        message.actionStatus ?? "pending"
    }

    var body: some View {
        if actionStatus != "pending" {
            collapsedCard
        } else {
            expandedCard
        }
    }

    // MARK: - Expanded Card (Pending)

    private var expandedCard: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                if let plan = plan {
                    cardHeader

                    Text(plan.displaySummary)
                        .font(.body)
                        .foregroundStyle(.primary)

                    blocksSection(blocks: plan.payload.blocks)

                    actionButtons
                } else {
                    Text(message.content)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.leading, 8)
            .padding(.trailing, 60)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Collapsed Card (Resolved)

    private var collapsedCard: some View {
        HStack(alignment: .top, spacing: 0) {
            HStack(spacing: 6) {
                statusIcon
                Text(plan?.displaySummary ?? message.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.05))
            )
            .padding(.leading, 8)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Status Icon

    @ViewBuilder
    private var statusIcon: some View {
        switch actionStatus {
        case "confirmed":
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case "cancelled":
            Image(systemName: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        case "undone":
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        default:
            EmptyView()
        }
    }

    // MARK: - Header

    private var cardHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar.day.timeline.leading")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            Text("DAILY PLAN")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.accentColor)
                .textCase(.uppercase)
        }
    }

    // MARK: - Blocks List

    @ViewBuilder
    private func blocksSection(blocks: [PlannedBlock]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(blocks) { block in
                blockRow(block)
            }
        }
    }

    private func blockRow(_ block: PlannedBlock) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 14)

            Text(formatTimeRange(start: block.startDate, end: block.endDate))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 100, alignment: .leading)

            Text(block.title)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(block.durationFormatted)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.gray.opacity(0.1))
                )
        }
    }

    // MARK: - Buttons

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                onApprove()
            } label: {
                Label("Approve", systemImage: "checkmark")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)

            Button {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                onReject()
            } label: {
                Text("Reject")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)

            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    // MARK: - Time Formatter

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    private func formatTimeRange(start: Date, end: Date) -> String {
        let s = Self.timeFormatter.string(from: start)
        let e = Self.timeFormatter.string(from: end)
        return "\(s) – \(e)"
    }
}
