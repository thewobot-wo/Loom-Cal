---
phase: 08-platform-polish
plan: 02
subsystem: ui, services
tags: [UNUserNotificationCenter, local-notifications, UserDefaults, UNCalendarNotificationTrigger]

requires:
  - phase: 08-platform-polish
    provides: Platform-branched ContentView with toolbar structure
provides:
  - Local notification scheduling for events (configurable lead time)
  - Local notification scheduling for tasks (due time or 9 AM fallback)
  - Foreground notification display via UNUserNotificationCenterDelegate
  - Notification lead time menu in calendar toolbar
affects: []

tech-stack:
  added: [UserNotifications]
  patterns: [NSObject singleton with UNUserNotificationCenterDelegate, foreground banner display]

key-files:
  created: [LoomCal/Services/NotificationService.swift]
  modified: [LoomCal/ViewModels/CalendarViewModel.swift, LoomCal/ViewModels/TaskViewModel.swift, LoomCal/App/LoomCalApp.swift, LoomCal/Views/ContentView.swift]

key-decisions:
  - "NSObject singleton for NotificationService — required for UNUserNotificationCenterDelegate conformance"
  - "Foreground banner display via willPresent delegate — iOS suppresses banners by default when app is active"
  - "Bell icon menu for lead time — minimal UI, no separate settings view"

patterns-established:
  - "Notification rescheduling on every Convex subscription update — simple cancel-all + re-add pattern"
  - "@AppStorage for user preferences synced with service singleton"

duration: ~10min
started: 2026-02-23
completed: 2026-02-23
---

# Phase 8 Plan 02: Local Notifications Summary

**Event and task local notifications via UNUserNotificationCenter with configurable lead time and foreground banner display.**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~10 min |
| Started | 2026-02-23 |
| Completed | 2026-02-23 |
| Tasks | 3 completed (1 checkpoint) |
| Files modified | 5 + 1 new |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-1: Event notifications with configurable lead time | Pass | Schedules for next 48h events at start - leadMinutes |
| AC-2: Task due date notifications | Pass | hasDueTime → exact time; no time → 9 AM |
| AC-3: Lead time user-configurable | Pass | Bell menu with 5/10/15/30/60 min options, @AppStorage backed |
| AC-4: Permission requested on launch | Pass | .task{} on ContentView in LoomCalApp, delegate set early |

## Accomplishments

- Created NotificationService singleton with event + task scheduling, permission handling, and foreground display
- Integrated with CalendarViewModel and TaskViewModel — notifications reschedule automatically on every Convex subscription update
- Added bell icon lead time menu to calendar toolbar on both iOS and macOS
- Human-verified: permission prompt appears, notifications fire correctly

## Files Created/Modified

| File | Change | Purpose |
|------|--------|---------|
| `LoomCal/Services/NotificationService.swift` | Created | Scheduling engine — NSObject + UNUserNotificationCenterDelegate singleton |
| `LoomCal/ViewModels/CalendarViewModel.swift` | Modified | Added rescheduleEventNotifications call in subscription loop |
| `LoomCal/ViewModels/TaskViewModel.swift` | Modified | Added rescheduleTaskNotifications call in subscription loop |
| `LoomCal/App/LoomCalApp.swift` | Modified | Permission request on launch + early singleton init for delegate |
| `LoomCal/Views/ContentView.swift` | Modified | @AppStorage leadMinutes + bell menu in both platform toolbars |
| `LoomCal.xcodeproj/project.pbxproj` | Modified | Added NotificationService.swift to target |

## Decisions Made

| Decision | Rationale | Impact |
|----------|-----------|--------|
| NSObject subclass for singleton | UNUserNotificationCenterDelegate requires NSObjectProtocol | Slightly heavier class, but necessary |
| willPresent delegate for foreground | iOS suppresses notification banners when app is active by default | Notifications visible during active use |
| Cancel-all + re-add on each update | Simple approach, avoids diffing; 48h window stays well under 64-item limit | Slightly more work per update but zero complexity |

## Deviations from Plan

### Auto-fixed Issues

**1. Foreground notification suppression**
- **Found during:** Checkpoint (Task 3)
- **Issue:** iOS does not show notification banners while the app is in the foreground by default
- **Fix:** Changed NotificationService from plain class to NSObject subclass with UNUserNotificationCenterDelegate; added willPresent handler returning [.banner, .sound]
- **Files:** NotificationService.swift, LoomCalApp.swift (early singleton touch)
- **Verification:** Human-verified — notifications now display in foreground

**2. Xcode project membership**
- **Found during:** Task 2 build verification
- **Issue:** New NotificationService.swift not in Xcode target — "cannot find in scope" error
- **Fix:** Added file reference, build file, group membership, and sources entry to project.pbxproj
- **Verification:** Both iOS and macOS builds succeed

**Total impact:** Essential fixes, no scope creep.

## Issues Encountered

None beyond the auto-fixed items above.

## Next Phase Readiness

**Ready:**
- Phase 8 complete — all 4 success criteria satisfied
- Milestone v0.1 complete — all 8 phases done

**Concerns:**
- None

**Blockers:**
- None

---
*Phase: 08-platform-polish, Plan: 02*
*Completed: 2026-02-23*
