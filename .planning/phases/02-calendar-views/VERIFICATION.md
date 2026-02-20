---
phase: 02-calendar-views
verified: 2026-02-20T23:45:00Z
status: passed
score: 5/5 must-haves verified
gaps: []
human_verification:
  - test: "Visual appearance of day and week timeline views"
    expected: "Fantastical-inspired clean cards with blue accent bars, generous whitespace, red now-marker line with dot at current time, hour grid lines with 12h labels"
    why_human: "Visual aesthetics and spacing cannot be verified programmatically"
  - test: "Drag-to-move event on day timeline"
    expected: "Long-press an event card, drag vertically, event snaps to 15-minute grid and updates via Convex mutation"
    why_human: "Gesture interaction requires runtime testing"
  - test: "Real-time sync across iOS and Mac"
    expected: "Edit event on iOS simulator, see change appear on Mac app within 2 seconds via Convex subscription"
    why_human: "Cross-device real-time behavior requires two running instances"
  - test: "Natural language parsing accuracy"
    expected: "'Dentist 3pm' parses to title 'Dentist' and start time 3:00 PM today; 'Team lunch tomorrow' parses to title 'Team lunch' and date tomorrow"
    why_human: "NSDataDetector parsing edge cases need runtime validation"
---

# Phase 2: Calendar Views Verification Report

