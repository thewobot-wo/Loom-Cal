---
phase: 06-ai-daily-planning
plan: 01
subsystem: ai, chat
tags: [openai, bridge, swift, codable, batch-events, undo]

# Dependency graph
requires:
  - phase: 05-loom-calendar-and-task-actions
    provides: action system (confirm/cancel/undo), bridge ACTION block parsing, ChatViewModel action lifecycle
provides:
  - Bridge daily_plan ACTION block support (system prompt + detection + normalization)
  - DailyPlanProposal Swift model with flexible String/Int Codable decoding
  - ChatViewModel batch approve/reject/undo for daily plans
affects: [06-02 (UI card + ChatView integration)]

# Tech tracking
tech-stack:
  added: []
  patterns: [batch-create-with-diff-id-detection, struct-based-undo-context]

key-files:
  created: [LoomCal/Models/DailyPlanProposal.swift]
  modified: [bridge/loom-bridge.mjs, LoomCal/Models/ChatMessage.swift, LoomCal/ViewModels/ChatViewModel.swift, LoomCal/Views/Chat/ChatView.swift]

key-decisions:
  - "UndoContext as struct replacing tuple — supports both single-action and batch-plan undo"
  - "PlannedBlock custom Codable handles both String and Int for start/duration (bridge normalizes to strings)"
  - "decodedPlan adds type=='daily_plan' guard for safety (prevents false positives from other action types)"

patterns-established:
  - "Batch event creation via before/after ID diffing on CalendarViewModel.events"
  - "Nested ACTION block normalization (blocks array inside payload)"

# Metrics
duration: ~15min
started: 2025-02-22T00:00:00Z
completed: 2025-02-22T00:15:00Z
---

# Phase 6 Plan 01: Bridge + Model + ViewModel Daily Planning Summary

**Daily planning backend and logic layers: bridge outputs `daily_plan` ACTION blocks, Swift decodes plan proposals, ChatViewModel batch-creates/undoes events.**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~15 min |
| Tasks | 3 completed |
| Files created | 1 |
| Files modified | 4 |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-1: Bridge sends daily planning instructions | Pass | System prompt includes "## Daily Planning" section with format spec and rules |
| AC-2: Bridge parses and normalizes daily_plan ACTION blocks | Pass | detectActionBlock accepts daily_plan with blocks array; normalizeActionPayload iterates blocks normalizing start/duration |
| AC-3: Swift model decodes daily plan proposals | Pass | DailyPlanProposal + PlannedBlock with custom Codable handling both String and Int values |
| AC-4: Batch approve creates all events with undo | Pass | approveDailyPlan creates events via CalendarViewModel, collects IDs by diffing, starts batch undo timer |
| AC-5: Reject dismisses plan without mutations | Pass | rejectDailyPlan delegates to cancelAction — marks cancelled, no events created |

## Accomplishments

- Bridge system prompt instructs Loom to output structured daily_plan ACTION blocks with blocks array, avoiding individual create_event tool calls
- DailyPlanProposal model with flexible Codable init handles the bridge's string-encoded numeric values alongside raw integers
- ChatViewModel supports full daily plan lifecycle: batch approve (create N events), reject (no mutations), and batch undo (delete all created events within 5s window)
- UndoContext refactored from implicit tuple to explicit struct, cleanly supporting both single-action and batch-plan undo paths

## Files Created/Modified

| File | Change | Purpose |
|------|--------|---------|
| `LoomCal/Models/DailyPlanProposal.swift` | Created | DailyPlanProposal + PlannedBlock model with custom String/Int Codable |
| `bridge/loom-bridge.mjs` | Modified | Daily Planning system prompt section, daily_plan detection/validation, blocks array normalization |
| `LoomCal/Models/ChatMessage.swift` | Modified | Added `decodedPlan` and `isDailyPlan` computed properties |
| `LoomCal/ViewModels/ChatViewModel.swift` | Modified | UndoContext struct, approveDailyPlan, rejectDailyPlan, batch undo in undoAction |
| `LoomCal/Views/Chat/ChatView.swift` | Modified | UndoBanner reads displaySummary from UndoContext struct (type adaptation) |

## Decisions Made

| Decision | Rationale | Impact |
|----------|-----------|--------|
| UndoContext struct replaces tuple | Supports both single and batch undo paths cleanly | Future action types can extend UndoContext without refactoring |
| PlannedBlock custom Codable init | Bridge normalizes to strings, but raw int may arrive in tests/future | Robust against format variation |
| Separate DailyPlanProposal from LoomAction | Daily plans have different structure (nested blocks array) vs flat payload | Clean separation, no LoomAction changes needed |
| decodedPlan type guard | Prevents false positive decoding of non-plan action strings | Safety without performance cost |

## Deviations from Plan

### Summary

| Type | Count | Impact |
|------|-------|--------|
| Auto-fixed | 1 | Minimal — type adaptation in ChatView |

**Total impact:** Essential adaptation, no scope creep.

### Auto-fixed Issues

**1. ChatView UndoBanner type adaptation**
- **Found during:** Task 3 (UndoContext refactor)
- **Issue:** ChatView.swift read undo banner data from the old tuple shape; UndoContext struct changed the interface
- **Fix:** Updated ChatView to read `undo.displaySummary` from UndoContext struct
- **Files:** LoomCal/Views/Chat/ChatView.swift
- **Verification:** Xcode build succeeds
- **Note:** Not a UI feature addition (plan boundary respected) — just type adaptation for the refactored undo context

## Issues Encountered

None

## Next Phase Readiness

**Ready:**
- Bridge fully supports daily_plan ACTION blocks (detection, validation, normalization)
- Swift model layer decodes plan proposals with typed blocks array
- ChatViewModel has complete approve/reject/undo lifecycle for daily plans
- Plan 06-02 can focus purely on the DailyPlanCard UI component and ChatView integration

**Concerns:**
- None

**Blockers:**
- None

---
*Phase: 06-ai-daily-planning, Plan: 01*
*Completed: 2025-02-22*
