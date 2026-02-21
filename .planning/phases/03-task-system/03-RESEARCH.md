# Phase 3: Task System - Research

**Researched:** 2026-02-20
**Domain:** SwiftUI task list UI, time-blocking drag gesture, Convex schema migration, Today view design
**Confidence:** HIGH (codebase fully inspected, patterns verified against existing Phase 2 implementations)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Task list presentation**
- Compact rows (Things 3 style) — title, due date chip, priority indicator on one line
- Colored left edge for priority: red = high, yellow = medium, blue/none = low
- Default view is the Today view (see below)
- Filter/sort by priority available within Phase 3 scope
- Tags and project grouping are deferred to v2

**Task completion behavior**
- Fade + strikethrough animation on tap complete
- Task stays visible briefly with undo option
- Then moves to a collapsed "Completed" section at the bottom

**Today view design**
- Interleaved timeline — events and tasks mixed on one timeline sorted by time
- Unscheduled tasks (no specific time) appear in a compact section at the top of the timeline, above the first timed event
- Today view replaces the current day view as the app's default landing screen (day view becomes redundant since Today includes the full timeline plus tasks)

**Calendar task markers — day view**
- Tasks with a due time appear as inline compact rows directly in the timeline at their due time — visually lighter than events
- Tasks with a due date but no time appear at the top of the day, above the timeline (same pattern as unscheduled tasks in Today view)

**Calendar task markers — week view**
- Small colored dot(s) under the day number indicating tasks are due that day
- Tap the day to see task details — keeps week view clean

**Overdue task handling**
- Overdue tasks flagged in the task list only (red/distinct styling)
- Calendar views show tasks on their actual due date, not on today

**Time-blocking interaction**
- Drag source: from the unscheduled task section at the top of the Today view, drop onto a time slot in the timeline below
- Default time block duration: 1 hour (user can resize after dropping)
- After time-blocking: task stays in the task list (now with a time indicator) AND appears as a block on the calendar timeline — completing either completes both
- Multiple time blocks per task allowed — useful for tasks spanning multiple work sessions, all blocks link back to the same task

### Claude's Discretion
- Visual treatment for time-blocked tasks vs regular events on the timeline (must be clearly distinct)
- Exact spacing, typography, and animation timing
- Task creation form design (quick-add vs full form)
- Error states and edge cases
- How task-event linking is stored in Convex schema

### Deferred Ideas (OUT OF SCOPE)
- Tags and tag-based filtering — v2 (TSKV-02 or new requirement)
- Project grouping for tasks — v2 (TSKV-02)
- Subtasks and checklists — v2 (TSKV-01)
- Multi-day upcoming view (Things 3 style) — v2 (TSKV-03)
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| TASK-01 | User can create tasks with title, due date, and priority | Requires Convex schema migration to add `priority` field (replacing `flagged`); TaskCreationView following EventCreationView pattern; `tasks:create` mutation update |
| TASK-02 | User can edit task details | TaskEditView following EventEditView pattern; `tasks:update` mutation already exists; priority picker needed |
| TASK-03 | User can mark tasks as complete | Toggle `completed` on existing `tasks:update` mutation; SwiftUI `.strikethrough` + `.opacity` animation + delayed move to completed section |
| TASK-04 | User can delete tasks | `.alert` modifier (per project pattern — not `.confirmationDialog`); `tasks:remove` mutation already exists |
| TASK-05 | Task due dates appear as markers on calendar views | Day view: inline compact row at due time or top-of-day banner; Week view: colored dot in day header cell; TaskViewModel provides filtered tasks-by-date queries |
| TASK-06 | User can drag a task onto a calendar slot to time-block it | `DragGesture` (not `Transferable`) — source in unscheduled task section, drop target is timeline ZStack; coordinate mapping from drag end position to time slot; `events:create` mutation creates linked event with `taskId` foreign key |
| TASK-07 | Today view shows current-day events and tasks due today in a single unified list | New TodayView replacing DayTimelineView as default; merge events and tasks into unified timeline sorted by time; unscheduled tasks section above first timed item; ContentView restructure |
</phase_requirements>

---

## Summary

Phase 3 builds the full task system on top of the Convex backend and calendar views from Phases 1 and 2. The architecture is clean and follows well-established Phase 2 patterns: a TaskViewModel (parallel to CalendarViewModel) owns the Convex subscription for tasks, and UI views follow the same Form/Sheet patterns used for events.

