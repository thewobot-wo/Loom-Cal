---
phase: 03-task-system
plan: 01
subsystem: database
tags: [convex, swift, swiftui, tasks, convexmobile]

# Dependency graph
requires:
  - phase: 02-calendar-views
    provides: LoomEvent model, CalendarViewModel pattern, ConvexMobile mutation patterns

provides:
  - Convex tasks schema with priority union (high/medium/low) replacing flagged boolean
  - hasDueTime boolean on tasks table for distinguishing timed vs date-only due dates
  - taskId optional foreign key on events table for time-block linkage
  - LoomTask Swift model with Identifiable, priorityColor, isOverdue, dueDateFormatted
  - LoomEvent updated with taskId field
  - TaskViewModel with tasks:list subscription, CRUD mutations, date-filtering helpers

affects: [03-02-task-list-view, 03-03-task-creation, 03-04-task-detail, all-phase-3-plans]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - TaskViewModel mirrors CalendarViewModel pattern (startSubscription/stopSubscription, @MainActor ObservableObject)
    - Convex priority union literals: v.union(v.literal("high"), v.literal("medium"), v.literal("low"))
    - @OptionalConvexInt for v.optional(v.int64()) fields on Swift models

key-files:
  created:
    - LoomCal/ViewModels/TaskViewModel.swift
  modified:
    - convex/schema.ts
    - convex/tasks.ts
    - convex/events.ts
    - LoomCal/Models/LoomTask.swift
    - LoomCal/Models/LoomEvent.swift
    - LoomCal.xcodeproj/project.pbxproj

key-decisions:
  - "priority union (high/medium/low) replaces flagged:boolean on tasks table — enables sorting and filtering by tier"
  - "hasDueTime:boolean separates date-only tasks from time-specific tasks in the same dueDate field"
  - "taskId on events table links time-blocked calendar events back to their source task"
  - "attachments removed from tasks:create mutation args (simplified — can be added later)"
  - "LoomTask.Identifiable via computed var id: String { _id } — matches LoomEvent pattern, avoids CodingKeys issues"

patterns-established:
  - "TaskViewModel: @MainActor ObservableObject, startSubscription/stopSubscription, subscriptionTask: Task<Void, Never>?"
  - "Date filtering helpers on ViewModel (tasks(dueOn:), tasksWithTime(dueOn:), unscheduledTasks(dueOn:), overdueTasks())"
  - "createTimeBlock on TaskViewModel — cross-domain mutation (tasks -> events) lives on task ViewModel"

requirements-completed: [TASK-01, TASK-02, TASK-05, TASK-06]

# Metrics
duration: 3min
completed: 2026-02-21
---

# Phase 3 Plan 01: Task System Foundation Summary

**Convex tasks schema migrated from flagged:Bool to priority union (high/medium/low) with hasDueTime and taskId fields; Swift models updated; TaskViewModel created with subscription, CRUD, and date-filtering**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-21T02:50:18Z
- **Completed:** 2026-02-21T02:53:52Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Convex schema migrated: priority union replaces flagged boolean, hasDueTime and by_priority index added to tasks table, taskId and by_task_id index added to events table
- Swift models updated: LoomTask gets Identifiable, priority:String, hasDueTime:Bool, computed properties (priorityColor, isOverdue, dueDateFormatted); LoomEvent gets taskId:String?
- TaskViewModel created mirroring CalendarViewModel pattern with tasks:list subscription, full CRUD mutations, date-filtering helpers, and createTimeBlock for cross-domain time-blocking
- iOS build succeeds with no errors

## Task Commits

Each task was committed atomically:

1. **Task 1: Migrate Convex schema and update mutation functions** - `59a8cce` (feat)
2. **Task 2: Update Swift models and create TaskViewModel** - `485e108` (feat)

**Plan metadata:** TBD (docs: complete plan)

## Files Created/Modified
- `convex/schema.ts` - Added priority union, hasDueTime, taskId on events with indexes
- `convex/tasks.ts` - Updated create/update with priority/hasDueTime, removed flagged/attachments from create
- `convex/events.ts` - Added optional taskId arg to create/update mutations
- `LoomCal/Models/LoomTask.swift` - Full rewrite with Identifiable, priority, hasDueTime, computed properties
- `LoomCal/Models/LoomEvent.swift` - Added taskId:String? field
- `LoomCal/ViewModels/TaskViewModel.swift` - New file: subscription + CRUD + date filtering + createTimeBlock
- `LoomCal.xcodeproj/project.pbxproj` - Added TaskViewModel.swift to ViewModels group and Sources phase

## Decisions Made
- priority union (high/medium/low) replaces flagged:boolean — enables sorting/filtering by tier, aligns with research recommendation
- hasDueTime boolean separates "due on date" from "due at time" within the same dueDate UTC ms field
- taskId on events table creates time-block linkage without duplicating task data
- attachments removed from tasks:create (simplification — upload UI deferred per plan)
- LoomTask.Identifiable via computed `var id: String { _id }` matches established LoomEvent pattern

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required. Schema changes will deploy when user runs `npx convex dev`.

## Next Phase Readiness
- All Phase 3 UI plans (03-02 through 03-04) now have the correct schema, models, and ViewModel foundation
- TaskViewModel ready for @StateObject injection in ContentView
- tasks:list query ready for subscription

---
*Phase: 03-task-system*
*Completed: 2026-02-21*

## Self-Check: PASSED
- All 7 files found on disk
- Both task commits verified: 59a8cce, 485e108
