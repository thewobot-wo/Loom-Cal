---
phase: 02-calendar-views
plan: 03
subsystem: ui
tags: [swiftui, week-view, drag-gesture, navigation, identifiable, sheet-item, convex, morgen]

# Dependency graph
requires:
  - phase: 02-calendar-views
    plan: 01
    provides: "CalendarViewModel, DayTimelineView, MiniMonthView, TimelineEventCard"
  - phase: 02-calendar-views
    plan: 02
    provides: "EventCreationView, EventDetailView, EventEditView, NLEventParser"
provides:
  - "WeekTimelineView: 7-column week layout with month/year header, per-day timelines, auto-scroll"
  - "ContentView: NavigationStack, segmented Day/Week, mini month in day mode only, .sheet(item:) for events"
  - "LoomEvent: Identifiable conformance via var id: String { _id }"
  - "TimelineEventCard: long-press + drag gesture with visual feedback"
  - "DayTimelineView: GeometryReader-as-root pattern, Color.clear height spacer for reliable scrolling"
  - "End time pickers in EventCreationView and EventEditView (replaced duration picker)"
  - "Alert-based delete confirmation (replaced unreliable confirmationDialog)"
affects: [03-tasks, 04-chat]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "GeometryReader as ROOT view (outside ScrollView) — prevents scroll-blocking anti-pattern"
    - "Color.clear.frame(height: totalHeight) as first ZStack child — guarantees ScrollView content height"
    - "LongPressGesture.sequenced(before: DragGesture) for drag-to-move"
    - ".sheet(item: $selectedEvent) with LoomEvent: Identifiable"
    - ".alert instead of .confirmationDialog for nested-sheet reliability"
    - "End time DatePicker with in: startTime.addingTimeInterval(900)... range constraint"
    - "platformFilters = (ios, ) in pbxproj for UIKit-only SPM packages on multiplatform targets"
    - "#if canImport(UIKit) / #if !os(macOS) guards for platform-specific APIs"

key-files:
  created:
    - "LoomCal/Views/Calendar/WeekTimelineView.swift — 7-column week timeline with month header, auto-scroll"
  modified:
    - "LoomCal/Models/LoomEvent.swift — Identifiable conformance"
    - "LoomCal/Views/Calendar/TimelineEventCard.swift — long-press+drag gesture"
    - "LoomCal/Views/Calendar/DayTimelineView.swift — GeometryReader-as-root, Color.clear spacer, fixed scrolling"
    - "LoomCal/Views/Calendar/MiniMonthView.swift — #if canImport(UIKit) guards, macOS LazyVGrid fallback"
    - "LoomCal/Views/ContentView.swift — Morgen-style layout, mini month hidden in week mode"
    - "LoomCal/Views/Events/EventCreationView.swift — end time picker, removed duration picker"
    - "LoomCal/Views/Events/EventEditView.swift — end time picker, removed duration picker"
    - "LoomCal/Views/Events/EventDetailView.swift — .alert for delete, replaced confirmationDialog"
    - "LoomCal/Views/Calendar/AllDayBannerView.swift — cross-platform Color"
    - "LoomCal/Views/Calendar/WeekTimelineView.swift — cross-platform Color"
    - "LoomCal.xcodeproj/project.pbxproj — platformFilters for HorizonCalendar, WeekTimelineView added"

key-decisions:
  - "Mini month hidden in week mode — week header IS the navigation, eliminates redundant double-calendar"
  - "End time pickers replace duration picker — no artificial cap, more natural time entry"
  - ".alert replaces .confirmationDialog for delete — more reliable in nested sheet contexts"
  - "GeometryReader must be ROOT view, never inside ScrollView — GeometryReader inside ScrollView prevents scrolling"
  - "Color.clear spacer needed as first ZStack child in ScrollView — offset-positioned children don't report correct content height"
  - "HorizonCalendar needs platformFilters = (ios, ) — UIKit dependency fails macOS build"
  - "Cross-platform colors: Color.gray.opacity(0.15) replaces Color(.systemGray5), .background replaces Color(.systemBackground)"

