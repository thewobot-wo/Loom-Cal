---
phase: 09-recurring-events
plan: 01
subsystem: calendar
tags: [rrule, recurrence, convex, swiftui, calendar-expansion]

requires:
  - phase: 05-loom-actions
    provides: events CRUD mutations, LoomEvent model, CalendarViewModel
provides:
  - RecurrenceRule model (RRULE parse/generate/expand for daily/weekly/monthly)
  - Client-side recurrence expansion in CalendarViewModel
  - exceptionDates schema field for occurrence-level exceptions
  - LoomEvent virtual occurrence factory
affects: [09-02 recurrence UI, 10-loom-voice (listForLoom now includes rrule context)]

tech-stack:
  added: []
  patterns: [client-side recurrence expansion, virtual occurrence with synthetic IDs, JSON-encoded int64 arrays]

key-files:
  created: [LoomCal/Models/RecurrenceRule.swift]
  modified: [convex/schema.ts, convex/events.ts, LoomCal/Models/LoomEvent.swift, LoomCal/ViewModels/CalendarViewModel.swift]

key-decisions:
  - "exceptionDates stored as v.string() JSON array instead of v.array(v.int64()) to avoid ConvexMobile BigInt array decoding issues"
  - "Client-side expansion in CalendarViewModel.events(for:) — no server-side expansion query needed"
  - "Virtual occurrences use synthetic IDs: {masterId}_occ_{startMs}"

patterns-established:
  - "RecurrenceRule.from(rrule:) / .toRRULE() for RRULE round-tripping"
  - "LoomEvent.virtualOccurrence(of:startMs:) factory for expanded instances"
  - "expandRecurringEvent() on-demand per day — no pre-computation"

duration: ~12min
started: 2026-02-24T13:15:00Z
completed: 2026-02-24T13:27:00Z
---

# Phase 9 Plan 01: Recurrence Data Model + Expansion Engine Summary

**RecurrenceRule model with RRULE parse/generate/expand for daily/weekly/monthly, client-side occurrence expansion in CalendarViewModel, and Convex schema support for exception dates.**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~12 min |
| Started | 2026-02-24 |
| Completed | 2026-02-24 |
| Tasks | 3 completed |
| Files modified | 5 |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-1: RRULE Parsing | Pass | RecurrenceRule.from(rrule:) handles FREQ, INTERVAL, BYDAY, BYMONTHDAY, UNTIL, COUNT |
| AC-2: RRULE Generation | Pass | toRRULE() produces valid strings; round-trips correctly |
| AC-3: Occurrence Expansion | Pass | CalendarViewModel.events(for:) returns virtual occurrences with synthetic IDs |
| AC-4: Exception Dates Honored | Pass | parsedExceptionDates → exceptionDateValues → excluded in expansion |
| AC-5: Non-Recurring Events Unaffected | Pass | Non-recurring events use original filter path unchanged |

## Accomplishments

- RecurrenceRule model: full RRULE parse/generate for daily, weekly (with BYDAY), monthly (with BYMONTHDAY), plus INTERVAL, UNTIL, COUNT support
- Client-side occurrence expansion integrated into CalendarViewModel.events(for:) — views get expanded occurrences transparently
- Virtual occurrence factory on LoomEvent with synthetic IDs and master event tracking
- Convex schema and mutations updated with exceptionDates field; listForLoom now returns recurrence context

## Files Created/Modified

| File | Change | Purpose |
|------|--------|---------|
| `LoomCal/Models/RecurrenceRule.swift` | Created | Weekday enum, RecurrenceFrequency, RecurrenceRule struct with parse/generate/expand |
| `LoomCal/Models/LoomEvent.swift` | Modified | Added exceptionDates, isRecurring, isVirtualOccurrence, masterEventId, virtualOccurrence factory |
| `LoomCal/ViewModels/CalendarViewModel.swift` | Modified | Recurrence expansion in events(for:), expandRecurringEvent() helper |
| `convex/schema.ts` | Modified | Added exceptionDates field to events table |
| `convex/events.ts` | Modified | Added exceptionDates to create/update args, rrule/recurrenceGroupId/exceptionDates to listForLoom |

## Decisions Made

| Decision | Rationale | Impact |
|----------|-----------|--------|
| exceptionDates as v.string() not v.array(v.int64()) | ConvexMobile lacks @ConvexInt array wrapper; JSON string decodes cleanly as String? | Swift parses via JSONDecoder; mutations pass JSON string |
| Client-side expansion (not server query) | Avoids new Convex endpoints; expansion window is per-day so lightweight | Expansion happens on every events(for:) call — acceptable for current scale |
| 365-occurrence safety cap | Prevents unbounded expansion for rules without UNTIL/COUNT | Exotic long-running recurrences may silently cap |

## Deviations from Plan

### Summary

| Type | Count | Impact |
|------|-------|--------|
| Auto-fixed | 1 | Schema type change — no functional impact |
| Scope additions | 0 | — |
| Deferred | 0 | — |

**Total impact:** Minimal — one schema type adjustment for SDK compatibility.

### Auto-fixed Issues

**1. Schema type: exceptionDates**
- **Found during:** Task 1 / Task 3 boundary
- **Issue:** v.array(v.int64()) cannot be decoded by ConvexMobile without custom Decodable init for all fields
- **Fix:** Changed to v.optional(v.string()) storing JSON array string
- **Files:** convex/schema.ts, convex/events.ts
- **Verification:** Schema pushed successfully, LoomEvent decodes cleanly

## Issues Encountered

| Issue | Resolution |
|-------|------------|
| `var dateComps` warning in RecurrenceRule.swift | Changed to `let` — value never mutated |

## Next Phase Readiness

**Ready:**
- RecurrenceRule model ready for UI to create/edit rules
- CalendarViewModel expansion works transparently — views already show virtual occurrences
- LoomEvent.isVirtualOccurrence / masterEventId ready for edit-this/edit-all logic

**Concerns:**
- LoomEvent memberwise init used for virtual occurrences — if new fields added to schema, factory method needs updating
- Weekly expansion computes from Monday; DST transitions near week boundaries not explicitly tested

**Blockers:**
- None

---
*Phase: 09-recurring-events, Plan: 01*
*Completed: 2026-02-24*
