import SwiftUI

// MARK: - ViewMode

enum ViewMode: String, CaseIterable {
    case day = "Day"
    case week = "Week"
}

// MARK: - ContentView

/// Main app view — Morgen-inspired layout:
/// - Day mode: mini month at top + day timeline below
/// - Week mode: week header row replaces mini month, week timeline fills remaining space
struct ContentView: View {
    @StateObject private var viewModel = CalendarViewModel()

    @State private var viewMode: ViewMode = .day
    @State private var showCreateSheet = false
    @State private var selectedEvent: LoomEvent? = nil
    @State private var createPrefilledDate: Date? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented Day/Week control
                Picker("View", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 6)

                // Day mode: show mini month for date picking
                // Week mode: mini month hidden — week header is the navigation
                if viewMode == .day {
                    MiniMonthView(
                        viewModel: viewModel,
                        onDateLongPress: { date in
                            createPrefilledDate = date
                            showCreateSheet = true
                        }
                    )
                    Divider()
                }

                // Timeline
                switch viewMode {
                case .day:
                    DayTimelineView(
                        events: viewModel.timedEvents(for: viewModel.selectedDate),
                        allDayEvents: viewModel.allDayEvents(for: viewModel.selectedDate),
                        onEventTap: { event in selectedEvent = event },
                        onEventDragMove: { event, pointsDelta in
                            handleDragMove(event: event, pointsDelta: pointsDelta)
                        }
                    )
                case .week:
                    WeekTimelineView(
                        viewModel: viewModel,
                        onEventTap: { event in selectedEvent = event }
                    )
                }
            }
            .navigationTitle("Loom Cal")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showCreateSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigation) {
                    Button("Today") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedDate = .now
                        }
                    }
                }
            }
        }
        .task {
            viewModel.startSubscription()
        }
        .sheet(isPresented: $showCreateSheet) {
            EventCreationView(
                viewModel: viewModel,
                isPresented: $showCreateSheet,
                prefilledDate: createPrefilledDate
            )
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(
                event: event,
                viewModel: viewModel,
                isPresented: .init(
                    get: { selectedEvent != nil },
                    set: { if !$0 { selectedEvent = nil } }
                )
            )
        }
        .onChange(of: showCreateSheet) { _, isShowing in
            if !isShowing { createPrefilledDate = nil }
        }
    }

    // MARK: - Drag to Move

    private func handleDragMove(event: LoomEvent, pointsDelta: CGFloat) {
        let pointsPerHour: CGFloat = 60.0
        let rawMinutesDelta = pointsDelta / pointsPerHour * 60.0
        let minutesDelta = Int(round(rawMinutesDelta / 15.0)) * 15
        let originalStart = Date(timeIntervalSince1970: TimeInterval(event.start) / 1000)
        let newStart = originalStart.addingTimeInterval(Double(minutesDelta) * 60)
        Task {
            try? await viewModel.updateEvent(id: event._id, start: newStart)
        }
    }
}

#Preview {
    ContentView()
}
