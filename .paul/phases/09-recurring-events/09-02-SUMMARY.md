---
phase: 09-recurring-events
plan: 02
subsystem: ui, calendar
tags: [recurrence, swiftui, picker, edit-this-all, delete-this-all, rrule]

requires:
  - phase: 09-recurring-events
    provides: RecurrenceRule model, CalendarViewModel expansion, virtual occurrences, exceptionDates
provides:
  - Recurrence picker in event creation (Never/Daily/Weekdays/Weekly/Monthly)
  - Recurrence badge in event detail view
  - Delete this occurrence / delete all series
  - Edit this occurrence / edit all series
  - CalendarViewModel recurrence mutation helpers
affects: [09-03 verification, 10-loom-voice (Loom can now reference recurring events)]

tech-stack:
  added: []
  patterns: [RecurrencePreset enum for picker options, RecurrenceEditMode for branching edit/delete, alert-based this/all choice]

key-files:
  created: []
  modified: [LoomCal/Views/Events/EventCreationView.swift, LoomCal/Views/Events/EventDetailView.swift, LoomCal/Views/Events/EventEditView.swift, LoomCal/ViewModels/CalendarViewModel.swift, LoomCal/Models/RecurrenceRule.swift]

key-decisions:
  - "RecurrencePreset enum maps picker options to RecurrenceRule factories — clean separation"
  - "RecurrenceEditMode defined in EventDetailView.swift (not a separate file) — minimal footprint"
  - "Edit single occurrence creates standalone event + exception on master — detach pattern"
  - "Used .alert for this/all choices (not .confirmationDialog) per CLAUDE.md nested sheet rule"

patterns-established:
  - "RecurrencePreset.toRule(for:) converts picker selection to RecurrenceRule for a given date"
  - "RecurrenceEditMode passed from detail → edit view to control save behavior"
  - "addExceptionDate reads master's current exceptions, appends, re-encodes JSON"
  - "editSingleOccurrence = create standalone + addExceptionDate (two-step atomic)"

duration: ~10min
started: 2026-02-24T13:30:00Z
completed: 2026-02-24T13:40:00Z
---

# Phase 9 Plan 02: Recurrence UI Summary

**Recurrence picker in event creation, recurrence badge in detail view, and edit-this/edit-all + delete-this/delete-all handling for recurring event occurrences.**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~10 min |
| Started | 2026-02-24 |
| Completed | 2026-02-24 |
| Tasks | 4 completed (3 auto + 1 checkpoint) |
| Files modified | 5 |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-1: Recurrence Picker in Creation | Pass | Picker with Never/Daily/Weekdays/Weekly/Monthly; rrule saved to Convex |
| AC-2: Recurrence Badge in Detail | Pass | displayDescription shows human-readable recurrence info |
| AC-3: Delete This Occurrence | Pass | addExceptionDate adds to master's JSON array; occurrence vanishes |
| AC-4: Delete All Events | Pass | deleteRecurringSeries resolves master ID and deletes |
| AC-5: Edit This / Edit All Choice | Pass | Alert branches; single creates standalone + exception; all updates master |

## Accomplishments

- RecurrencePreset enum with 5 options mapping to RecurrenceRule factories, integrated into EventCreationView details section
- RecurrenceRule.displayDescription for human-readable recurrence descriptions ("Repeats weekly on Mon, Wed, Fri")
- Full delete branching: "This Event" (exception date) vs "All Events" (delete master) with proper alert UI
- Full edit branching: "This Event" (standalone creation + exception) vs "All Events" (master update) via RecurrenceEditMode
- CalendarViewModel gained 3 new mutation helpers: addExceptionDate, deleteRecurringSeries, editSingleOccurrence

## Files Created/Modified

| File | Change | Purpose |
|------|--------|---------|
| `LoomCal/Views/Events/EventCreationView.swift` | Modified | RecurrencePreset enum, @State picker, rrule in saveEvent(), recurrence label in summary card |
| `LoomCal/Views/Events/EventDetailView.swift` | Modified | RecurrenceEditMode enum, recurrence badge, delete this/all alert, edit this/all alert |
| `LoomCal/Views/Events/EventEditView.swift` | Modified | editMode parameter, branching saveChanges() for single vs all |
| `LoomCal/ViewModels/CalendarViewModel.swift` | Modified | createEvent rrule param, addExceptionDate, deleteRecurringSeries, editSingleOccurrence |
| `LoomCal/Models/RecurrenceRule.swift` | Modified | displayDescription computed property, ordinal() helper |

## Decisions Made

| Decision | Rationale | Impact |
|----------|-----------|--------|
| RecurrencePreset enum in EventCreationView | Keeps picker options simple and self-contained; maps to RecurrenceRule at save time | Weekly defaults to event's weekday, monthly to event's day-of-month |
| .alert for this/all choices | .confirmationDialog breaks in nested sheets (per CLAUDE.md) | Three-button alert: "This Event" / "All Events" / "Cancel" |
| Edit single = create standalone + exception | Simpler than modifying occurrence in-place; standalone event is fully independent | recurrenceGroupId links standalone back to series for future reference |

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## Next Phase Readiness

**Ready:**
- Full recurring event lifecycle works: create → view → edit → delete
- Plan 09-03 (verification/Loom integration) can proceed
- RecurrencePreset pattern extensible for future "Custom" option with day-picker

**Concerns:**
- "Edit This Event" creates a standalone event — user can't tell it was detached from series (no UI indicator yet)
- No UNTIL/end-date picker — recurring events repeat forever until manually deleted

**Blockers:**
- None

---
*Phase: 09-recurring-events, Plan: 02*
*Completed: 2026-02-24*