The most technically interesting piece is time-blocking drag. The existing codebase already uses `LongPressGesture.sequenced(before: DragGesture)` in `TimelineEventCard.swift` for drag-to-move events — the same gesture pattern applies for drag-from-task-list-to-timeline. The drop target is the timeline `ZStack`, which resolves global DragGesture coordinates via a `GeometryReader`. This is fully custom SwiftUI (no `Transferable`/`dropDestination`) because the drop target is inside a `ScrollView`, where `dropDestination` is unreliable on iOS.

There is one critical pre-work item: the existing Convex schema has `flagged: Bool` for tasks (no priority tiers), but CONTEXT.md requires high/medium/low priority. This requires a schema migration (`v.union(v.literal("high"), v.literal("medium"), v.literal("low"))`) and updates to both `LoomTask.swift` and `tasks.ts` before any other work begins. The `events` schema also needs a `taskId: v.optional(v.id("tasks"))` field to link time-blocked calendar events back to their source tasks.

The Today view is the most visible architectural change: it replaces the existing Day view as the default landing screen. `ContentView.swift` currently has a `ViewMode` enum (`day`, `week`). This needs a third option `today` (or the Day mode replaced by a Today mode that incorporates the task panel).

**Primary recommendation:** Follow Phase 2's proven patterns exactly. Schema migration first (priority + taskId fields), then TaskViewModel, then task CRUD views, then calendar integration, then Today view. The drag-to-block is the only genuinely new SwiftUI pattern — implement it using the same `LongPressGesture.sequenced(before: DragGesture)` approach already present in `TimelineEventCard`.

---

## Critical Pre-Work: Schema Migration

### Problem: Existing Schema Does Not Support Priority Tiers

The current `LoomTask.swift` and `convex/tasks.ts` both use `flagged: Bool` instead of priority levels. This was the original design decision (visible in STATE.md: "[Plan 01-01]: LoomTask.flagged is a boolean flag — no priority tiers"). The CONTEXT.md for Phase 3 explicitly overrides this with high/medium/low priority.

**Schema must change before any Phase 3 UI work begins.**

### Required Convex Schema Changes

**`convex/schema.ts` — tasks table:**
```typescript
// BEFORE (existing)
tasks: defineTable({
  title: v.string(),
  dueDate: v.optional(v.int64()),
  flagged: v.boolean(),           // ← must be replaced
  completed: v.boolean(),
  notes: v.optional(v.string()),
  attachments: v.optional(v.array(v.string())),
})

// AFTER (Phase 3)
tasks: defineTable({
  title: v.string(),
  dueDate: v.optional(v.int64()),           // UTC milliseconds, unchanged
  dueTime: v.optional(v.int64()),           // UTC milliseconds for time portion (new)
  priority: v.union(
    v.literal("high"),
    v.literal("medium"),
    v.literal("low")
  ),                                        // replaces flagged
  completed: v.boolean(),
  notes: v.optional(v.string()),
  attachments: v.optional(v.array(v.string())),
})
  .index("by_due_date", ["dueDate"])
  .index("by_completed", ["completed"])
  .index("by_priority", ["priority"])       // new index
```

Note on `dueTime`: The CONTEXT.md distinguishes "tasks with a due time" from "tasks with a due date but no time." The simplest representation that avoids parsing is two fields: `dueDate` (date-only, UTC ms for midnight of that day) and an optional `dueTime` (UTC ms with the actual hour/minute). Alternatively, `dueDate` stores the full datetime when a time is set and a separate `hasTime: Bool` flag signals whether to show it on the timeline vs. top-of-day. Research recommendation: use a single `dueDate` field that stores a full UTC ms timestamp plus a boolean `hasDueTime` flag. This avoids ambiguity and mirrors how `LoomEvent.isAllDay` works in the existing events schema.

**`convex/events.ts` — add taskId foreign key for time-blocking:**
```typescript
// In events table schema (schema.ts):
events: defineTable({
  // ...existing fields...
  taskId: v.optional(v.id("tasks")),        // new: links time-block back to source task
})
```

