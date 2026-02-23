---
phase: 07-natural-language-entry
plan: 02
subsystem: ui
tags: [swiftui, nlparse, things3, progressive-disclosure, loomcolors]

requires:
  - phase: 07-natural-language-entry/07-01
    provides: parse_requests Convex table, nlParse mutations/queries, bridge processing
provides:
  - NLParseService Swift singleton for NL → structured data via Convex
  - ParsedNLResult Decodable model for parse_requests documents
  - Things 3-inspired EventCreationView with NL hero input, parsed summary card, progressive disclosure
  - Things 3-inspired TaskCreationView with NL hero input, custom priority capsule chips, progressive disclosure
  - Sheet presentation detents on all creation/detail sheets
affects: [08-platform-polish]

tech-stack:
  added: []
  patterns: [hero NL input with accent underline, progressive disclosure via @State toggle, custom capsule chip buttons, FocusState auto-focus with delay]

key-files:
  created: [LoomCal/Models/ParsedNLResult.swift, LoomCal/Services/NLParseService.swift]
  modified: [LoomCal/Views/Events/EventCreationView.swift, LoomCal/Views/Tasks/TaskCreationView.swift, LoomCal/Views/ContentView.swift]

key-decisions:
  - "ScrollView+VStack over Form for full layout control"
  - "Progressive disclosure: details hidden until user toggles or NL parse completes"
  - "Custom capsule priority chips instead of segmented Picker"
  - "Sheet detents (.medium/.large) on all creation and detail sheets"
  - "NL hero input auto-focused with 0.5s delay to avoid keyboard animation conflicts"

patterns-established:
  - "Hero input pattern: .title2 font, .plain textFieldStyle, accent underline Rectangle, parsing state indicator"
  - "Progressive disclosure: @State showDetails toggle with chevron, auto-expands after NL parse"
  - "PriorityChip reusable component: capsule with color fill when selected, gray.opacity(0.1) when not"
  - "LoomColors applied consistently: eventDefault for event accent, sage for task accent, coral for buttons/toggles"

duration: ~20min
started: 2026-02-22
completed: 2026-02-22
---

# Phase 7 Plan 02: Swift NL Integration + Things 3 UI Redesign Summary

**NLParseService connects Swift to Convex NL parsing; EventCreationView and TaskCreationView redesigned with Things 3-inspired aesthetics — hero NL input, progressive disclosure, custom priority chips, LoomColors palette**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~20 min |
| Started | 2026-02-22 |
| Completed | 2026-02-22 |
| Tasks | 2 auto + 1 checkpoint completed |
| Files modified | 5 |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-1: NL Event Parsing via Loom | Pass | EventCreationView sends NL text to NLParseService, receives parsed fields, populates title/date/time/duration |
| AC-2: NL Task Parsing via Loom | Pass | TaskCreationView sends NL text to NLParseService, receives parsed fields, populates title/priority/dueDate |
| AC-3: Fallback When Loom Unreachable | Pass | EventCreationView falls back to local NLEventParser; TaskCreationView uses raw input as title |
| AC-4: Loading State During Parse | Pass | ProgressView + "Parsing..." text with gold accent underline while in-flight |

## Accomplishments

- Built NLParseService singleton with timeout-racing async subscription pattern
- Redesigned both creation views from generic Form to Things 3-inspired ScrollView+VStack with hero NL input
- Added progressive disclosure that auto-expands after successful NL parse
- Replaced segmented Picker with custom PriorityChip capsule buttons (sage/gold/coral)
- Applied LoomColors consistently across both views (accent underlines, buttons, toggles, summary cards)
- Added .presentationDetents([.medium, .large]) to all 6 sheet sites in ContentView + TaskListTabView

## Task Commits

| Task | Commit | Type | Description |
|------|--------|------|-------------|
| Task 1-2: NLParseService + View upgrades | `fa28d07` | feat | NL parse service, model, EventCreation/TaskCreation NL integration |
| UI Redesign: Things 3 aesthetics | `f0aacd6` | feat | Full UI overhaul of both creation views + sheet detents |

## Files Created/Modified

| File | Change | Purpose |
|------|--------|---------|
| `LoomCal/Models/ParsedNLResult.swift` | Created | Decodable struct for parse_requests docs + eventFields/taskFields computed properties |
| `LoomCal/Services/NLParseService.swift` | Created | @MainActor singleton: creates parse request, subscribes for result, races against 10s timeout |
| `LoomCal/Views/Events/EventCreationView.swift` | Modified | Replaced Form with ScrollView+VStack, hero NL input with eventDefault underline, parsed summary card, progressive disclosure, FocusState, LoomColors |
| `LoomCal/Views/Tasks/TaskCreationView.swift` | Modified | Replaced Form with ScrollView+VStack, hero NL input with sage underline, custom PriorityChip capsules, progressive disclosure with indicator icons, FocusState |
| `LoomCal/Views/ContentView.swift` | Modified | Added presentationDetents([.medium, .large]) and presentationDragIndicator(.visible) to all 6 sheet sites |

## Decisions Made

| Decision | Rationale | Impact |
|----------|-----------|--------|
| ScrollView+VStack over Form | Full layout control, no default Form chrome, Things 3 aesthetic | All future creation views should follow this pattern |
| Progressive disclosure | Content-first: show NL hero and essentials, hide detail fields until needed | Cleaner initial sheet appearance at .medium detent |
| Custom PriorityChip over Picker | Visual priority distinction with LoomColors (sage/gold/coral capsules) | Reusable component for any priority selection |
| Sheet detents on all sheets | Sheets open at half-screen, expandable — less jarring than full-screen | Consistent sheet behavior app-wide |

## Deviations from Plan

### Summary

| Type | Count | Impact |
|------|-------|--------|
| Scope additions | 1 | Essential UX polish |

**Total impact:** UI redesign was added on top of the original 07-02 plan scope (which only covered NL integration). The redesign was a natural extension — both creation views were already being modified.

### Details

**1. Things 3 UI Redesign (added scope)**
- **Context:** Original 07-02 plan only covered NL service + wiring. UI redesign was requested separately after plan was applied.
- **Addition:** Full visual overhaul of both views, PriorityChip component, sheet detents, LoomColors integration.
- **Files:** Same files as original plan — no additional files created.
- **Verification:** Xcode build succeeded on iPhone 17 Pro simulator.

## Issues Encountered

None.

## Next Phase Readiness

**Ready:**
- Phase 7 complete — all NL entry infrastructure and UI in place
- Both creation views accept NL input, parse via Loom, show loading, fall back gracefully
- Views use LoomColors palette and Things 3 design patterns
- Sheet detents provide consistent presentation behavior

**Concerns:**
- None

**Blockers:**
- None

---
*Phase: 07-natural-language-entry, Plan: 02*
*Completed: 2026-02-22*
