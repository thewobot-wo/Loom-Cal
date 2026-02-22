#if os(macOS)
import SwiftUI

/// Fantastical-style toolbar for macOS calendar: nav arrows, today, date, mode picker.
struct CalendarToolbar: View {
    @ObservedObject var viewModel: CalendarViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Navigation chevrons
            Button { viewModel.navigateBackward() } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.plain)

            Button("Today") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.selectedDate = .now
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(LoomColors.coral)
            .fontWeight(.medium)

            Button { viewModel.navigateForward() } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.plain)

            // Day number circle
            let dayNum = Calendar.current.component(.day, from: viewModel.selectedDate)
            Text("\(dayNum)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(LoomColors.coral))

            // Date title
            Text(viewModel.toolbarTitle)
                .font(.headline)
                .lineLimit(1)

            Spacer()

            // View mode picker
            Picker("View", selection: $viewModel.viewMode) {
                ForEach(CalendarViewMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)

            // Search placeholder
            Button {
                // TODO: wire search
            } label: {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.background)
    }
}
#endif