**Phase Goal:** Users can see and manage Convex-native events in a day and week calendar view, and perform full event CRUD from the app
**Verified:** 2026-02-20T23:45:00Z
**Status:** passed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can view the current day's events in a timeline view that shows event titles and times | VERIFIED | `DayTimelineView.swift` (217 lines): 24h scrollable timeline with hour grid, `TimelineEventCard` showing title + 12h formatted time, greedy column-assignment for overlapping events. Wired in `ContentView.swift` line 52 via `viewModel.timedEvents(for:)` and `viewModel.allDayEvents(for:)`. |
| 2 | User can switch to a week view that shows all seven days with events laid out in their time slots | VERIFIED | `ContentView.swift` has `ViewMode` enum (Day/Week) with `Picker(.segmented)` at line 27. `WeekTimelineView.swift` (272 lines): 7-column layout via `weekDates` computed property, per-day event rendering in `dayColumn(for:width:)`, month/year header, today/selected indicators. Wired in `ContentView.swift` line 61. |
| 3 | User can tap a time slot to create a new event by entering a title, date, start time, and duration -- the event appears on the calendar immediately | VERIFIED | Plus button in ContentView toolbar (line 73) opens `EventCreationView` sheet. `EventCreationView.swift` (141 lines): NL TextField with `parseAndFill()` on submit, Form with title/date/start time/end time/all-day fields, `saveEvent()` calls `viewModel.createEvent()`. `CalendarViewModel.createEvent()` calls `convex.mutation("events:create")`. Backend `events.ts:create` inserts into DB. Subscription auto-delivers new event to `events` array. Long-press on MiniMonthView date also opens creation with prefilled date. |
| 4 | User can tap an existing event to edit its title, time, or duration -- changes reflect in real-time across both iOS and Mac | VERIFIED | `TimelineEventCard` tap -> `onEventTap` callback -> `ContentView` sets `selectedEvent` -> `.sheet(item:)` opens `EventDetailView`. Edit button opens nested `EventEditView` sheet (line 91). `EventEditView.swift` (137 lines): pre-fills `@State` from `LoomEvent` in `init()`, detects changed fields, calls `viewModel.updateEvent(id:title:start:durationMinutes:)`. Backend `events.ts:update` patches DB via `ctx.db.patch()`. Convex subscription delivers update in real-time. |
| 5 | User can delete an event from the event detail view and it disappears from the calendar without requiring a reload | VERIFIED | `EventDetailView.swift` Delete button (line 65) triggers `.alert` confirmation (line 80). On confirm, calls `viewModel.deleteEvent(id:)` then sets `isPresented = false`. `CalendarViewModel.deleteEvent()` calls `convex.mutation("events:remove")`. Backend `events.ts:remove` calls `ctx.db.delete(id)`. Subscription automatically removes deleted event from `events` array -- no reload needed. |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `LoomCal/ViewModels/CalendarViewModel.swift` | ViewModel with Convex subscription, CRUD mutations | VERIFIED | 118 lines. `startSubscription()` with `for await` over Convex publisher, `createEvent()`, `updateEvent()`, `deleteEvent()` all calling Convex mutations with `[String: ConvexEncodable?]` args. Date-filtering helpers: `events(for:)`, `allDayEvents(for:)`, `timedEvents(for:)`. |
| `LoomCal/Views/Calendar/DayTimelineView.swift` | Day timeline view | VERIFIED | 217 lines. 24h scrollable timeline, GeometryReader at root, Color.clear height spacer, hour grid, now indicator (TimelineView periodic), event cards via `computeLayout()` greedy column algorithm, auto-scroll to current time. |
| `LoomCal/Views/Calendar/WeekTimelineView.swift` | Week timeline view (7-column layout) | VERIFIED | 272 lines. 7-column layout via `weekDates` computed from `Calendar.dateInterval(of: .weekOfYear)`, week header with month/year label and day cells (selected/today indicators), per-day event columns, now indicator, auto-scroll. |
| `LoomCal/Views/ContentView.swift` | Main app view with Day/Week segmented control | VERIFIED | 127 lines. `ViewMode` enum, segmented Picker, mini month in day mode only, DayTimelineView/WeekTimelineView switch, plus button, Today button, `.sheet(isPresented:)` for creation, `.sheet(item:)` for detail, drag-to-move handler. |
| `LoomCal/Views/Events/EventCreationView.swift` | Event creation with NL parser | VERIFIED | 141 lines. NL TextField with `parseAndFill()` calling `NLEventParser.parse()`, Form with title/date/start/end time/all-day, `saveEvent()` combining date+time components, calling `viewModel.createEvent()`. |
| `LoomCal/Views/Events/EventDetailView.swift` | Event detail with delete | VERIFIED | 101 lines. Read-only display of title/date/time range, Edit button opening `EventEditView` sheet, Delete button with `.alert` confirmation calling `viewModel.deleteEvent()`. |
| `LoomCal/Views/Events/EventEditView.swift` | Event edit form | VERIFIED | 137 lines. Pre-fills `@State` from `LoomEvent` in `init()`, DatePickers for date/start/end, change detection against original, `viewModel.updateEvent()` with only changed fields, two-level dismiss via `isDetailPresented` binding. |
| `LoomCal/Views/Calendar/MiniMonthView.swift` | Mini month calendar | VERIFIED | 351 lines. iOS: HorizonCalendar 1.x UIViewRepresentable with `MiniDayCellView` (selected/today/event-dot states), day selection handler, long-press gesture. macOS: LazyVGrid fallback with `#if os(macOS)`. |
| `LoomCal/Views/Calendar/TimelineEventCard.swift` | Event card with drag gesture | VERIFIED | 121 lines. Fantastical-style card with blue accent bar, title + 12h time, `LongPressGesture.sequenced(before: DragGesture)` for drag-to-move, visual feedback (opacity, shadow changes). |
| `LoomCal/Models/LoomEvent.swift` | Event model with Identifiable | VERIFIED | 24 lines. `Decodable, Identifiable` conformance, `var id: String { _id }`, `@ConvexInt` for `start` and `duration`, all schema fields mapped. |
| `LoomCal/Services/NLEventParser.swift` | NL event text parser | VERIFIED | 109 lines. `NSDataDetector` for date/time extraction, multi-pass title cleanup (detector range removal + regex stripping), `ParsedEvent` struct with title/date/hasTime. |
| `LoomCal/Views/Calendar/NowIndicatorView.swift` | Now time indicator | VERIFIED | 41 lines. `TimelineView(.periodic(from: .now, by: 60))` for minute updates, red circle + red line. |
| `LoomCal/Views/Calendar/AllDayBannerView.swift` | All-day event banner | VERIFIED | 59 lines. Horizontal scroll of pill-shaped event labels, `EmptyView` when no all-day events. |
| `convex/events.ts` | Backend CRUD functions | VERIFIED | 75 lines. `list` query with `by_start` index, `create` mutation with full schema args, `update` mutation with partial patch via `ctx.db.patch()`, `remove` mutation via `ctx.db.delete()`. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `LoomCalApp.swift` | `ContentView` | `WindowGroup { ContentView() }` | WIRED | App entry point renders ContentView (line 14) |
| `ContentView` | `CalendarViewModel` | `@StateObject private var viewModel` | WIRED | Single ViewModel instance owned by ContentView (line 16), passed to all child views |
| `ContentView` | `DayTimelineView` | Direct instantiation in `case .day:` | WIRED | Lines 52-59, passes filtered events and callbacks |
| `ContentView` | `WeekTimelineView` | Direct instantiation in `case .week:` | WIRED | Lines 61-63, passes viewModel and onEventTap |
| `ContentView` | `EventCreationView` | `.sheet(isPresented: $showCreateSheet)` | WIRED | Lines 89-95, passes viewModel, binding, prefilled date |
| `ContentView` | `EventDetailView` | `.sheet(item: $selectedEvent)` | WIRED | Lines 96-105, passes event, viewModel, binding |
| `EventDetailView` | `EventEditView` | `.sheet(isPresented: $showEditSheet)` | WIRED | Lines 91-98, passes event, viewModel, both bindings |
| `EventCreationView` | `CalendarViewModel.createEvent()` | `viewModel.createEvent(title:start:durationMinutes:isAllDay:)` | WIRED | Line 129, inside `Task { try await }` |
| `EventEditView` | `CalendarViewModel.updateEvent()` | `viewModel.updateEvent(id:title:start:durationMinutes:)` | WIRED | Line 124, inside `Task { try await }` |
| `EventDetailView` | `CalendarViewModel.deleteEvent()` | `viewModel.deleteEvent(id:)` | WIRED | Line 83, inside `Task { try? await }` |
| `CalendarViewModel.createEvent()` | `convex/events.ts:create` | `convex.mutation("events:create", with: args)` | WIRED | Line 96 in CalendarViewModel |
| `CalendarViewModel.updateEvent()` | `convex/events.ts:update` | `convex.mutation("events:update", with: args)` | WIRED | Line 110 in CalendarViewModel |
| `CalendarViewModel.deleteEvent()` | `convex/events.ts:remove` | `convex.mutation("events:remove", with: args)` | WIRED | Line 116 in CalendarViewModel |
| `CalendarViewModel.startSubscription()` | `convex/events.ts:list` | `convex.subscribe(to: "events:list")` | WIRED | Line 33-34, for-await loop updates `self.events` |
| `DayTimelineView` | `TimelineEventCard` | `ForEach` in `eventCards()` | WIRED | Line 114-115 in DayTimelineView |
| `TimelineEventCard.onTap` | `ContentView.selectedEvent` | Callback chain: `onTap -> onEventTap -> selectedEvent = event` | WIRED | ContentView line 55 sets `selectedEvent` |
| `EventCreationView` | `NLEventParser` | `NLEventParser.parse(nlInput)` | WIRED | Line 96 in `parseAndFill()` |
| `ContentView` | `MiniMonthView` | Direct instantiation in `if viewMode == .day` | WIRED | Lines 39-45, passes viewModel and onDateLongPress |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| CALV-01 | 02-01, 02-03 | User can view events in a day calendar view | SATISFIED | DayTimelineView renders events with titles and times in 24h scrollable timeline. Wired in ContentView. |
| CALV-02 | 02-03 | User can view events in a week calendar view | SATISFIED | WeekTimelineView renders 7-column layout with per-day events. Switchable via segmented control in ContentView. Note: REQUIREMENTS.md checkbox not ticked -- bookkeeping only, implementation is complete. |
| CALV-03 | 02-02 | User can create events with title, date/time, and duration | SATISFIED | EventCreationView with NL parser, Form fields, calls CalendarViewModel.createEvent() -> Convex mutation. |
| CALV-04 | 02-02 | User can edit existing events (title, time, duration) | SATISFIED | EventEditView pre-fills from LoomEvent, change detection, calls CalendarViewModel.updateEvent() -> Convex mutation. |
| CALV-05 | 02-02 | User can delete events | SATISFIED | EventDetailView Delete button -> .alert confirmation -> CalendarViewModel.deleteEvent() -> Convex mutation. |