**`LoomTask.swift` — updated Swift model:**
```swift
struct LoomTask: Decodable, Identifiable {
    let _id: String
    var id: String { _id }  // Identifiable — matches LoomEvent pattern
    let title: String
    @OptionalConvexInt var dueDate: Int?    // UTC ms — v.optional(v.int64())
    let hasDueTime: Bool                    // true if dueDate includes time component
    let priority: String                    // "high" | "medium" | "low"
    let completed: Bool
    let notes: String?
    let attachments: [String]?
}
```

The `priority` field is `String` (not an enum) to match Decodable without custom coding. Add a computed helper:
```swift
extension LoomTask {
    var priorityColor: Color {
        switch priority {
        case "high": return .red
        case "medium": return .yellow
        default: return .blue.opacity(0.6)  // low or unrecognized
        }
    }
}
```

**`LoomEvent.swift` — add taskId:**
```swift
struct LoomEvent: Decodable, Identifiable {
    // ...existing fields...
    let taskId: String?    // links time-blocked events to their source task
}
```

---

## Architecture Patterns

### Recommended Project Structure (new files)

```
LoomCal/
├── Models/
│   └── LoomTask.swift          ← update: priority replaces flagged, add hasDueTime, add Identifiable
├── Models/
│   └── LoomEvent.swift         ← update: add taskId: String?
├── ViewModels/
│   └── TaskViewModel.swift     ← new: parallel to CalendarViewModel
├── Views/
│   ├── ContentView.swift       ← update: add Today tab, restructure ViewMode
│   ├── Today/
│   │   └── TodayView.swift     ← new: unified event+task timeline
│   ├── Tasks/
│   │   ├── TaskListView.swift  ← new: standalone task list (for non-Today access)
│   │   ├── TaskRowView.swift   ← new: compact Things 3-style row
│   │   ├── TaskCreationView.swift  ← new: quick-add + full form
│   │   └── TaskDetailView.swift    ← new: edit + complete + delete
│   └── Calendar/
│       ├── DayTimelineView.swift   ← update: add task markers
│       └── WeekTimelineView.swift  ← update: add task dot indicators
└── convex/
    ├── schema.ts               ← update: priority, hasDueTime, taskId
    └── tasks.ts                ← update: create/update mutations for new fields
```

### Pattern 1: TaskViewModel (mirrors CalendarViewModel exactly)

```swift
// Source: CalendarViewModel.swift — follow identical pattern
@MainActor
class TaskViewModel: ObservableObject {
    @Published var tasks: [LoomTask] = []
    @Published var isLoading: Bool = true
    private var subscriptionTask: Task<Void, Never>?

    func startSubscription() {
        subscriptionTask?.cancel()
        subscriptionTask = Task {
            for await result: [LoomTask] in convex
                .subscribe(to: "tasks:list")
                .replaceError(with: [])
                .values
            {
                guard !Task.isCancelled else { break }
                self.tasks = result
                self.isLoading = false
            }
        }
    }

    func stopSubscription() {
        subscriptionTask?.cancel()
        subscriptionTask = nil
    }

    // Date helpers
    func tasks(dueOn date: Date) -> [LoomTask] { ... }
    func tasksWithTime(dueOn date: Date) -> [LoomTask] { ... }
    func unscheduledTasks(dueOn date: Date) -> [LoomTask] { ... }
    func overdueTasks() -> [LoomTask] { ... }

    // CRUD mutations — use [String: ConvexEncodable?] typed args
    func createTask(title: String, priority: String, dueDate: Date?, hasDueTime: Bool) async throws { ... }
    func updateTask(id: String, title: String?, priority: String?, dueDate: Date?, completed: Bool?) async throws { ... }
    func deleteTask(id: String) async throws { ... }
}
```

**Critical:** Both `CalendarViewModel` and `TaskViewModel` must be instantiated at the top of the view hierarchy and passed down. Do NOT create a new TaskViewModel inside individual task rows — this causes subscription leaks (established anti-pattern from PITFALLS.md).

### Pattern 2: Task Completion Animation

SwiftUI iOS 17+ supports `withAnimation(_:completionCriteria:_:completion:)` for chained animations. Use this for the fade+strikethrough then move-to-completed sequence:

```swift
// Source: Apple Developer Documentation (withAnimation completionCriteria)
@State private var isCompleted = false
@State private var isVisible = true

Button("Complete") {
    withAnimation(.easeInOut(duration: 0.25), completionCriteria: .logicallyComplete) {
        isCompleted = true      // triggers strikethrough + fade
    } completion: {
        // After animation: show undo banner, then after 3s move to completed section
        showUndoBanner = true
        Task {
            try? await Task.sleep(for: .seconds(3))
            if !undoTriggered {
                withAnimation { moveToCompleted() }
            }
        }
    }
}
```

