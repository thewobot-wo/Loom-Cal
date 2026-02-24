import SwiftUI

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
                            onTap: { selectedTask = task },
                            isHighlighted: taskViewModel.highlightedTaskId == task._id
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
                                onTap: { selectedTask = task },
                                isHighlighted: taskViewModel.highlightedTaskId == task._id
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
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - AppSection

enum AppSection: Hashable {
    case calendar, tasks, chat
}

// MARK: - ContentView

/// Main app view — platform-branched navigation.
/// macOS: NavigationSplitView with sidebar (Calendar, Tasks, Loom).
/// iOS: TabView with native bottom tab bar.
/// All ViewModels live at ContentView level to prevent subscription
/// restarts on section/tab switch.
struct ContentView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @StateObject private var taskViewModel = TaskViewModel()
    @StateObject private var chatViewModel = ChatViewModel()

    @State private var showCreateSheet = false
    @State private var showTaskCreateSheet = false
    @State private var selectedEvent: LoomEvent? = nil
    @State private var selectedTask: LoomTask? = nil
    @AppStorage("notificationLeadMinutes") private var leadMinutes: Int = 15

    #if os(macOS)
    @State private var selectedSection: AppSection = .calendar
    #endif

    var body: some View {
        mainContent
            .task {
                chatViewModel.calendarViewModel = viewModel
                chatViewModel.taskViewModel = taskViewModel
                viewModel.startSubscription()
                taskViewModel.startSubscription()
                chatViewModel.startSubscription()
            }
            // MARK: Sheets (shared across platforms)
            .sheet(isPresented: $showCreateSheet) {
                EventCreationView(
                    viewModel: viewModel,
                    isPresented: $showCreateSheet
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showTaskCreateSheet) {
                TaskCreationView(
                    taskViewModel: taskViewModel,
                    isPresented: $showTaskCreateSheet
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
    }

    // MARK: - Platform Navigation

    @ViewBuilder
    private var mainContent: some View {
        #if os(macOS)
        NavigationSplitView {
            List(selection: $selectedSection) {
                Label("Calendar", systemImage: "calendar")
                    .tag(AppSection.calendar)
                Label("Tasks", systemImage: "checklist")
                    .tag(AppSection.tasks)
                Label("Loom", systemImage: "bubble.left.and.bubble.right")
                    .tag(AppSection.chat)
            }
            .navigationTitle("Loom Cal")
        } detail: {
            macOSDetail
        }
        #else
        TabView {
            // MARK: Tab 1 — Calendar

            NavigationStack {
                VStack(spacing: 0) {
                    CollapsibleCalendarHeader(
                        calendarViewModel: viewModel,
                        taskViewModel: taskViewModel
                    )
                    Divider()
                    DayEventListView(
                        calendarViewModel: viewModel,
                        taskViewModel: taskViewModel,
                        onEventTap: { event in selectedEvent = event },
                        onTaskTap: { task in selectedTask = task }
                    )
                }
                .navigationTitle("Loom Cal")
                .navigationBarTitleDisplayMode(.inline)
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
                    ToolbarItem(placement: .automatic) {
                        notificationLeadTimeMenu
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
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            Image("LoomAvatar")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                        }
                        ToolbarItem(placement: .automatic) {
                            Menu {
                                Button(role: .destructive) {
                                    chatViewModel.clearChat()
                                } label: {
                                    Label("Clear Chat", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Loom", systemImage: "bubble.left.and.bubble.right")
            }
        }
        .overlay(alignment: .bottomTrailing) {
            ChatFAB(chatViewModel: chatViewModel)
                .padding(.trailing, 20)
                .padding(.bottom, 80)
        }
        #endif
    }

    // MARK: - Notification Lead Time Menu

    private var notificationLeadTimeMenu: some View {
        Menu {
            ForEach([5, 10, 15, 30, 60], id: \.self) { minutes in
                Button {
                    leadMinutes = minutes
                    NotificationService.shared.eventLeadMinutes = minutes
                    NotificationService.shared.rescheduleEventNotifications(viewModel.events)
                } label: {
                    HStack {
                        Text("\(minutes) min before")
                        if leadMinutes == minutes {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "bell")
        }
    }

    // MARK: - macOS Detail Pane

    #if os(macOS)
    @ViewBuilder
    private var macOSDetail: some View {
        switch selectedSection {
        case .calendar:
            MacCalendarLayout(
                calendarViewModel: viewModel,
                taskViewModel: taskViewModel,
                onEventTap: { event in selectedEvent = event },
                onTaskTap: { task in selectedTask = task }
            )
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
                ToolbarItem(placement: .automatic) {
                    notificationLeadTimeMenu
                }
            }
        case .tasks:
            TaskListTabView(taskViewModel: taskViewModel)
        case .chat:
            ChatView(chatViewModel: chatViewModel)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Image("LoomAvatar")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    }
                    ToolbarItem(placement: .automatic) {
                        Menu {
                            Button(role: .destructive) {
                                chatViewModel.clearChat()
                            } label: {
                                Label("Clear Chat", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
        }
    }
    #endif
}

#Preview {
    ContentView()
}
