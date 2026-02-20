---
phase: 02-calendar-views
plan: 01
subsystem: ui
tags: [swiftui, horizoncalendar, convex, calendar, timeline, uiviewrepresentable]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: "ConvexMobile SDK integration, LoomEvent Swift model with @ConvexInt, global convex singleton"
provides:
  - "CalendarViewModel: @MainActor ObservableObject with Convex events:list subscription and CRUD mutations"
  - "DayTimelineView: scrollable 24-hour timeline with hour grid, event cards, now indicator, all-day banner"
  - "MiniMonthView: HorizonCalendar 1.x UIViewRepresentable wrapper with day selection and event dot indicators"
  - "TimelineEventCard: Fantastical-style rounded card with blue accent bar, title + 12-hour formatted time"
  - "NowIndicatorView: red line+dot updating every 60 seconds via TimelineView(.periodic)"
  - "AllDayBannerView: horizontal pill strip, collapses to EmptyView when empty"
affects: [02-02-event-crud, 02-03-week-view, 02-04-navigation]

# Tech tracking
tech-stack:
  added:
    - "HorizonCalendar 1.16.0 — mini month calendar grid via UIViewRepresentable (resolved 1.x, not 2.x)"
  patterns:
    - "UIViewRepresentable wrapping HorizonCalendar 1.x CalendarView — CalendarViewRepresentable is 2.x API only"
    - "CalendarViewModel @MainActor ObservableObject with Task-based subscription and cancellation"
    - "[String: ConvexEncodable?] type required for mutation args — [String: Any] does not conform"
    - "iOS 18 ScrollPosition binding for auto-scroll to current time on DayTimelineView appear"
    - "Greedy column-assignment algorithm for overlapping events in DayTimelineView"
    - "TimelineView(.periodic(from:by:60)) for NowIndicatorView minute updates"

key-files:
  created:
    - "LoomCal/ViewModels/CalendarViewModel.swift — centralized state, Convex subscription, CRUD mutations"
    - "LoomCal/Views/Calendar/DayTimelineView.swift — 24h scrollable timeline with event layout engine"
    - "LoomCal/Views/Calendar/MiniMonthView.swift — HorizonCalendar UIViewRepresentable + MiniDayCellView"
    - "LoomCal/Views/Calendar/TimelineEventCard.swift — Fantastical-style event card"
    - "LoomCal/Views/Calendar/NowIndicatorView.swift — red line+dot time indicator"
    - "LoomCal/Views/Calendar/AllDayBannerView.swift — all-day event pill banner"
  modified:
    - "LoomCal.xcodeproj/project.pbxproj — added HorizonCalendar SPM package, ViewModels group, Calendar group, all 6 new Swift files"

key-decisions:
  - "HorizonCalendar resolved at 1.16.0 (1.x), not 2.x — CalendarViewRepresentable is a 2.x API; wrapped UIKit CalendarView in UIViewRepresentable instead"
  - "ConvexMobile mutation args must be [String: ConvexEncodable?] not [String: Any] — Int, Bool, String all conform to ConvexEncodable"
  - "MiniDayCellView implemented as CalendarItemViewRepresentable UIView subclass for HorizonCalendar 1.x day cell customization"
  - "DayTimelineView uses iOS 18 ScrollPosition binding with DispatchQueue.main.asyncAfter(0.05) delay for reliable auto-scroll to current time"
  - "Overlapping events use greedy column-assignment: sort by start, assign to first non-overlapping column, divide width equally"

patterns-established:
  - "CalendarViewModel pattern: single @MainActor ObservableObject owns subscription + CRUD; never subscribe in view .task{} blocks"
  - "HorizonCalendar 1.x pattern: UIViewRepresentable wrapper with CalendarViewContent dayItemProvider and daySelectionHandler callback"
  - "Timeline layout pattern: ZStack with totalHeight=1440pt, events offset by (hour*60+minute)/60*pointsPerHour"
  - "ConvexMobile mutation pattern: [String: ConvexEncodable?] explicit type annotation required to satisfy generic constraint"

requirements-completed: [CALV-01]

# Metrics
duration: 6min
completed: 2026-02-20
---

# Phase 2 Plan 01: Calendar View Infrastructure Summary

**Fantastical-style day timeline with CalendarViewModel Convex subscription, HorizonCalendar 1.x mini month picker (UIViewRepresentable), and 5 calendar views including 24h scrollable timeline with greedy overlap layout**

## Performance

- **Duration:** 6 min
- **Started:** 2026-02-20T21:07:41Z
- **Completed:** 2026-02-20T21:14:16Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- Built CalendarViewModel as the single source of truth for all calendar state — Convex subscription, selected date, CRUD mutations, and date-filtering helpers (events/allDayEvents/timedEvents for a given Date)
- Created DayTimelineView with full 24-hour scrollable layout: hour grid lines with 12-hour labels, absolute-positioned event cards via greedy column-assignment algorithm for overlapping events, iOS 18 ScrollPosition auto-scroll to current time, and NowIndicatorView updating every 60 seconds
- Wrapped HorizonCalendar 1.16.0 (UIKit-based) in UIViewRepresentable with custom MiniDayCellView showing selected/today/event-dot states; day tap updates CalendarViewModel.selectedDate

## Task Commits

Each task was committed atomically:

1. **Task 1: CalendarViewModel and HorizonCalendar SPM dependency** - `d91e6fb` (feat)
2. **Task 2: Build day timeline view with event cards, now-indicator, and mini month** - `4831f96` (feat)

**Plan metadata:** (to be added after SUMMARY.md commit)