Confidence: HIGH — `withAnimation(_:completionCriteria:_:completion:)` is iOS 17+ official API, confirmed present in the project's iOS 17 baseline.

### Pattern 3: Task Row Visual Design (Things 3 Style)

```swift
struct TaskRowView: View {
    let task: LoomTask
    var onComplete: () -> Void = {}
    var onTap: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            // Priority left edge bar
            Rectangle()
                .fill(task.priorityColor)
                .frame(width: 3)

            // Completion circle + content
            HStack(spacing: 10) {
                Button(action: onComplete) {
                    Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(task.completed ? .secondary : task.priorityColor)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .strikethrough(task.completed)
                        .foregroundStyle(task.completed ? .secondary : .primary)
                    if let dueDate = task.dueDateFormatted {
                        Text(dueDate)
                            .font(.caption2)
                            .foregroundStyle(task.isOverdue ? .red : .secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Spacer()
        }
        .background(.background)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
```

### Pattern 4: Time-Blocking Drag Gesture

This is the most novel pattern in Phase 3. The existing project uses `LongPressGesture.sequenced(before: DragGesture)` in `TimelineEventCard.swift` for drag-to-move. The same pattern applies for drag-from-task-to-timeline, with the key difference that the source and destination are different parent views.

**Why NOT `Transferable`/`dropDestination`:**
- `dropDestination` does not work when the drop target is a subview of a `List` or inside a `ScrollView` on iOS (confirmed by Apple Developer Forums thread #730367, #732076)
- The timeline drop target IS a `ScrollView`-based `ZStack` — `dropDestination` on iOS provides drop coordinates in global coordinate space inconsistently
- The existing codebase avoids `Transferable` entirely — consistency is valuable

**Recommended approach: Global coordinate DragGesture + GeometryReader anchor**

```swift
// In TodayView — the unified view containing both task list and timeline

// 1. Task row in unscheduled section has a DragGesture (no long press needed for this UX)
struct DraggableTaskRow: View {
    let task: LoomTask
    @Binding var dragState: TaskDragState?  // passed from parent

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    var body: some View {
        TaskRowView(task: task)
            .offset(dragOffset)
            .opacity(isDragging ? 0.7 : 1.0)
            .scaleEffect(isDragging ? 1.05 : 1.0)
            .animation(.interactiveSpring(), value: isDragging)
            .gesture(
                LongPressGesture(minimumDuration: 0.2)
                    .sequenced(before: DragGesture(coordinateSpace: .global))
                    .onChanged { value in
                        switch value {
                        case .first: isDragging = true
                        case .second(true, let drag?):
                            isDragging = true
                            dragOffset = drag.translation
                            dragState = TaskDragState(task: task, location: drag.location)
                        default: break
                        }
                    }
                    .onEnded { value in
                        if case .second(true, let drag?) = value {
                            dragState = TaskDragState(task: task, location: drag.location, ended: true)
                        }
                        withAnimation(.easeOut(duration: 0.15)) {
                            dragOffset = .zero
                            isDragging = false
                        }
                    }
            )
    }
}

struct TaskDragState {
    let task: LoomTask
    let location: CGPoint      // global coordinate
    var ended: Bool = false
}
```

```swift
// 2. Timeline ZStack tracks its frame in global coordinates via GeometryReader preference key
// Then in TodayView: when dragState.ended, convert global location to time slot

func timeSlot(for globalPoint: CGPoint, timelineFrame: CGRect, scrollOffset: CGFloat) -> Date? {
    let localY = globalPoint.y - timelineFrame.minY + scrollOffset
    guard localY >= 0 && localY <= timelineFrame.height else { return nil }
    let fraction = localY / (timelineFrame.height)  // 0 = midnight, 1 = midnight
    let minutesFromMidnight = fraction * 24 * 60
    // Round to nearest 15 minutes
    let rounded = round(minutesFromMidnight / 15) * 15
    let start = Calendar.current.startOfDay(for: Date())
    return start.addingTimeInterval(rounded * 60)
}
```

**Tracking scroll offset:** `ScrollView` with `.scrollPosition($scrollPosition)` (already used in `DayTimelineView.swift`) stores the current Y offset. Pass this to the drop handler for accurate coordinate mapping.

Confidence: MEDIUM-HIGH — Pattern derived from existing `TimelineEventCard.swift` code and Apple DragGesture docs. The coordinate math is straightforward; the scroll offset tracking is the subtle part.

### Pattern 5: Time-Blocked Event Visual Distinction

Per Claude's Discretion. Recommendation: time-blocked events use a dashed left border and a task icon instead of the solid blue left bar used for regular events. Background opacity is lower (0.08 vs 0.15). The task title appears below the block title in smaller text.

```swift
// In timeline event card: if event.taskId != nil, render as time-block style
HStack(spacing: 0) {
    // Dashed left bar for time-blocked tasks
    if event.taskId != nil {
        Rectangle()
            .fill(Color.orange.opacity(0.8))
            .frame(width: 3)
    } else {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.blue)
            .frame(width: 4)
    }
    // ...content
}
.background(
    RoundedRectangle(cornerRadius: 8)
        .fill(event.taskId != nil ? Color.orange.opacity(0.08) : Color.blue.opacity(0.15))
)
```

### Pattern 6: Week View Task Dot Indicators

In `WeekTimelineView.swift`, the `weekHeader` function builds the day number cells. Add task dots below the day number:

```swift
// In weekHeader — after the day number circle:
let tasksForDay = taskViewModel.tasks(dueOn: date)
if !tasksForDay.isEmpty {
    HStack(spacing: 2) {
        ForEach(tasksForDay.prefix(3)) { task in
            Circle()
                .fill(task.priorityColor)
                .frame(width: 5, height: 5)
        }
    }
}
```

WeekTimelineView needs `@ObservedObject var taskViewModel: TaskViewModel` added to its interface.

### Pattern 7: Today View Structure

Today view is the most complex new view. Structure:

```
TodayView
├── NavigationStack (title: today's date)
├── VStack(spacing: 0)
│   ├── [Optional: unscheduled tasks section]
│   │   Header: "Today" label + task count
│   │   ForEach unscheduled tasks → DraggableTaskRow
│   └── ScrollView(.vertical)
│       └── GeometryReader (ROOT — same pattern as DayTimelineView)
│           └── ZStack(alignment: .topLeading)
│               ├── Color.clear spacer (totalHeight)
│               ├── Hour grid lines + labels
│               ├── NowIndicator
│               ├── Event cards (same as DayTimelineView)
│               └── Task time markers (compact rows at due time)
```

The unscheduled tasks section above the ScrollView is a fixed-height collapsible panel (not inside the ScrollView). This avoids the GeometryReader-inside-ScrollView anti-pattern.

**Drag target registration:** The ScrollView's `ZStack` needs to register its global frame for hit testing during drag. Use a `PreferenceKey` + `background(GeometryReader)` to capture the timeline frame:

```swift
struct TimelineFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// On the ScrollView ZStack:
.background(
    GeometryReader { geo in
        Color.clear
            .preference(key: TimelineFrameKey.self,
                        value: geo.frame(in: .global))
    }
)
.onPreferenceChange(TimelineFrameKey.self) { frame in
    timelineGlobalFrame = frame
}
```

### Pattern 8: ContentView Restructure

Current `ContentView.swift` has `ViewMode: .day | .week`. Today view replaces `.day` as the default landing screen. Two options:

**Option A (recommended):** Replace `.day` with `.today` in the enum, rename "Day" to "Today", and the today view incorporates the full day timeline plus task panel. The pure "Day" view without tasks is no longer needed (CONTEXT.md: "day view becomes redundant").

```swift
enum ViewMode: String, CaseIterable {
    case today = "Today"   // was .day — now unified event+task view
    case week = "Week"
}
```

**Option B:** Add a tab bar with Today / Calendar / Tasks tabs (aligns with Phase 8 platform polish roadmap). This is premature for Phase 3 — Phase 8 handles the tab bar. Stick with Option A for now.

ContentView also needs access to `TaskViewModel`. Either:
- Add `@StateObject private var taskViewModel = TaskViewModel()` alongside `calendarViewModel`
- Or make TaskViewModel an environment object like EventKitService

**Recommendation:** `@StateObject` in ContentView and pass as `@ObservedObject` to child views (mirrors `calendarViewModel` pattern).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Drag + drop between different scroll areas | Custom NSItemProvider / Transferable pipeline | DragGesture with global coordinates — already proven in this codebase |
| Task completion animation sequencing | Custom animation coordinator | `withAnimation(_:completionCriteria:_:completion:)` — iOS 17+ built-in |
| Scroll offset tracking | UIScrollView delegate wrapper | SwiftUI `ScrollPosition` + `.scrollPosition($scrollPosition)` — already used in DayTimelineView |
| Priority color mapping | Hardcoded switch in each view | Extension on `LoomTask` with computed `priorityColor: Color` |
| Timeline coordinate math | Third-party calendar drop library | Same `yOffset(for:)` helper already in DayTimelineView — extend it |

---

## Common Pitfalls

### Pitfall 1: DragGesture Conflicts with ScrollView Scroll
**What goes wrong:** A `DragGesture` on a task row inside a `ScrollView` consumes the vertical pan gesture, preventing the timeline from scrolling.
**Why it happens:** SwiftUI gesture recognizers compete on vertical drags with the ScrollView's built-in pan recognizer.
**How to avoid:** The unscheduled task section sits ABOVE the ScrollView (not inside it). Only task rows in the fixed-height panel above the timeline have the DragGesture — the timeline itself scrolls normally. If task rows are ever added inside the ScrollView, use `.simultaneousGesture` or a minimum drag distance to defer to scroll.
**Warning signs:** Timeline stops scrolling when task rows are visible.

### Pitfall 2: GeometryReader Inside ScrollView
**What goes wrong:** Using `GeometryReader` inside a `ScrollView` reports incorrect sizes and prevents scrolling.
**Why it happens:** Established pattern — documented in MEMORY.md and STATE.md ("GeometryReader must be ROOT view (outside ScrollView)").
**How to avoid:** GeometryReader is always the outermost view in TodayView, wrapping the entire VStack including the ScrollView. Color.clear spacer is the first child of the timeline ZStack inside the ScrollView.
**Warning signs:** Timeline shows 0 height or doesn't scroll.

### Pitfall 3: Schema Migration Breaking Existing Tasks
**What goes wrong:** Existing tasks in Convex with `flagged: Bool` field cause Decodable errors when the schema changes to `priority: String`.
**Why it happens:** Convex does not automatically migrate existing documents when schema changes.
**How to avoid:** The tasks table is currently empty in development (no production data yet). Wipe the development table via `npx convex dev` or the Convex dashboard before deploying the new schema. Alternatively, make `priority` optional (`v.optional(...)`) during migration then backfill.
**Warning signs:** Swift decode errors on `tasks:list` subscription after schema update.

### Pitfall 4: Mutation Args for New Priority Field
**What goes wrong:** Passing `priority` as a raw Swift enum instead of a String to the Convex mutation.
**Why it happens:** The mutation expects a string value matching the `v.literal()` options.
**How to avoid:** Use String literals (`"high"`, `"medium"`, `"low"`) in mutation args — not an enum's `.rawValue` until you verify encoding behavior.
```swift
// Correct
let args: [String: ConvexEncodable?] = [
    "title": title,
    "priority": "high",   // string literal
    "completed": false
]
// Wrong — may not encode correctly
let args: [String: ConvexEncodable?] = [
    "priority": TaskPriority.high  // custom enum — won't conform to ConvexEncodable
]
```

### Pitfall 5: Drag Location Off-By-One from Scroll Offset
**What goes wrong:** Dragged task appears to drop at the wrong time slot — off by the current scroll position.
**Why it happens:** `DragGesture.location` is in global coordinates. The timeline ZStack frame (captured via GeometryReader/PreferenceKey) is also global. But the timeline's internal Y is `global_y - timeline_top + scrollOffset`. If scrollOffset is not correctly tracked, the resulting time is wrong.
**How to avoid:** Store the `ScrollPosition.y` value from `DayTimelineView`'s `.scrollPosition($scrollPosition)` and pass it to the coordinate converter. Test by dragging to specific hour markers (e.g., drag to 2 PM grid line and verify the created event starts at 2:00 PM).
**Warning signs:** Created time-block event appears 2-3 hours off from where the user dropped.

### Pitfall 6: @OptionalConvexInt Required for new hasDueTime-dependent dueDate
**What goes wrong:** If `dueDate` is still `v.optional(v.int64())`, the Swift property wrapper must remain `@OptionalConvexInt var dueDate: Int?` — using plain `Int?` silently fails.
**Why it happens:** Established pattern from Phase 1 — `@ConvexInt` / `@OptionalConvexInt` required for all int64 fields (see MEMORY.md).
**How to avoid:** Keep `@OptionalConvexInt var dueDate: Int?` in the updated LoomTask struct. The new `hasDueTime: Bool` is a plain Bool — no wrapper needed.

---

## Code Examples

### Convex tasks.ts — Updated create mutation

```typescript
// Source: convex/tasks.ts — update to add priority, hasDueTime, remove flagged
export const create = mutation({
  args: {
    title: v.string(),
    dueDate: v.optional(v.int64()),
    hasDueTime: v.boolean(),
    priority: v.union(v.literal("high"), v.literal("medium"), v.literal("low")),
    completed: v.boolean(),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    return await ctx.db.insert("tasks", args);
  },
});
```

### Swift TaskViewModel — createTask mutation

```swift
// Source: CalendarViewModel.swift createEvent — identical pattern
func createTask(
    title: String,
    priority: String,
    dueDate: Date? = nil,
    hasDueTime: Bool = false
) async throws {
    var args: [String: ConvexEncodable?] = [
        "title": title,
        "priority": priority,       // "high" | "medium" | "low"
        "hasDueTime": hasDueTime,
        "completed": false
    ]
    if let dueDate {
        args["dueDate"] = Int(dueDate.timeIntervalSince1970 * 1000)
    }
    try await convex.mutation("tasks:create", with: args)
}
```

### Swift LoomTask — updated model with Identifiable

```swift
// LoomTask.swift — updated for Phase 3
import ConvexMobile

struct LoomTask: Decodable, Identifiable {
    let _id: String
    var id: String { _id }              // Identifiable — matches LoomEvent pattern
    let title: String
    @OptionalConvexInt var dueDate: Int? // UTC ms — @OptionalConvexInt required
    let hasDueTime: Bool                 // true when dueDate includes time component
    let priority: String                 // "high" | "medium" | "low"
    let completed: Bool
    let notes: String?
    let attachments: [String]?
}

extension LoomTask {
    var priorityColor: Color {
        switch priority {
        case "high":   return .red
        case "medium": return .yellow
        default:       return Color.blue.opacity(0.6)
        }
    }

    var isOverdue: Bool {
        guard let ms = dueDate else { return false }
        return Date(timeIntervalSince1970: TimeInterval(ms) / 1000) < Date()
    }

    var dueDateFormatted: String? {
        guard let ms = dueDate else { return nil }
        let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = hasDueTime ? "MMM d, h:mm a" : "MMM d"
        return formatter.string(from: date)
    }
}
```

### LoomEvent.swift — add taskId

```swift
// Add to LoomEvent (after existing fields):
let taskId: String?    // non-nil when event is a time-block for a task
```

### Convex events:create — add taskId support

```typescript
// In convex/events.ts — update create mutation args:
export const create = mutation({
  args: {
    // ...existing args...
    taskId: v.optional(v.id("tasks")),  // new: for time-blocking
  },
  handler: async (ctx, args) => {
    return await ctx.db.insert("events", args);
  },
});
```

### Time-blocking: create event from task drop

```swift
// In TaskViewModel or TodayView action handler:
func createTimeBlock(for task: LoomTask, at date: Date) async throws {
    let startMs = Int(date.timeIntervalSince1970 * 1000)
    let args: [String: ConvexEncodable?] = [
        "calendarId": "personal",
        "title": task.title,
        "start": startMs,
        "duration": 60,             // default 1 hour
        "timezone": TimeZone.current.identifier,
        "isAllDay": false,
        "taskId": task._id          // link back to source task
    ]
    try await convex.mutation("events:create", with: args)
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `DragGesture` for drag-to-move only | `LongPressGesture.sequenced(before: DragGesture)` for intentional drags | Phase 2 (existing code) | Use same pattern for task-to-timeline drag |
| `confirmationDialog` for delete | `.alert` for delete (more reliable in nested sheets) | Phase 2 (STATE.md decision) | Task deletion uses `.alert` |
| `flagged: Bool` for task urgency | `priority: String` enum literal ("high"/"medium"/"low") | Phase 3 (schema migration) | UI gets 3-level priority with color coding |
| Day view as default | Today view as default landing screen | Phase 3 | Unified event+task timeline becomes home |

---

## Open Questions

1. **dueDate field: date-only vs full datetime**
   - What we know: CONTEXT.md distinguishes "tasks with due time" from "tasks with due date but no time"
   - What's unclear: Whether to use a single `dueDate` int64 field + `hasDueTime: Bool`, or two separate fields `dueDate` and `dueTime`
   - Recommendation: Single `dueDate` (stores full UTC ms timestamp when time is set; stores midnight UTC when date-only) + `hasDueTime: Bool`. Mirrors `isAllDay` pattern from `LoomEvent`. Simpler to query and sort.

2. **Undo after task completion**
   - What we know: "Task stays visible briefly with undo option" (CONTEXT.md)
   - What's unclear: Implementation — SwiftUI `.toast`-style overlay vs system `.undoManager` vs manual banner view
   - Recommendation: Simple `@State var undoTask: LoomTask?` + a floating `HStack` banner at bottom of screen with a 3-second timeout. No third-party toast library needed.

3. **Multiple time blocks per task: query direction**
   - What we know: "Multiple time blocks per task allowed — all blocks link back to the same task" (CONTEXT.md)
   - What's unclear: Whether to query events by taskId to find all time blocks for a task's detail view
   - Recommendation: Add `by_task_id` index to events table in schema: `.index("by_task_id", ["taskId"])`. Low cost now, required later.

4. **Today view: task section height**
   - What we know: Unscheduled tasks appear above the timeline in a collapsible section
   - What's unclear: What happens when there are 20 unscheduled tasks — does the section become a fixed-height scroll? Fixed height of ~150pt (3 rows) with "Show all" expansion seems right
   - Recommendation: Cap at 3 visible rows, show expand toggle. Implement in Phase 3; revisit if user feedback indicates different preference.

---

## Sources

### Primary (HIGH confidence)
- Existing codebase — `LoomCal/` directory (fully inspected Feb 2026)
  - `LoomTask.swift` — current model structure
  - `LoomEvent.swift` — Identifiable pattern + `isAllDay` Bool precedent
  - `CalendarViewModel.swift` — subscription + mutation patterns to mirror
  - `TimelineEventCard.swift` — `LongPressGesture.sequenced(before: DragGesture)` pattern
  - `DayTimelineView.swift` — GeometryReader ROOT pattern, Color.clear spacer, ScrollPosition
  - `WeekTimelineView.swift` — day header structure for task dot addition
  - `ContentView.swift` — ViewMode enum, current navigation structure
  - `convex/schema.ts` — current tasks table definition
  - `convex/tasks.ts` — existing CRUD mutations
- `.planning/STATE.md` — accumulated decisions including @ConvexInt requirement, .alert over .confirmationDialog
- `.planning/research/PITFALLS.md` — Convex number type mismatch patterns, subscription leak prevention
- Apple Developer Documentation — `withAnimation(_:completionCriteria:_:completion:)` (iOS 17+)

### Secondary (MEDIUM confidence)
- Apple Developer Forums thread #730367 — `dropDestination` does not work inside `List` subviews
- Apple Developer Forums thread #732076 — `dropDestination` location in global vs local coordinates on iOS
- WebSearch: SwiftUI drag drop ScrollView 2024 — confirms DragGesture + coordinate tracking as preferred pattern for within-app drag between non-sibling views

### Tertiary (LOW confidence)
- Context7 ConvexMobile docs — primarily Android/Kotlin; Swift patterns verified directly from codebase instead

---

## Metadata

**Confidence breakdown:**
- Schema migration (priority, hasDueTime, taskId): HIGH — inspected existing schema; changes are additive
- TaskViewModel pattern: HIGH — direct mirror of CalendarViewModel which works in production
- Task row + completion animation: HIGH — standard SwiftUI patterns, iOS 17+ API confirmed
- Time-blocking drag implementation: MEDIUM-HIGH — gesture pattern exists in codebase; coordinate math is new
- Today view architecture: MEDIUM-HIGH — structural pattern is clear; scroll offset tracking for drag needs testing
- Week view dot indicators: HIGH — simple addition to existing weekHeader function

**Research date:** 2026-02-20
**Valid until:** 2026-03-20 (stable SwiftUI/Convex APIs; drag gesture coordinate behavior stable since iOS 17)
