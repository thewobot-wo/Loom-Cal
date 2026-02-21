---
phase: 03-task-system
plan: "03"
subsystem: ui
tags: [swiftui, todayview, tasks, calendar, timeline, weekview]

requires:
  - phase: 03-task-system/03-02
    provides: TaskRowView, TaskCreationView, TaskDetailView — task UI components used in TodayView
  - phase: 03-task-system/03-01
    provides: LoomTask model, TaskViewModel with date filtering helpers
  - phase: 02-calendar-views/02-03
    provides: DayTimelineView layout patterns, WeekTimelineView, GeometryReader-as-root pattern

provides:
  - TodayView — unified event+task timeline as the default landing screen
  - TimelineItem enum — type-erased union of LoomEvent and LoomTask for timeline interleaving
  - Task dot indicators in WeekTimelineView day headers
  - ContentView with Today/Week modes, dual ViewModels, task creation sheet

affects: [03-04, 04-chat-loom, future-phases]

tech-stack:
  added: []
  patterns:
    - TimelineItem enum for type-erased event+task interleaving in ZStack timeline
    - Unscheduled task section above timeline with 3-row cap and Show All toggle
    - Compact 20pt task time markers (clear background, inline text) vs full event cards
    - Task dot indicators (5pt circles, priority-colored) below day numbers in week header

key-files:
  created:
    - LoomCal/Views/Today/TodayView.swift
  modified:
    - LoomCal/Views/ContentView.swift
    - LoomCal/Views/Calendar/WeekTimelineView.swift
    - LoomCal.xcodeproj/project.pbxproj

key-decisions:
  - "TodayView uses same GeometryReader-as-root + Color.clear spacer pattern as DayTimelineView — consistent layout behavior"
  - "TimelineItem enum with .event / .task cases enables interleaved sort without mixing model types"
  - "Unscheduled section deduplicates overdue (no time) + today unscheduled tasks by Set<String> ID tracking"
  - "Week view task dots fixed-height spacer (Color.clear 5pt) maintains consistent header height on no-task days"
  - "Toolbar + button replaced with Menu (New Event / New Task) — single entry point for both creation flows"

patterns-established:
  - "TimelineItem enum: type-erased union for rendering heterogeneous timeline items at Y offsets"
  - "Compact task markers: HStack(priority dot + title text + completion circle), height 20, Color.clear background"

requirements-completed: [TASK-05, TASK-07]

duration: 5min
completed: 2026-02-21
---

# Phase 3 Plan 03: TodayView and Calendar Task Integration Summary

**TodayView as default landing screen with unified event+task timeline, unscheduled task section, and colored priority dots in week header**

## Performance

- **Duration:** 5 min
- **Started:** 2026-02-21T03:03:53Z
- **Completed:** 2026-02-21T03:08:56Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Created TodayView.swift — GeometryReader-rooted unified timeline interleaving calendar events and timed tasks via TimelineItem enum
- Unscheduled tasks section above timeline: collapsible, capped at 3 rows with Show All toggle, uses existing TaskRowView
- Timed task markers in timeline: compact 20pt inline rows (priority dot + title + completion circle, clear background)
- ContentView updated: ViewMode.day → .today, TaskViewModel @StateObject, task creation + detail sheets, plus-menu with New Event / New Task
- WeekTimelineView: colored priority dots (up to 3) under day numbers for tasks due each day

## Task Commits

Each task was committed atomically:

1. **Task 1: Create TodayView and update ContentView** - `a20123e` (feat)
2. **Task 2: Add task dot indicators to WeekTimelineView** - `cc5cad9` (feat)

## Files Created/Modified

- `LoomCal/Views/Today/TodayView.swift` — New: unified event+task timeline with TimelineItem enum, unscheduled section, timed task markers
- `LoomCal/Views/ContentView.swift` — Updated: ViewMode.today, TaskViewModel, task sheets, plus-menu
- `LoomCal/Views/Calendar/WeekTimelineView.swift` — Updated: taskViewModel parameter, priority dots in day headers
- `LoomCal.xcodeproj/project.pbxproj` — Updated: Today group with TodayView.swift registered in build sources

## Decisions Made

- **TimelineItem enum** used for type-erased event+task interleaving — keeps ZStack rendering clean without mixing LoomEvent/LoomTask directly
- **GeometryReader-as-root + Color.clear spacer** pattern maintained in TodayView (consistent with DayTimelineView)
- **Compact task markers** use clear background (no card) for visual distinction from event cards — follows plan spec
- **Fixed-height spacer** on no-task days in week header ensures uniform cell height across all days
- **Plus button upgraded to Menu** — single toolbar button opens "New Event" / "New Task" sheet choice

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added taskViewModel parameter to WeekTimelineView before Task 1 build**
- **Found during:** Task 1 (ContentView compilation)
- **Issue:** ContentView passes taskViewModel to WeekTimelineView on line 67, but WeekTimelineView had no such parameter — caused `extra argument 'taskViewModel' in call` build error
- **Fix:** Added `@ObservedObject var taskViewModel: TaskViewModel` to WeekTimelineView struct and updated preview — minimal stub addition (actual dot rendering added in Task 2)
- **Files modified:** LoomCal/Views/Calendar/WeekTimelineView.swift
- **Verification:** BUILD SUCCEEDED after addition
- **Committed in:** a20123e (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Parameter addition was necessary prerequisite for Task 1 build. Task 2 then added the actual dot rendering logic as planned. No scope creep.

## Issues Encountered

- `xcodebuild -destination 'platform=iOS Simulator,name=iPhone 16'` unavailable (no plain iPhone 16 in this Xcode version) — switched to `id=DD005F21-9AC6-4EF0-9F70-438AE7118DCD` (iPhone 16 Pro). Cosmetic difference only; build result identical.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- TodayView complete and building — core unified view delivered (TASK-05, TASK-07 done)
- Plan 03-04 (task filtering/sorting) can proceed — all view infrastructure in place
- TaskViewModel already subscribed in ContentView — reactive updates will flow to TodayView and WeekTimelineView automatically

---
*Phase: 03-task-system*
*Completed: 2026-02-21*

## Self-Check: PASSED

- FOUND: LoomCal/Views/Today/TodayView.swift
- FOUND: LoomCal/Views/ContentView.swift
- FOUND: LoomCal/Views/Calendar/WeekTimelineView.swift
- FOUND commit: a20123e (Task 1)
- FOUND commit: cc5cad9 (Task 2)