patterns-established:
  - "ScrollView content pattern: GeometryReader at ROOT → pass width down → ScrollView > ZStack > Color.clear.frame(height:) + offset-positioned content"
  - "Multiplatform guard pattern: #if canImport(UIKit) for UIKit-specific code, #if !os(macOS) for iOS-only modifiers"
  - "Drag-to-move: LongPressGesture.sequenced(before: DragGesture) with 15-minute snap"

requirements-completed: [CALV-01, CALV-02]

# Metrics
duration: ~15min (including post-checkpoint fixes)
completed: 2026-02-20
---

# Phase 2 Plan 03: Week Timeline and Full Calendar Layout Summary

**Morgen-style calendar app: WeekTimelineView, full ContentView replacement, end time pickers, reliable delete, fixed scrolling, macOS platform guards**

## Performance

- **Duration:** ~15 min (Task 1 + checkpoint fixes)
- **Started:** 2026-02-20T21:24:31Z
- **Completed:** 2026-02-20
- **Tasks:** 2/2 (Task 2 = human-verify checkpoint, approved)
- **Files modified:** 11

## Accomplishments

- Created WeekTimelineView with 7-column layout, month/year header, proper day cells with selected/today indicators, auto-scroll to current time
- Replaced ContentView with Morgen-style layout: mini month visible only in day mode, hidden in week mode (week header IS the navigation)
- Added Identifiable conformance to LoomEvent for .sheet(item:) support
- Added long-press + drag gesture to TimelineEventCard for drag-to-move events
- Replaced duration picker with end time DatePicker in both creation and edit views — no artificial cap
- Replaced .confirmationDialog with .alert for delete — fixes unreliable trigger in nested sheets
- Fixed DayTimelineView scrolling: GeometryReader moved to root (outside ScrollView), Color.clear spacer for content height
- Added macOS platform guards: HorizonCalendar platformFilters, #if canImport(UIKit) for MiniMonthView with LazyVGrid fallback, cross-platform colors

## Task Commits

| Task | Name | Commit |
|------|------|--------|
| 1 | WeekTimelineView, ContentView, LoomEvent Identifiable, drag-to-move | adc295c |
| fix | macOS platform guards for HorizonCalendar and UIKit APIs | a8119fb |
| fix | simultaneousGesture for swipe nav (intermediate) | b04b548 |
| fix | GeometryReader-as-root, Color.clear spacer for scrolling | 8de8027, ef948e7 |
| fix | End time pickers, reliable delete, week view redesign | bf16db6 |
| 2 | Human verification checkpoint — approved | — |

## Post-Checkpoint Fixes

1. **HorizonCalendar macOS build failure** — added platformFilters = (ios, ) to pbxproj, wrapped MiniMonthView with #if canImport(UIKit), added macOS LazyVGrid fallback
2. **DayTimelineView scroll blocked** — GeometryReader inside ScrollView prevented scrolling; moved to root view, added Color.clear height spacer
3. **Duration capped at 2 hours** — replaced Picker with end time DatePicker in EventCreationView and EventEditView
4. **Delete required 3 taps** — replaced .confirmationDialog with .alert in EventDetailView
5. **Week view poor UI** — hid mini month in week mode, redesigned week header with month label and proper day indicators

## Self-Check: PASSED

- FOUND: LoomCal/Views/Calendar/WeekTimelineView.swift
- FOUND: LoomCal/Models/LoomEvent.swift — Identifiable conformance
- FOUND: LoomCal/Views/ContentView.swift — ViewMode, segmented control, mini month conditional
- VERIFIED: BUILD SUCCEEDED on iOS target
- VERIFIED: User approved checkpoint

---
*Phase: 02-calendar-views*
*Completed: 2026-02-20*
