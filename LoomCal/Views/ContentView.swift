import SwiftUI

// MARK: - ViewMode

enum ViewMode: String, CaseIterable {
    case today = "Today"   // unified event+task timeline (replaces .day)
    case week = "Week"
}

// MARK: - ContentView

/// Main app view — Morgen-inspired layout:
/// - Today mode: mini month at top + unified event+task timeline below
/// - Week mode: week header row replaces mini month, week timeline fills remaining space
struct ContentView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @StateObject private var taskViewModel = TaskViewModel()

    @State private var viewMode: ViewMode = .today
    @State private var showCreateSheet = false
    @State private var showTaskCreateSheet = false
    @State private var selectedEvent: LoomEvent? = nil
    @State private var selectedTask: LoomTask? = nil
    @State private var createPrefilledDate: Date? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented Today/Week control
                Picker("View", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 6)

                // Today mode: show mini month for date picking
                // Week mode: mini month hidden — week header is the navigation
                if viewMode == .today {
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
                case .today:
                    TodayView(
                        calendarViewModel: viewModel,
                        taskViewModel: taskViewModel,
                        onEventTap: { event in selectedEvent = event },
                        onTaskTap: { task in selectedTask = task },
                        onEventDragMove: { event, pointsDelta in
                            handleDragMove(event: event, pointsDelta: pointsDelta)
                        }
                    )
                case .week:
                    WeekTimelineView(
                        viewModel: viewModel,
                        taskViewModel: taskViewModel,
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
                    Menu {
                        Button {
                            showCreateSheet = true
                        } label: {
                            Label("New Event", systemImage: "calendar.badge.plus")
                        }
                        Button {
                            showTaskCreateSheet = true
                        } label: {
                            Label("New Task", systemImage: "checkmark.circle")
                        }
                    } label: {
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
            taskViewModel.startSubscription()
        }
        .sheet(isPresented: $showCreateSheet) {
            EventCreationView(
                viewModel: viewModel,
                isPresented: $showCreateSheet,
                prefilledDate: createPrefilledDate
            )
        }
        .sheet(isPresented: $showTaskCreateSheet) {
            TaskCreationView(
                taskViewModel: taskViewModel,
                isPresented: $showTaskCreateSheet
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
        .sheet(item: $selectedTask) { task in
            TaskDetailView(
                task: task,
                taskViewModel: taskViewModel,
                isPresented: .init(
                    get: { selectedTask != nil },
                    set: { if !$0 { selectedTask = nil } }
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
