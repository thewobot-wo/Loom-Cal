import SwiftUI

// MARK: - ViewMode

enum ViewMode: String, CaseIterable {
    case today = "Today"   // unified event+task timeline (replaces .day)
    case week = "Week"
}

// MARK: - TaskListTabView

/// Simple full task list for the Tasks tab.
/// Shows incomplete tasks (sorted by priority then due date) followed
/// by a collapsed Completed section. Supports task creation and detail sheets.
struct TaskListTabView: View {
    @ObservedObject var taskViewModel: TaskViewModel

    @State private var showTaskCreateSheet = false
    @State private var selectedTask: LoomTask? = nil
    @State private var showCompleted = false

    /// Incomplete tasks sorted: high → medium → low, then by due date ascending
    private var incompleteTasks: [LoomTask] {
        taskViewModel.activeTasks.sorted { a, b in
            let priorityOrder = ["high": 0, "medium": 1, "low": 2]
            let aPriority = priorityOrder[a.priority] ?? 2
            let bPriority = priorityOrder[b.priority] ?? 2
            if aPriority != bPriority { return aPriority < bPriority }
            // Same priority — sort by due date (tasks without due date last)
            switch (a.dueDate, b.dueDate) {
            case (nil, nil): return false
            case (nil, _): return false
            case (_, nil): return true
            case (let aMs?, let bMs?): return aMs < bMs
            }
        }
    }

    private var completedTasks: [LoomTask] {
        taskViewModel.completedTasks
    }

    var body: some View {
        List {
            // Incomplete tasks
            if incompleteTasks.isEmpty && !taskViewModel.isLoading {
                Section {
                    Text("No tasks — tap + to add one")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(incompleteTasks) { task in
                        TaskRowView(
                            task: task,
                            onComplete: {
                                Task { try? await taskViewModel.toggleComplete(task: task) }
                            },
                            onTap: { selectedTask = task }
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                    }
                }
            }

            // Completed tasks section (collapsible)
            if !completedTasks.isEmpty {
                Section {
                    if showCompleted {
                        ForEach(completedTasks) { task in
                            TaskRowView(
                                task: task,
                                onComplete: {
                                    Task { try? await taskViewModel.toggleComplete(task: task) }
                                },
                                onTap: { selectedTask = task }
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                        }
                    }
                } header: {
                    Button {
                        withAnimation { showCompleted.toggle() }
                    } label: {
                        HStack {
                            Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                                .font(.caption)
                            Text("Completed (\(completedTasks.count))")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Tasks")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showTaskCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showTaskCreateSheet) {
            TaskCreationView(
                taskViewModel: taskViewModel,
                isPresented: $showTaskCreateSheet
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
    }
}

// MARK: - ContentView

/// Main app view — TabView with Calendar, Tasks, and Chat tabs.
/// All ViewModels live at ContentView level to prevent subscription
/// restarts on tab switch (pitfall #1 from research).
struct ContentView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @StateObject private var taskViewModel = TaskViewModel()
    @StateObject private var chatViewModel = ChatViewModel()

    @State private var viewMode: ViewMode = .today
    @State private var showCreateSheet = false
    @State private var showTaskCreateSheet = false
    @State private var selectedEvent: LoomEvent? = nil
    @State private var selectedTask: LoomTask? = nil
    @State private var createPrefilledDate: Date? = nil

    var body: some View {
        TabView {
            // MARK: Tab 1 — Calendar

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
            .tabItem {
                Label("Calendar", systemImage: "calendar")
            }

            // MARK: Tab 2 — Tasks

            NavigationStack {
                TaskListTabView(taskViewModel: taskViewModel)
            }
            .tabItem {
                Label("Tasks", systemImage: "checklist")
            }

            // MARK: Tab 3 — Chat

            NavigationStack {
                ChatView(chatViewModel: chatViewModel)
                    .navigationTitle("Loom")
                    #if !os(macOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
            }
            .tabItem {
                Label("Loom", systemImage: "bubble.left.and.bubble.right")
            }
        }
        .task {
            viewModel.startSubscription()
            taskViewModel.startSubscription()
            chatViewModel.startSubscription()
        }
        // MARK: Calendar sheets
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
        // MARK: FAB overlay (iOS only)
        #if !os(macOS)
        .overlay(alignment: .bottomTrailing) {
            ChatFAB(chatViewModel: chatViewModel)
                .padding(.trailing, 20)
                .padding(.bottom, 80) // above tab bar
        }
        #endif
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
