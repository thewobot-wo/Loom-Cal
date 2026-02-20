---
phase: 01-foundation
plan: 03
subsystem: ui
tags: [swift, swiftui, eventkit, ios, macos, usersdefaults, entitlements, permissions, convexmobile]

# Dependency graph
requires:
  - phase: 01-02
    provides: "LoomCal Xcode project with ConvexMobile 0.8.0; ContentView with events:list subscription; Info.plist with NSCalendarsFullAccessUsageDescription"
provides:
  - "EventKitService.swift — requestFullAccessToEvents() permission request, graceful denial, calendar discovery, event fetching"
  - "LoomCal.entitlements — macOS sandbox entitlement for calendar access"
  - "ContentView updated to show both Convex events and EventKit authorization status"
  - "LoomCalApp.swift updated to create and inject EventKitService as environment object"
  - "convex/schema.ts data ownership rules documented in comments"
  - "Calendar visibility preferences persisted in UserDefaults (selectedAppleCalendarIdentifiers key)"
affects: [03-calendar-ui, 04-ai-chat, 05-notifications]

# Tech tracking
tech-stack:
  added:
    - "EventKit framework — EKEventStore, EKCalendar, EKEvent, EKAuthorizationStatus"
  patterns:
    - "@MainActor class EventKitService: ObservableObject — EventKit service as app-wide singleton via environmentObject"
    - "requestFullAccessToEvents() async/await — iOS 17+/macOS 14+ API, NOT deprecated requestAccess(to:completion:)"
    - "EKAuthorizationStatus switch with .writeOnly and @unknown default — full exhaustiveness for all SDK cases"
    - "UserDefaults storage for calendar visibility — key selectedAppleCalendarIdentifiers, Set<String> of calendarIdentifier"
    - "Graceful denial: authStatus = .denied, no retry, no nag — app continues with Convex-only events"

key-files:
  created:
    - "LoomCal/Services/EventKitService.swift — EventKit permission request, calendar discovery, event fetching, UserDefaults visibility"
    - "LoomCal/LoomCal.entitlements — com.apple.security.app-sandbox + com.apple.security.personal-information.calendars"
  modified:
    - "LoomCal/App/LoomCalApp.swift — added @StateObject EventKitService, inject as .environmentObject"
    - "LoomCal/Views/ContentView.swift — Phase 1 proof-of-concept dashboard showing both Convex events and EventKit status"
    - "convex/schema.ts — data ownership rules comment block documenting all 5 data sources"
    - "LoomCal.xcodeproj/project.pbxproj — added EventKitService.swift to Sources, LoomCal.entitlements to group, CODE_SIGN_ENTITLEMENTS build setting"

key-decisions:
  - "Use app-sandbox entitlement (com.apple.security.app-sandbox = true) alongside calendar entitlement — required for macOS sandboxed apps to request privacy permissions"
  - "EKAuthorizationStatus switch includes .writeOnly case explicitly — avoids 'switch must be exhaustive' warning since .writeOnly is a known case added in iOS 17"
  - "Data ownership rules documented in schema.ts comments — EventKit events are not stored in Convex, always read on-device"

patterns-established:
  - "EventKit service pattern: @MainActor ObservableObject injected via .environmentObject at app root"
  - "Calendar visibility pattern: Set<String> of calendarIdentifiers persisted to UserDefaults, all selected by default on first grant"
  - "EKAuthorizationStatus exhaustive switch: handle .notDetermined, .fullAccess, .denied, .restricted, .writeOnly, @unknown default"

requirements-completed: [PLAT-05]

# Metrics
duration: 4min
completed: 2026-02-20
---

# Phase 1 Plan 03: EventKit Permission Flow and Calendar Infrastructure Summary

**EventKitService with iOS 17+ requestFullAccessToEvents() API, macOS sandbox entitlement, graceful denial handling, UserDefaults calendar visibility, and both data sources wired into ContentView**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-20T10:52:13Z
- **Completed:** 2026-02-20T10:56:08Z
- **Tasks:** 2 of 2
- **Files modified:** 6