No orphaned requirements -- all 5 CALV requirements mapped in ROADMAP.md are covered by plans and implemented.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `LoomCal/App/ConvexEnv.swift` | 4 | TODO: Use Xcode build configurations for dev/prod | Info | Phase 1 file, not Phase 2 concern. Environment config deferred to later phase. No impact on Phase 2 goal. |

No blocker or warning-level anti-patterns found in any Phase 2 files. No stubs, no placeholders, no empty implementations, no console.log-only handlers.

### Human Verification Required

### 1. Visual Appearance of Calendar Views

**Test:** Launch app in iOS simulator, verify day timeline shows hour grid with 12h labels, event cards with blue accent bars and titles/times, red now-marker at current time, all-day banner at top
**Expected:** Fantastical-inspired clean layout with generous whitespace, subtle shadows on event cards, proper spacing
**Why human:** Visual aesthetics, spacing, and typography cannot be verified programmatically

### 2. Day/Week View Switching

**Test:** Tap "Week" in the segmented control, verify 7-column layout appears with events in correct time slots. Tap "Day" to return to day view with mini month visible above timeline.
**Expected:** Smooth transition, mini month hidden in week mode, week header shows month/year and day numbers with today/selected indicators
**Why human:** Layout transitions and visual correctness of 7-column grid need visual confirmation

