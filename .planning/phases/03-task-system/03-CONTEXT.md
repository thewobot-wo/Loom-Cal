# Phase 3: Task System - Context

**Gathered:** 2026-02-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Full task CRUD (create, edit, complete, delete) with due dates and priorities. Tasks appear as markers on day and week calendar views. Users can drag tasks onto calendar time slots to time-block them. A Today view replaces the current day view as the default landing screen, showing events and tasks in a unified interleaved timeline.

Tags, projects, subtasks, and multi-day upcoming views are v2 (TSKV-01, TSKV-02, TSKV-03).

</domain>

<decisions>
## Implementation Decisions

### Task list presentation
- Compact rows (Things 3 style) — title, due date chip, priority indicator on one line
- Colored left edge for priority: red = high, yellow = medium, blue/none = low
- Default view is the Today view (see below)
- Filter/sort by priority available within Phase 3 scope
- Tags and project grouping are deferred to v2

### Task completion behavior
- Fade + strikethrough animation on tap complete
- Task stays visible briefly with undo option
- Then moves to a collapsed "Completed" section at the bottom

### Today view design
- Interleaved timeline — events and tasks mixed on one timeline sorted by time
- Unscheduled tasks (no specific time) appear in a compact section at the top of the timeline, above the first timed event
- Today view replaces the current day view as the app's default landing screen (day view becomes redundant since Today includes the full timeline plus tasks)

### Calendar task markers — day view
- Tasks with a due time appear as inline compact rows directly in the timeline at their due time — visually lighter than events
- Tasks with a due date but no time appear at the top of the day, above the timeline (same pattern as unscheduled tasks in Today view)

### Calendar task markers — week view
- Small colored dot(s) under the day number indicating tasks are due that day
- Tap the day to see task details — keeps week view clean

### Overdue task handling
- Overdue tasks flagged in the task list only (red/distinct styling)
- Calendar views show tasks on their actual due date, not on today

### Time-blocking interaction
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

</decisions>

<specifics>
## Specific Ideas

- Compact rows inspired by Things 3 — dense, scannable, one task per line
- Today view as the single "home screen" — calendar + tasks unified like Morgen's agenda view
- Priority left-edge bars similar to Notion database row indicators
- Time-blocking should feel like dragging a post-it onto a calendar

</specifics>

<deferred>
## Deferred Ideas

- Tags and tag-based filtering — v2 (TSKV-02 or new requirement)
- Project grouping for tasks — v2 (TSKV-02)
- Subtasks and checklists — v2 (TSKV-01)
- Multi-day upcoming view (Things 3 style) — v2 (TSKV-03)

</deferred>

---

*Phase: 03-task-system*
*Context gathered: 2026-02-20*
