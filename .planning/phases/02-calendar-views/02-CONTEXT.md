# Phase 2: Calendar Views - Context

**Gathered:** 2026-02-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Day and week calendar views with Convex-native event CRUD. Users can see events in a timeline, create events (with basic local natural-language parsing), edit event details, delete events, and navigate between day/week views. A mini month calendar provides date navigation. Full Loom-powered NLP is Phase 7.

</domain>

<decisions>
## Implementation Decisions

### Timeline layout
- Fantastical-inspired style: clean, generous whitespace, events as rounded cards with subtle shadows
- Events show title + time only — details on tap
- Red horizontal line with dot for current-time indicator (classic Apple Calendar now-marker)
- Auto-scroll to current time when opening the view
- All-day events displayed as banner at the top of the timeline, above the time grid
- Hour labels always 12-hour format (2 PM, 3:30 PM)

### Default view & navigation
- Default view on app open: mini month calendar on top + today's day timeline below (Fantastical-style layout)
- Mini month always visible at top — tap any date to jump to that day's timeline
- Segmented control (Day | Week) in the header for switching between day and week views
- Swipe left/right on timeline navigates between days (or weeks in week view)

### Event creation flow
- Plus button opens event creation view
- Long-press on a date in the mini month opens creation view with that date pre-filled
- Creation view: text field for natural language input at top + expandable details card below for manual input
- Basic local parsing (regex/DateFormatter) — "Dentist 3pm" extracts title + time. No AI/Loom required.
- Default event duration: 1 hour

### Event editing & deletion
- Tap an event on timeline opens a detail sheet with event info + Edit and Delete buttons
- Long-press and drag an event block to move it to a different time slot on the timeline
- Delete requires confirmation dialog ("Delete this event?") before removing
- Changes reflect in real-time across iOS and Mac via Convex subscriptions

### Claude's Discretion
- Time scale density (hours visible without scrolling) — adapt to device size
- Overlapping event display strategy (side-by-side vs. stacked)
- Drag-to-resize on event edges (adjust duration directly on timeline) — implement if feasible, skip if too complex for Phase 2
- Loading skeleton design
- Exact spacing, typography, and card shadow values
- Error state handling

</decisions>

<specifics>
## Specific Ideas

- Fantastical is the primary visual reference — clean cards, generous whitespace, mini month + day timeline combo
- "Month overview + day" as the default landing view — user explicitly wants to see the bigger picture with today's detail
- Natural language input is important to the user even pre-Loom — basic local parsing bridges to Phase 7
- Red now-marker is a deliberate choice — classic, recognizable

</specifics>

<deferred>
## Deferred Ideas

- Full Loom-powered natural language parsing — Phase 7
- Event color coding by calendar — future phase
- Recurring events — not in Phase 2 scope

</deferred>

---

*Phase: 02-calendar-views*
*Context gathered: 2026-02-20*
