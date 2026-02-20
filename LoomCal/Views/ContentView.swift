import SwiftUI

// MARK: - ViewMode

/// Determines which timeline is displayed below the mini month.
enum ViewMode: String, CaseIterable {
    case day = "Day"
    case week = "Week"
}

// MARK: - ContentView

/// Main app view — Fantastical-style layout:
/// - NavigationStack with Today + plus toolbar buttons
/// - Segmented Day/Week control at top
/// - MiniMonthView always visible below the control
/// - DayTimelineView or WeekTimelineView below the mini month
/// - EventCreationView sheet on plus button tap (or long-press on mini month date)
/// - EventDetailView sheet on event card tap (via .sheet(item: $selectedEvent))
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

                // Mini month (always visible)
                MiniMonthView(
                    viewModel: viewModel,
                    onDateLongPress: { date in
                        createPrefilledDate = date
                        showCreateSheet = true
                    }
                )

                Divider()

                // Timeline: day or week based on segmented control
                Group {
                    switch viewMode {
                    case .day:
                        DayTimelineView(
                            events: viewModel.timedEvents(for: viewModel.selectedDate),
                            allDayEvents: viewModel.allDayEvents(for: viewModel.selectedDate),
                            onEventTap: { event in
                                selectedEvent = event
                            },
                            onEventDragMove: { event, pointsDelta in
                                handleDragMove(event: event, pointsDelta: pointsDelta)
                            }
                        )
                    case .week:
                        WeekTimelineView(
                            viewModel: viewModel,
                            onEventTap: { event in
                                selectedEvent = event
                            }
                        )
                    }
                }
                // Swipe left/right to navigate days or weeks
                .gesture(
                    DragGesture(minimumDistance: 40)
                        .onEnded { value in
                            let xDelta = value.translation.width
                            // Only handle horizontal swipes (not accidentally triggering on drag-to-move)
                            guard abs(xDelta) > abs(value.translation.height) else { return }

                            let daysToAdvance: Int = viewMode == .week ? 7 : 1
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if xDelta < 0 {
                                    // Swipe left — advance forward
                                    viewModel.selectedDate = Calendar.current.date(
                                        byAdding: .day,
                                        value: daysToAdvance,
                                        to: viewModel.selectedDate
                                    ) ?? viewModel.selectedDate
                                } else {
                                    // Swipe right — go back
                                    viewModel.selectedDate = Calendar.current.date(
                                        byAdding: .day,
                                        value: -daysToAdvance,
                                        to: viewModel.selectedDate
                                    ) ?? viewModel.selectedDate
                                }
                            }
                        }
                )
            }
            .navigationTitle("Loom Cal")
            .navigationBarTitleDisplayMode(.inline)
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
        // Start Convex subscription when app appears
        .task {
            viewModel.startSubscription()
        }
        // Event creation sheet
        .sheet(isPresented: $showCreateSheet) {
            EventCreationView(
                viewModel: viewModel,
                isPresented: $showCreateSheet,
                prefilledDate: createPrefilledDate
            )
        }
        // Event detail sheet — LoomEvent conforms to Identifiable for .sheet(item:)
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
        // Reset prefilled date when creation sheet closes
        .onChange(of: showCreateSheet) { _, isShowing in
            if !isShowing {
                createPrefilledDate = nil
            }
        }
    }

    // MARK: - Drag to Move

    /// Converts a vertical point delta from a drag gesture into a time update.
    /// Uses DayTimelineView's pointsPerHour (60) to compute minutes moved.
    /// Snaps to nearest 15-minute boundary.
    private func handleDragMove(event: LoomEvent, pointsDelta: CGFloat) {
        let pointsPerHour: CGFloat = 60.0
        let rawMinutesDelta = pointsDelta / pointsPerHour * 60.0
        // Snap to nearest 15 minutes
        var minutesDelta = Int(round(rawMinutesDelta / 15.0)) * 15

        // Compute new start time
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