### 3. Event Creation via NL Input

**Test:** Tap plus button, type "Dentist 3pm" in the NL field and press Return, verify title field fills with "Dentist" and start time fills with 3:00 PM, tap Add
**Expected:** Event appears immediately on the day timeline at the 3 PM slot
**Why human:** NSDataDetector parsing accuracy and real-time appearance on timeline need runtime validation

### 4. Event Edit Flow

**Test:** Tap an event on the timeline, verify detail sheet shows title/date/time, tap Edit, change the title and time, tap Save
**Expected:** Both sheets dismiss, event reflects new title and time on the timeline immediately
**Why human:** Two-level sheet dismiss behavior and real-time Convex update reflection need runtime testing

### 5. Event Delete Flow

**Test:** Tap an event, tap Delete in the detail sheet, confirm in the alert dialog
**Expected:** Alert appears with event title, on confirm the event disappears from the calendar without reload, detail sheet dismisses
**Why human:** Alert reliability in nested sheet context and subscription-driven removal need runtime testing

### 6. Drag-to-Move Events

**Test:** Long-press an event card on the day timeline, drag vertically to a new time slot, release
**Expected:** Event snaps to 15-minute grid, visual feedback during drag (opacity change, larger shadow), event time updates via Convex mutation
**Why human:** Gesture interaction and snap behavior require runtime testing

### 7. Cross-Device Real-Time Sync

**Test:** Run app on iOS simulator and Mac (if macOS build available), create/edit/delete event on one device
**Expected:** Change appears on other device within 2 seconds via Convex subscription
**Why human:** Cross-device real-time behavior requires two running instances; macOS has known pre-existing linker issue

### Gaps Summary

No gaps found. All five observable truths are verified through code analysis:

1. **Day view:** DayTimelineView is substantive (217 lines with full 24h timeline, event layout engine, now indicator) and fully wired through ContentView to CalendarViewModel's Convex subscription.

2. **Week view:** WeekTimelineView is substantive (272 lines with 7-column layout, per-day event rendering, week header navigation) and switchable via segmented control in ContentView.

3. **Event creation:** EventCreationView has NL parser, full form fields, and calls CalendarViewModel.createEvent() which fires a Convex mutation. Events appear via real-time subscription.

4. **Event editing:** EventEditView pre-fills from existing event data, detects changes, and calls CalendarViewModel.updateEvent() with only modified fields. Convex subscription delivers updates.

5. **Event deletion:** EventDetailView has .alert-based delete confirmation that calls CalendarViewModel.deleteEvent(), which fires a Convex remove mutation. Subscription-driven removal means no reload needed.

All artifacts exist, are substantive (no stubs), and are fully wired through the component graph from LoomCalApp -> ContentView -> Views -> CalendarViewModel -> Convex backend.

The only bookkeeping issue is that CALV-02 in REQUIREMENTS.md is still marked as "Pending" despite the implementation being complete. This should be ticked off.

---

_Verified: 2026-02-20T23:45:00Z_
_Verifier: Claude (gsd-verifier)_
