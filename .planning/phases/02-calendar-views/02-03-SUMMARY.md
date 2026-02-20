---
phase: 02-calendar-views
plan: 03
subsystem: ui
tags: [swiftui, week-view, drag-gesture, navigation, identifiable, sheet-item, convex]

# Dependency graph
requires:
  - phase: 02-calendar-views
    plan: 01
    provides: "CalendarViewModel, DayTimelineView, MiniMonthView, TimelineEventCard"
  - phase: 02-calendar-views
    plan: 02
    provides: "EventCreationView, EventDetailView, EventEditView, NLEventParser"
provides:
  - "WeekTimelineView: 7-column week layout with per-day timelines, events, now indicator"
  - "ContentView (full replacement): NavigationStack, segmented Day/Week control, MiniMonthView always visible, swipe navigation, plus button, .sheet(item: $selectedEvent)"
  - "LoomEvent: Identifiable conformance via var id: String { _id }"
  - "TimelineEventCard: long-press + drag gesture with visual feedback; onDragMove callback"
  - "DayTimelineView: onEventDragMove((LoomEvent, CGFloat)->Void) wired through from TimelineEventCard"
affects: [03-tasks, 04-chat]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "LongPressGesture.sequenced(before: DragGesture) for drag-to-move — activates on hold, tracks vertical delta"
    - "ViewMode enum (CaseIterable) as Picker selection — ForEach ViewMode.allCases with .tag"
    - ".sheet(item: $selectedEvent) with LoomEvent: Identifiable — id: String { _id } computed property"
    - "DragGesture on timeline container for swipe navigation — horizontal/vertical disambiguation via abs(xDelta) > abs(yDelta)"
    - "15-minute snap via Int(round(rawMinutes / 15.0)) * 15"
    - "Calendar.dateInterval(of: .weekOfYear, for:) to compute week start for WeekTimelineView"
    - "GeometryReader column width: (geometry.size.width - gutterWidth) / 7"
    - "Narrow column detection: columnWidth < 60 — colored bar only vs abbreviated title"

key-files:
  created:
    - "LoomCal/Views/Calendar/WeekTimelineView.swift — 7-column week timeline, 50pt/hr, shared gutter, day headers, now indicator, narrow/wide event cards"
  modified:
    - "LoomCal/Models/LoomEvent.swift — added Identifiable conformance; var id: String { _id }"
    - "LoomCal/Views/Calendar/TimelineEventCard.swift — long-press+drag gesture, dragOffset state, onDragMove callback, drag visual feedback"
    - "LoomCal/Views/Calendar/DayTimelineView.swift — onEventDragMove callback parameter, wired to TimelineEventCard.onDragMove"
    - "LoomCal/Views/ContentView.swift — full replacement: ViewMode enum, @StateObject viewModel, segmented control, MiniMonthView, Day/Week timeline switch, swipe navigation, sheets, handleDragMove"
    - "LoomCal.xcodeproj/project.pbxproj — WeekTimelineView.swift added to Calendar group and Sources build phase"

key-decisions:
  - "LoomEvent Identifiable via computed var id: String { _id } — avoids renaming the _id field which is required for Convex Decodable conformance"
  - "Swipe navigation uses horizontal/vertical disambiguation (abs(xDelta) > abs(yDelta)) to avoid firing during vertical event drag"
  - "ContentView creates its own @StateObject CalendarViewModel — LoomCalApp keeps EventKitService injection (for later phases) but ContentView no longer references it"
  - "WeekTimelineView narrow column threshold: 60pt — below that, only colored bar (no text) per RESEARCH open question #3"

patterns-established:
  - "Drag-to-move pattern: LongPressGesture.sequenced(before: DragGesture) activates drag; parent receives (event, pointsDelta) and converts to time delta"
  - "ContentView as full app shell: @StateObject viewModel, ViewMode enum, all sheet states, swipe navigation"
  - "Identifiable model conformance via computed property wrapping existing unique field"

requirements-completed: [CALV-01, CALV-02]

# Metrics
duration: 3min
completed: 2026-02-20
---

# Phase 2 Plan 03: Week Timeline and Full Calendar Layout Summary

**Partial summary — Task 1 complete (adc295c), awaiting human verification at checkpoint (Task 2)**

**Complete Fantastical-style calendar app: LoomEvent Identifiable, drag-to-move on day timeline, 7-column WeekTimelineView, ContentView replaced with full NavigationStack layout — segmented Day/Week control, MiniMonthView, swipe navigation, .sheet(item: $selectedEvent)**

## Performance

- **Duration:** ~3 min (Task 1 only — paused at checkpoint)
- **Started:** 2026-02-20T21:24:31Z
- **Tasks:** 1 of 2 complete
- **Files modified:** 6