## Files Created/Modified
- `LoomCal/ViewModels/CalendarViewModel.swift` — @MainActor ObservableObject; startSubscription(), stopSubscription(), events(for:), allDayEvents(for:), timedEvents(for:), createEvent(), updateEvent(), deleteEvent()
- `LoomCal/Views/Calendar/DayTimelineView.swift` — 24h timeline with AllDayBannerView, hour grid, NowIndicatorView, greedy event layout, iOS 18 ScrollPosition auto-scroll
- `LoomCal/Views/Calendar/MiniMonthView.swift` — UIViewRepresentable wrapping HorizonCalendar CalendarView; MiniDayCellView with selected/today/event-dot visual states
- `LoomCal/Views/Calendar/TimelineEventCard.swift` — rounded rectangle, blue opacity background, 4pt leading accent bar, shadow(radius:4), title + "h:mm a" time
- `LoomCal/Views/Calendar/NowIndicatorView.swift` — TimelineView(.periodic(from:.now, by:60)) wrapping red line+dot
- `LoomCal/Views/Calendar/AllDayBannerView.swift` — horizontal scroll of pill-shaped all-day event labels; EmptyView when empty
- `LoomCal.xcodeproj/project.pbxproj` — HorizonCalendar SPM package reference + product dependency, ViewModels group, Calendar group, all 6 Swift file entries

## Decisions Made
- Used HorizonCalendar 1.16.0 (1.x, not 2.x) — the SPM resolved to 1.x via `upToNextMajorVersion >= 1.11.0`. CalendarViewRepresentable is only in HorizonCalendar 2.x; the 1.x API uses UIKit `CalendarView` which must be wrapped in `UIViewRepresentable`. The wrapper approach works correctly.
- ConvexMobile mutation args require `[String: ConvexEncodable?]` — the plan showed `[String: Any]` which causes a type error. All mutation arg dictionaries use explicit `[String: ConvexEncodable?]` type annotations.
- MiniDayCellView as `CalendarItemViewRepresentable` UIView — HorizonCalendar 1.x day cells must conform to this protocol for the `dayItemProvider` closure.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] CalendarViewRepresentable does not exist in HorizonCalendar 1.x**
- **Found during:** Task 2 (MiniMonthView build errors)
- **Issue:** Plan specified `CalendarViewRepresentable` which is a HorizonCalendar 2.x API. SPM resolved 1.16.0 (1.x). The type does not exist in 1.x.
- **Fix:** Rewrote MiniMonthView as a `UIViewRepresentable` wrapping HorizonCalendar's UIKit `CalendarView`. Created `HorizonCalendarView` struct and `MiniDayCellView: UIView & CalendarItemViewRepresentable` for custom day cell rendering.
- **Files modified:** `LoomCal/Views/Calendar/MiniMonthView.swift`
- **Verification:** BUILD SUCCEEDED with HorizonCalendar 1.16.0
- **Committed in:** 4831f96 (Task 2 commit)

**2. [Rule 1 - Bug] ConvexMobile mutation requires [String: ConvexEncodable?] not [String: Any]**
- **Found during:** Task 1 (CalendarViewModel build errors)
- **Issue:** `convex.mutation()` generic constraint requires `[String: ConvexEncodable?]` but plan's code pattern used `[String: Any]` cast. Swift type checker rejects the conversion.
- **Fix:** Changed all mutation arg dictionaries to use explicit `[String: ConvexEncodable?]` type annotations. Int, Bool, String all conform to ConvexEncodable natively.
- **Files modified:** `LoomCal/ViewModels/CalendarViewModel.swift`
- **Verification:** BUILD SUCCEEDED
- **Committed in:** d91e6fb (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 bugs)
**Impact on plan:** Both fixes required for compilation. No scope creep. Functionality is identical to plan spec — UIViewRepresentable wrapper provides equivalent API to what CalendarViewRepresentable would have given.

## Issues Encountered
- HorizonCalendar resolved at 1.x (not 2.x) because the requirement was set to `upToNextMajorVersion >= 1.11.0`. The plan intended `from: "2.0.0"` in the requirement string, but `upToNextMajorVersion` of 1.x stays within 1.x. The UIViewRepresentable wrapper is a clean solution and avoids any risk of 2.x breaking changes.

## User Setup Required
None — no external service configuration required. HorizonCalendar resolves via SPM automatically.

## Next Phase Readiness
- CalendarViewModel is ready as a `@StateObject` in ContentView or any parent view
- DayTimelineView accepts pre-filtered `[LoomEvent]` from `viewModel.timedEvents(for:)` and `viewModel.allDayEvents(for:)`
- MiniMonthView is ready to integrate with `@ObservedObject var viewModel: CalendarViewModel`
- Plan 02 can wire event tap callbacks (`onEventTap`) to EventDetailView sheets
- Plan 02 can wire `onDateLongPress` on MiniMonthView to event creation flow

## Self-Check: PASSED

- FOUND: LoomCal/ViewModels/CalendarViewModel.swift
- FOUND: LoomCal/Views/Calendar/DayTimelineView.swift
- FOUND: LoomCal/Views/Calendar/MiniMonthView.swift
- FOUND: LoomCal/Views/Calendar/TimelineEventCard.swift
- FOUND: LoomCal/Views/Calendar/NowIndicatorView.swift
- FOUND: LoomCal/Views/Calendar/AllDayBannerView.swift
- FOUND: commit d91e6fb (Task 1)
- FOUND: commit 4831f96 (Task 2)
- BUILD SUCCEEDED on iOS target

---
*Phase: 02-calendar-views*
*Completed: 2026-02-20*