## Accomplishments
- EventKitService created with `requestFullAccessToEvents()` (iOS 17+ API) — uses async/await, handles all auth states including MDM restriction
- macOS entitlements file created with calendar access entitlement — prevents silent `.denied` without prompt on macOS sandbox
- ContentView updated to Phase 1 proof-of-concept dashboard showing both Convex subscription events and EventKit status side-by-side
- Calendar visibility preferences stored in UserDefaults — all calendars selected on first grant, toggleable per-calendar

## Task Commits

Each task was committed atomically:

1. **Task 1: Create EventKitService with permission and calendar reading** - `45c2c47` (feat)
2. **Task 2: Wire EventKitService into the app and add data ownership documentation** - `ab89cb1` (feat)

**Plan metadata:** (to be updated after final docs commit)

## Files Created/Modified
- `LoomCal/Services/EventKitService.swift` — EventKit service: permission request, calendar discovery, event fetching, UserDefaults visibility persistence
- `LoomCal/LoomCal.entitlements` — macOS sandbox entitlement for calendar access (com.apple.security.app-sandbox + com.apple.security.personal-information.calendars)
- `LoomCal/App/LoomCalApp.swift` — creates @StateObject EventKitService, injects via .environmentObject into ContentView
- `LoomCal/Views/ContentView.swift` — Phase 1 proof-of-concept: Convex events section + Apple Calendar status section; .task fires requestAccess() on launch
- `convex/schema.ts` — data ownership comment block documenting all 5 data sources and their source-of-truth
- `LoomCal.xcodeproj/project.pbxproj` — EventKitService.swift added to Sources build phase; LoomCal.entitlements added to group and CODE_SIGN_ENTITLEMENTS build setting

## Decisions Made
- Used `com.apple.security.app-sandbox = true` alongside the calendar entitlement — macOS requires app sandbox to be active before privacy entitlements are respected
- Added `.writeOnly` to the EKAuthorizationStatus switch explicitly — it's a known enum case added in iOS 17, avoiding the exhaustiveness warning without relying only on `@unknown default`
- EventKit events are NOT stored in Convex — documented in schema.ts as "read directly from EventKit on-device, always fresh, no sync needed"

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added .writeOnly to EKAuthorizationStatus switch**
- **Found during:** Task 2 (ContentView update)
- **Issue:** Plan's ContentView code used `@unknown default` only, which produced an "switch must be exhaustive" warning because .writeOnly is a known case in the SDK
- **Fix:** Added `.writeOnly` explicitly to the `.denied, .restricted` case arm
- **Files modified:** LoomCal/Views/ContentView.swift
- **Verification:** Build succeeded with no warnings
- **Committed in:** ab89cb1 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 missing critical — exhaustive switch)
**Impact on plan:** Minor correctness fix. No scope creep.

## Issues Encountered
None — both tasks built cleanly on first attempt. EventKit framework is available in both iOS and macOS targets without platform guards.

## User Setup Required
None — no additional configuration required beyond what was established in Plan 01-02. EventKit permission prompt will appear automatically on first launch.

## Next Phase Readiness
- Phase 1 Foundation is complete — Convex schema, Swift client, ConvexMobile integration, and EventKit infrastructure all wired end-to-end
- EventKitService is ready for Phase 3 (calendar UI) — `fetchEvents(from:to:)` returns `[EKEvent]` for any date range
- Calendar visibility preferences system is in place — Phase 3 can expose toggle UI using `toggleCalendar(_:)` and `availableCalendars`
- Data ownership is documented — future phases know exactly which tables to query and which to leave alone

## Self-Check: PASSED

All files verified present:
- LoomCal/Services/EventKitService.swift: FOUND
- LoomCal/LoomCal.entitlements: FOUND
- LoomCal/App/LoomCalApp.swift: FOUND (modified)
- LoomCal/Views/ContentView.swift: FOUND (modified)
- convex/schema.ts: FOUND (modified)
- .planning/phases/01-foundation/01-03-SUMMARY.md: FOUND

All commits verified:
- 45c2c47 feat(01-03): add EventKitService with permission flow and macOS entitlement: FOUND
- ab89cb1 feat(01-03): wire EventKitService into app and document data ownership: FOUND

---
*Phase: 01-foundation*
*Completed: 2026-02-20*