## Accomplishments

- Added `Identifiable` conformance to `LoomEvent` via `var id: String { _id }` — enables `.sheet(item: $selectedEvent)` in ContentView without breaking existing Decodable conformance
- Updated `TimelineEventCard` with long-press + drag gesture using `LongPressGesture.sequenced(before: DragGesture)` — long-press activates drag mode (preventing accidental drags), tracks `dragOffset` for visual feedback, calls `onDragMove?(delta)` on end
- Updated `DayTimelineView` with `onEventDragMove: ((LoomEvent, CGFloat) -> Void)?` callback, wired to each `TimelineEventCard`
- Created `WeekTimelineView` with 7-column layout using `GeometryReader`, shared time-label gutter (35pt), day headers (abbreviated weekday + day number with today/selected highlighting), `Calendar.dateInterval(of: .weekOfYear)` for week start, now indicator spanning all columns, narrow column (<60pt) colored bars vs wider abbreviated-title cards
- Fully replaced Phase 1 proof-of-concept `ContentView` with Fantastical-style layout: `@StateObject CalendarViewModel`, `ViewMode` enum segmented control, `MiniMonthView` always visible, conditional Day/Week timeline, swipe navigation with horizontal/vertical disambiguation, plus button + long-press creation sheet, `.sheet(item: $selectedEvent)` with `EventDetailView`, `handleDragMove` with 15-minute snapping

## Task Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add Identifiable to LoomEvent, drag-to-move, WeekTimelineView, replace ContentView | adc295c | 6 files |

## Files Created/Modified

- `LoomCal/Models/LoomEvent.swift` — `Identifiable` conformance; `var id: String { _id }`
- `LoomCal/Views/Calendar/TimelineEventCard.swift` — long-press+drag gesture; `@State dragOffset/isDragging`; `onDragMove: ((CGFloat) -> Void)?` callback; visual feedback (opacity 0.8, shadow(radius:8) during drag)
- `LoomCal/Views/Calendar/DayTimelineView.swift` — `onEventDragMove: ((LoomEvent, CGFloat) -> Void)?` parameter; wired to `TimelineEventCard.onDragMove`
- `LoomCal/Views/Calendar/WeekTimelineView.swift` — 7-column layout; `pointsPerHour = 50`; `gutterWidth = 35`; `weekDates` computed from `Calendar.dateInterval(of: .weekOfYear)`; day headers with tap-to-navigate; shared gutter with 2-hour interval labels; `TimelineView(.periodic)` now indicator; per-day `ZStack` event columns; narrow/wide column branching at 60pt
- `LoomCal/Views/ContentView.swift` — full replacement; `ViewMode` enum; `@StateObject viewModel`; segmented `Picker`; `MiniMonthView` with long-press; `DayTimelineView`/`WeekTimelineView` conditional; `DragGesture` swipe navigation; `.task { viewModel.startSubscription() }`; `.sheet(isPresented:)` for creation; `.sheet(item: $selectedEvent)` for detail; `handleDragMove` with 15-min snap
- `LoomCal.xcodeproj/project.pbxproj` — `WeekTimelineView.swift` added to Calendar PBXGroup and PBXSourcesBuildPhase

## Decisions Made

- `var id: String { _id }` computed property satisfies `Identifiable` without requiring stored property (avoids CodingKeys complications with existing `@ConvexInt` wrapper properties)
- ContentView now creates its own `@StateObject CalendarViewModel` — LoomCalApp still injects `EventKitService` environmentObject (needed in Phase 5/6) but new ContentView no longer reads it
- Swipe navigation disambiguation: `abs(xDelta) > abs(yDelta)` check prevents accidental day navigation when user is vertically scrolling the timeline
- 15-minute snap: `Int(round(rawMinutes / 15.0)) * 15` — clean alignment with standard calendar time slots

## Deviations from Plan

None — plan executed exactly as written. All 6 substeps of Task 1 implemented per specification. Build succeeded on first attempt.

## Issues Encountered

None — BUILD SUCCEEDED without errors or warnings relevant to the changes.

## Self-Check: PASSED

- FOUND: LoomCal/Views/Calendar/WeekTimelineView.swift
- FOUND: LoomCal/Models/LoomEvent.swift — Identifiable conformance present
- FOUND: LoomCal/Views/ContentView.swift — ViewMode, @StateObject, segmented control, .sheet(item:) present
- FOUND: commit adc295c (Task 1)
- BUILD SUCCEEDED on iOS target

---
*Phase: 02-calendar-views*
*Completed: 2026-02-20 (partial — awaiting checkpoint verification)*
