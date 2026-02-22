---
phase: 05-loom-calendar-and-task-actions
plan: 02
subsystem: ui
tags: [swift, swiftui, convex, loom, action, undo, highlight, viewmodel]

# Dependency graph
requires:
  - phase: 05-01
    provides: Convex backend schema and endpoints for pending_action messages and updateActionStatus mutation

provides:
  - ChatMessage model extended with action (JSON string) and actionStatus optional fields
  - LoomAction Codable struct with flexible ActionValue enum for string/int/bool payloads
  - ChatViewModel.confirmAction: marks confirmed in Convex, routes to CalendarVM/TaskVM CRUD, starts undo timer
  - ChatViewModel.cancelAction: marks cancelled in Convex without executing mutation
  - ChatViewModel.undoAction: reverses create (delete) or update (patch previousValues) within 5-second window
  - CalendarViewModel.highlightedEventId published + flashHighlight(eventId:) + navigateToDate(_:)
  - TaskViewModel.highlightedTaskId published + flashHighlight(taskId:)
  - ContentView wires chatViewModel.calendarViewModel and .taskViewModel references

affects: [05-03-action-confirmation-ui, plan views using highlightedEventId/highlightedTaskId]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Subscription snapshot diff: capture Set of IDs before mutation, wait up to 3s for new ID to appear via subscription
    - Undo timer: Task counting down from 5→0 with 1-second sleep intervals, cancelled on undoAction()
    - Action routing: switch on action.type string to fan out to typed ViewModel CRUD method calls
    - Highlight feedback: @Published ID + Task.sleep(2s) + withAnimation nil clear pattern

key-files:
  created:
    - LoomCal/Models/LoomAction.swift
  modified:
    - LoomCal/Models/ChatMessage.swift
    - LoomCal/ViewModels/ChatViewModel.swift
    - LoomCal/ViewModels/CalendarViewModel.swift
    - LoomCal/ViewModels/TaskViewModel.swift
    - LoomCal/Views/ContentView.swift
    - LoomCal.xcodeproj/project.pbxproj

key-decisions:
  - "ActionValue enum decodes Bool before Int — JSON booleans would otherwise decode as Int 0/1"
  - "Undo not started for delete actions — data is gone, too complex for Phase 5; timer only for create/update"
  - "New item ID captured via subscription snapshot diff (wait up to 3s polling) — ConvexMobile mutation returns Void"
  - "calendarViewModel/taskViewModel stored as optional vars on ChatViewModel, wired in ContentView .task{}"

patterns-established:
  - "Subscription snapshot diff: Set of existing IDs before mutation → poll subscription for new entry"
  - "Highlight feedback: @Published String? ID + 2-second Task.sleep + withAnimation nil clear"

requirements-completed: [LOOM-05, LOOM-06, LOOM-07]

# Metrics
duration: 4min
completed: 2026-02-22
---

# Phase 5 Plan 02: Loom Calendar and Task Actions — iOS Confirmation Flow Summary

**ChatViewModel action lifecycle (confirm/cancel/undo) with LoomAction model, CalendarViewModel/TaskViewModel highlight support, and ContentView ViewModel wiring**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-22T06:16:15Z
- **Completed:** 2026-02-22T06:20:15Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Created LoomAction Codable struct with flexible ActionValue enum that handles string/int/bool JSON payload values, plus isEventAction/isTaskAction/isCreate/isUpdate/isDelete convenience properties
- Extended ChatMessage with action and actionStatus optional fields, isPendingAction computed property, and decodedAction computed property that decodes the JSON string into a typed LoomAction
- Added ChatViewModel.confirmAction: marks action confirmed in Convex, executes CalendarVM/TaskVM CRUD mutation, captures new item ID via subscription snapshot diff, triggers flashHighlight, starts 5-second undo timer
- Added ChatViewModel.cancelAction, undoAction, reverseAction — undo reverses create (delete) or update (patch previousValues); delete undo skipped intentionally
- Added CalendarViewModel.highlightedEventId published property, flashHighlight(eventId:) auto-clearing method, and navigateToDate(_:) helper
- Added TaskViewModel.highlightedTaskId published property and flashHighlight(taskId:) method
- Wired ViewModel references in ContentView .task{} so ChatViewModel can call CalendarVM/TaskVM CRUD on action confirm

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend ChatMessage model and create LoomAction struct** - `0f4b9d5` (feat)
2. **Task 2: Add confirm/cancel/undo logic and highlight feedback** - `410fff6` (feat)

**Plan metadata:** (docs commit to follow)

## Files Created/Modified

- `LoomCal/Models/LoomAction.swift` - New Codable struct for Loom action payloads with ActionValue enum
- `LoomCal/Models/ChatMessage.swift` - Added action, actionStatus optional fields, isPendingAction, decodedAction
- `LoomCal/ViewModels/ChatViewModel.swift` - confirmAction, cancelAction, undoAction, startUndoTimer, executeAction, reverseAction, ViewModel references
- `LoomCal/ViewModels/CalendarViewModel.swift` - highlightedEventId, flashHighlight, navigateToDate
- `LoomCal/ViewModels/TaskViewModel.swift` - highlightedTaskId, flashHighlight
- `LoomCal/Views/ContentView.swift` - Wires chatViewModel.calendarViewModel and .taskViewModel in .task
- `LoomCal.xcodeproj/project.pbxproj` - Registered LoomAction.swift in Models group and Sources build phase

## Decisions Made

- ActionValue enum decodes Bool before Int to prevent JSON booleans from being decoded as Int 0/1 (Swift's JSONDecoder is greedy)
- Undo timer not started for delete actions — data is irrecoverably gone in Phase 5; undo is scoped to create/update
- New item ID captured via subscription snapshot diff: snapshot Set of existing IDs before mutation, then poll subscription up to 3 seconds (6x 500ms sleeps) for a new entry — ConvexMobile mutation returns Void so direct return value unavailable
- calendarViewModel/taskViewModel stored as optional var properties on ChatViewModel, set in ContentView .task{} which already owns all three @StateObjects

## Deviations from Plan

None — plan executed exactly as written. The optional var approach for ViewModel references (vs weak var) was specified in the plan and followed directly.

## Issues Encountered

None — build succeeded clean on first attempt for both tasks.

## Next Phase Readiness

- All ViewModel logic is in place for the action lifecycle
- Plan 03 (ActionConfirmationCard UI) can now build on ChatViewModel.confirmAction/cancelAction and highlightedEventId/highlightedTaskId
- No blockers — ContentView wiring is complete, build is green

---
*Phase: 05-loom-calendar-and-task-actions*
*Completed: 2026-02-22*
