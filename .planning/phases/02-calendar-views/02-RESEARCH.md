# Phase 2: Calendar Views - Research

**Researched:** 2026-02-20
**Domain:** SwiftUI calendar UI, Convex CRUD mutations, natural language date parsing
**Confidence:** MEDIUM-HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Timeline layout**
- Fantastical-inspired style: clean, generous whitespace, events as rounded cards with subtle shadows
- Events show title + time only — details on tap
- Red horizontal line with dot for current-time indicator (classic Apple Calendar now-marker)
- Auto-scroll to current time when opening the view
- All-day events displayed as banner at the top of the timeline, above the time grid
- Hour labels always 12-hour format (2 PM, 3:30 PM)

**Default view & navigation**
- Default view on app open: mini month calendar on top + today's day timeline below (Fantastical-style layout)
- Mini month always visible at top — tap any date to jump to that day's timeline
- Segmented control (Day | Week) in the header for switching between day and week views
- Swipe left/right on timeline navigates between days (or weeks in week view)

**Event creation flow**
- Plus button opens event creation view
- Long-press on a date in the mini month opens creation view with that date pre-filled
- Creation view: text field for natural language input at top + expandable details card below for manual input
- Basic local parsing (regex/DateFormatter) — "Dentist 3pm" extracts title + time. No AI/Loom required.
- Default event duration: 1 hour

**Event editing & deletion**
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

### Deferred Ideas (OUT OF SCOPE)
- Full Loom-powered natural language parsing — Phase 7
- Event color coding by calendar — future phase
- Recurring events — not in Phase 2 scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CALV-01 | User can view events in a day calendar view | Custom SwiftUI day timeline with ScrollView + absolute positioning; events from Convex `events:list` subscription |
| CALV-02 | User can view events in a week calendar view | Custom SwiftUI week view with 7-column layout; same event subscription, filtered per column |
| CALV-03 | User can create events with title, date/time, and duration | Event creation sheet with NL input + manual fields; `events:create` Convex mutation with `v.int64()` for start/duration |
| CALV-04 | User can edit existing events (title, time, duration) | Event detail sheet with edit mode; `events:update` Convex mutation with partial args; drag-to-move via DragGesture |
| CALV-05 | User can delete events | `confirmationDialog` on delete tap; `events:remove` Convex mutation; Convex subscription auto-removes from UI |
</phase_requirements>

---

## Summary

Phase 2 builds the full calendar UI layer on top of the Convex backend established in Phase 1. The core challenge is implementing two things that no single existing library handles well together: (1) a mini month calendar for date navigation, and (2) a scrollable hourly timeline for day and week views — all in a Fantastical-inspired visual style.

No existing third-party SwiftUI library covers the full feature set at the right iOS version target (18.0). KVKCalendar (UIKit-based) covers day/week timeline with drag support and works on iOS 13+, but requires a UIViewRepresentable wrapper and the delegate pattern introduces friction with SwiftUI state. The pragmatic choice is to build a **custom SwiftUI timeline** using ScrollView + absolute positioning for event cards, while using HorizonCalendar for the mini month (which is exactly what it excels at). The Convex backend already has all three mutations (`events:create`, `events:update`, `events:remove`) and the `by_start` index ready to use.

The CRUD operations are straightforward — Convex mutations with dictionary args. The key gotcha is that `Int64`-mapped fields (`start`, `duration`) use `@ConvexInt` on the Swift model side for subscriptions, but when calling mutations from Swift, they should be passed as regular Swift `Int` values (the SDK handles the BigInt encoding). Natural language parsing for the creation form uses `NSDataDetector` which handles "3pm", "tomorrow 2:30pm" natively without any third-party library.

**Primary recommendation:** Build a custom SwiftUI timeline (ScrollView + ZStack layout) rather than adopting KVKCalendar. Use HorizonCalendar for the mini month picker. The Convex CRUD layer is already complete from Phase 1 — Phase 2 is primarily UI work.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 18.0 SDK | All UI — timeline, sheets, gestures | Native; project target is iOS 18 |
| HorizonCalendar | 1.x (latest) | Mini month calendar at top of screen | Airbnb's month/date picker; well-maintained; perfect fit for mini month only |
| ConvexMobile | 0.8.0 (confirmed) | Subscribe to events, call CRUD mutations | Already integrated in Phase 1 |
| Foundation (NSDataDetector) | System | NL date/time extraction from text input | Apple-native; no dependency; handles "3pm", "tomorrow 9am" well |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| KVKCalendar | 0.6.30 | Full-featured day/week timeline (UIKit) | Use ONLY if custom SwiftUI timeline proves too complex; requires UIViewRepresentable wrapper |
| DateFormatter / Calendar API | System | 12-hour formatting, day/week date math | All time label rendering and date navigation |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom SwiftUI timeline | KVKCalendar (UIKit) | KVKCalendar has drag built in, but adds UIKit wrapper friction, obscures state flow, and the delegate pattern fights SwiftUI reactivity |
| HorizonCalendar (mini month) | SwiftUI GraphicalDatePickerStyle | HorizonCalendar is more compact and customizable; GraphicalDatePickerStyle is too large for a persistent mini panel |
| NSDataDetector | SwiftyChrono or SoulverDateFromString | NSDataDetector is zero dependency and handles the required patterns ("Dentist 3pm"); external libraries for Phase 7 |

**Installation:**
```bash
# In Xcode: File > Add Package Dependencies
# HorizonCalendar
https://github.com/airbnb/HorizonCalendar.git  # from: "1.0.0"

# ConvexMobile already added in Phase 1
```

---

## Architecture Patterns

### Recommended Project Structure

```
LoomCal/
├── Models/
│   └── LoomEvent.swift          # Exists from Phase 1 — no changes needed
├── Services/
│   └── NLEventParser.swift      # NEW: NSDataDetector wrapper for NL parsing
├── ViewModels/
│   └── CalendarViewModel.swift  # NEW: @MainActor ObservableObject; owns Convex subscription + CRUD
├── Views/
│   ├── ContentView.swift        # REPLACE: Fantastical layout (mini month + timeline)
│   ├── Calendar/
│   │   ├── MiniMonthView.swift       # NEW: HorizonCalendar wrapper
│   │   ├── DayTimelineView.swift     # NEW: scrollable hourly day view
│   │   ├── WeekTimelineView.swift    # NEW: 7-column week view
│   │   ├── TimelineEventCard.swift   # NEW: event card (rounded, shadow)
│   │   ├── NowIndicatorView.swift    # NEW: red line + dot
│   │   └── AllDayBannerView.swift    # NEW: all-day events strip
│   └── Events/
│       ├── EventCreationView.swift   # NEW: NL field + detail card
│       ├── EventDetailView.swift     # NEW: tap-to-open sheet
│       └── EventEditView.swift       # NEW: edit form
```

### Pattern 1: Custom SwiftUI Timeline Layout

**What:** A `ScrollView` containing a fixed-height `ZStack` (24 hours * pointsPerHour). Hour grid lines are drawn first, then event cards are positioned with `.offset(y:)` based on their start time. Events visible width is calculated after collision detection.

**When to use:** Day view and each column in week view.

**Example:**
```swift
// Source: Custom implementation based on iOS Calendar app conventions
struct DayTimelineView: View {
    let events: [LoomEvent]
    let pointsPerHour: CGFloat = 60.0  // 60 pt per hour = 1 pt per minute
    private var totalHeight: CGFloat { 24 * pointsPerHour }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ZStack(alignment: .topLeading) {
                    // Hour grid
                    ForEach(0..<24, id: \.self) { hour in
                        HourRowView(hour: hour)
                            .offset(y: CGFloat(hour) * pointsPerHour)
                    }

                    // Now indicator
                    NowIndicatorView()
                        .offset(y: yOffset(for: Date()))

                    // Event cards (positioned absolutely)
                    ForEach(events, id: \._id) { event in
                        TimelineEventCard(event: event)
                            .frame(height: cardHeight(for: event))
                            .offset(y: yOffset(for: event.startDate))
                    }
                }
                .frame(height: totalHeight)
                .id("timeline")
            }
            .onAppear {
                // Auto-scroll to current time
                proxy.scrollTo("timeline", anchor: UnitPoint(x: 0, y: currentTimeAnchor()))
            }
        }
    }

    private func yOffset(for date: Date) -> CGFloat {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return CGFloat(components.hour! * 60 + components.minute!) / 60 * pointsPerHour
    }
}
```

### Pattern 2: CalendarViewModel — Centralized State

**What:** A single `@MainActor ObservableObject` that owns the Convex subscription, the selected date, and all mutation methods. Views observe it via `@ObservedObject`.

**When to use:** All calendar views share this single source of truth.

**Example:**
```swift
// Source: Convex Swift docs pattern + Phase 1 established patterns
@MainActor
class CalendarViewModel: ObservableObject {
    @Published var events: [LoomEvent] = []
    @Published var selectedDate: Date = .now

    private var subscriptionTask: Task<Void, Never>?

    func startSubscription() {
        subscriptionTask = Task {
            for await result: [LoomEvent] in convex
                .subscribe(to: "events:list")
                .replaceError(with: [])
                .values
            {
                self.events = result
            }
        }
    }

    func createEvent(title: String, start: Date, durationMinutes: Int) async throws {
        let startMs = Int(start.timeIntervalSince1970 * 1000)
        try await convex.mutation("events:create", with: [
            "calendarId": "personal",
            "title": title,
            "start": startMs,         // Swift Int — SDK encodes as BigInt
            "duration": durationMinutes,
            "timezone": TimeZone.current.identifier,
            "isAllDay": false
        ])
    }

    func updateEvent(id: String, title: String?, start: Date?, durationMinutes: Int?) async throws {
        var args: [String: Any] = ["id": id]
        if let title { args["title"] = title }
        if let start { args["start"] = Int(start.timeIntervalSince1970 * 1000) }
        if let d = durationMinutes { args["duration"] = d }
        try await convex.mutation("events:update", with: args)
    }

    func deleteEvent(id: String) async throws {
        try await convex.mutation("events:remove", with: ["id": id])
    }

    // Filter for a given day — client-side since full subscription is active
    func events(for date: Date) -> [LoomEvent] {
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        return events.filter { event in
            let ms = TimeInterval(event.start) / 1000
            let d = Date(timeIntervalSince1970: ms)
            return d >= start && d < end
        }
    }
}
```

### Pattern 3: Convex events:list — Subscription Strategy

**What:** Subscribe to `events:list` (fetches all events ordered by start) and filter client-side for the visible date range. This is simpler than adding parameterized queries, and for a single user's calendar the dataset will be small.

**When to use:** Phase 2 — a single user, expected <1000 events. If performance degrades, add a `events:listByRange` query with `by_start` index range in a later phase.

**Convex index range query (for future reference):**
```typescript
// Source: https://docs.convex.dev/database/reading-data/indexes/
export const listByRange = query({
  args: { startMs: v.int64(), endMs: v.int64() },
  handler: async (ctx, { startMs, endMs }) => {
    return await ctx.db
      .query("events")
      .withIndex("by_start", (q) =>
        q.gte("start", startMs).lt("start", endMs)
      )
      .collect();
  },
});
```

### Pattern 4: Mini Month with HorizonCalendar

**What:** Embed `CalendarViewRepresentable` (HorizonCalendar's SwiftUI view) in a compact panel at the top. Bind `.onDaySelection` to update `CalendarViewModel.selectedDate`.

**When to use:** Always visible at top of screen.

**Example:**
```swift
// Source: https://github.com/airbnb/HorizonCalendar
import HorizonCalendar

struct MiniMonthView: View {
    @ObservedObject var viewModel: CalendarViewModel

    var body: some View {
        CalendarViewRepresentable(
            calendar: Calendar.current,
            visibleDateRange: monthRange(),
            monthsLayout: .horizontal(options: .init()),
            dataDependency: viewModel.selectedDate
        )
        .onDaySelection { day in
            viewModel.selectedDate = day.components.date(in: .current)!
        }
        .frame(height: 280)
    }
}
```

### Pattern 5: Natural Language Parsing

**What:** Use `NSDataDetector` to extract dates and times from a text field. Fall back to current date + next round hour if detection fails.

**Example:**
```swift
// Source: https://nshipster.com/nsdatadetector/
// Source: Apple Developer Documentation — NSDataDetector
struct NLEventParser {
    static func parse(_ input: String) -> (title: String, date: Date?, time: Date?) {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        var detectedDate: Date?

        detector?.enumerateMatches(in: input, options: [], range: range) { match, _, _ in
            if match?.resultType == .date {
                detectedDate = match?.date
            }
        }

        // Strip detected time references from title (basic regex)
        let titleCleaned = input
            .replacingOccurrences(of: #"\b\d{1,2}(:\d{2})?\s*(am|pm)\b"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        return (title: titleCleaned.isEmpty ? input : titleCleaned, date: detectedDate, time: detectedDate)
    }
}
```

### Pattern 6: Drag-to-Move on Timeline

**What:** Attach `DragGesture` to each event card. Calculate new start time from drag offset relative to timeline's points-per-minute scale. On `onEnded`, call `viewModel.updateEvent()`.

**Key formula:**
```swift
// offset in points -> minutes delta -> new start
let minutesDelta = Int(dragOffset.height / (pointsPerHour / 60))
let newStart = Calendar.current.date(byAdding: .minute, value: minutesDelta, to: event.startDate)!
```

**Snapping:** Round `newStart` to nearest 15-minute boundary to feel natural.

### Anti-Patterns to Avoid

- **Subscribing inside a View body:** Subscribe in `CalendarViewModel.startSubscription()` — not inside a view's `.task {}` block — to avoid re-subscribing on view re-renders.
- **Converting Int to Date in the model:** Keep `LoomEvent.start` as `Int` (ms). Convert to `Date` only at the display layer using `Date(timeIntervalSince1970: TimeInterval(event.start) / 1000)`.
- **Passing a `Binding<Date>` directly to HorizonCalendar:** HorizonCalendar uses its own day selection callback — bridge to `CalendarViewModel.selectedDate` in the closure.
- **Using a full `DatePicker` sheet for event creation time:** Use `DatePicker` inline in the details card, `.datePickerStyle(.compact)`, which is compact and native-looking.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Mini month calendar grid | Custom month grid in SwiftUI | HorizonCalendar | Handles month boundaries, locale, first-weekday-of-week, selection highlighting correctly |
| NL date extraction from text | Manual regex | NSDataDetector | Handles "tomorrow", "next Tuesday", "3pm PST", duration — Apple's battle-tested NLP engine |
| Convex event CRUD | Custom HTTP layer | `convex.mutation()` SDK calls | Already established in Phase 1; mutations exist in `convex/events.ts` |
| Confirmation dialog | Custom alert view | SwiftUI `.confirmationDialog()` | Native; slides from bottom on iOS; correct destructive button styling automatically |
| 12-hour time formatting | Manual string interpolation | `DateFormatter` with `"h:mm a"` format | Locale-aware, handles edge cases (midnight, noon) |

**Key insight:** The calendar UI itself cannot be replaced by a third-party library at this project's iOS target and design fidelity requirement — the custom timeline is necessary work.

---

## Common Pitfalls

### Pitfall 1: Int64 / @ConvexInt Mutation Argument

**What goes wrong:** Passing `Int64` or `Date.timeIntervalSince1970` (a `Double`) directly into a mutation `with:` dictionary causes a type encoding error or silent data corruption.
**Why it happens:** Convex `v.int64()` fields require BigInt on the wire; the ConvexMobile SDK handles this for `Int` natively but not for other numeric types.
**How to avoid:** Convert `Date` to milliseconds as Swift `Int`: `Int(date.timeIntervalSince1970 * 1000)`. Pass plain `Int` — the SDK encodes it correctly as BigInt for `v.int64()` backend fields. Verified in Phase 1 notes.
**Warning signs:** "Invalid argument type" error from Convex, or events storing `0` as start time.

### Pitfall 2: HorizonCalendar Mac Catalyst Behavior (Unverified)

**What goes wrong:** HorizonCalendar has unverified Mac Catalyst behavior — noted as a blocker in STATE.md from Phase 1.
**Why it happens:** The library is UIKit-based; Mac Catalyst renders it but scroll/interaction behavior may differ.
**How to avoid:** Test HorizonCalendar on Mac target early. If it breaks, replace with a custom SwiftUI month grid (~1-2 days work for a simple version). The mini month does not need all HorizonCalendar's features — a basic `LazyVGrid` grid of day numbers with tap gesture is a viable fallback.
**Warning signs:** Crash on Mac target, missing tap events, incorrect rendering.

### Pitfall 3: ScrollView Auto-Scroll to Current Time

**What goes wrong:** Calling `scrollTo` in `onAppear` before the ScrollView has laid out its content results in no scroll or incorrect position.
**Why it happens:** SwiftUI layout is asynchronous; `onAppear` fires before the frame is fully calculated.
**How to avoid:** Use `ScrollViewReader` with `.scrollTo(id:anchor:)` inside a `.task {}` with a short delay (`try? await Task.sleep(nanoseconds: 100_000_000)`) or use the `scrollPosition` binding (iOS 18) with an initial value.
**Warning signs:** App opens and timeline shows midnight (top) instead of current hour.

### Pitfall 4: Now Indicator Accuracy

**What goes wrong:** The red now-indicator is drawn once on appear and never moves.
**Why it happens:** The offset is computed from `Date()` at view creation time.
**How to avoid:** Use SwiftUI's `TimelineView(.periodic(from: .now, by: 60))` to wrap the now-indicator, updating it every minute.
**Warning signs:** Indicator stays fixed after 1+ minutes.

### Pitfall 5: Convex Subscription Memory Leak

**What goes wrong:** Multiple subscription tasks accumulate if `CalendarViewModel.startSubscription()` is called multiple times.
**Why it happens:** SwiftUI may re-create or re-call view lifecycle methods.
**How to avoid:** Store the `Task` handle in `subscriptionTask` and cancel before re-subscribing. Cancel in `deinit` or when no longer needed.

### Pitfall 6: Overlapping Events Layout Complexity

**What goes wrong:** Naively laying out overlapping events with full width produces unreadable stacked cards.
**Why it happens:** ZStack with same width and overlapping y positions obscures cards behind others.
**How to avoid:** Implement a collision detection pass: group events that overlap, assign column indices within the group, divide width by column count. This is ~50 lines of straightforward Swift (sort by start, greedy column assignment). Claude's Discretion allows stacking if side-by-side is too complex.
**Warning signs:** Events with same time slot appear as one card, or earlier event is completely hidden.

### Pitfall 7: NSDataDetector Title Cleanup

**What goes wrong:** After extracting the date, the title still contains "3pm" or "tomorrow" verbatim.
**Why it happens:** `NSDataDetector` extracts the date but doesn't strip the matched portion from the string.
**How to avoid:** Get the `match.range` from the detector and remove that range from the original string to produce a clean title. Fall back to the full input as title if cleanup fails.
**Warning signs:** Event titled "Dentist appointment 3pm" instead of "Dentist appointment".

---

## Code Examples

### Convex: events:list with range filter (TypeScript backend)

```typescript
// Source: https://docs.convex.dev/database/reading-data/indexes/
// convex/events.ts — add this query for future optimization
export const listByRange = query({
  args: { startMs: v.int64(), endMs: v.int64() },
  handler: async (ctx, { startMs, endMs }) => {
    return await ctx.db
      .query("events")
      .withIndex("by_start", (q) =>
        q.gte("start", startMs).lt("start", endMs)
      )
      .collect();
  },
});
```

### SwiftUI: confirmationDialog for delete

```swift
// Source: Apple Developer Documentation — confirmationDialog
.confirmationDialog("Delete Event?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
    Button("Delete", role: .destructive) {
        Task { try? await viewModel.deleteEvent(id: event._id) }
    }
    Button("Cancel", role: .cancel) {}
} message: {
    Text(""\(event.title)" will be permanently deleted.")
}
```

### SwiftUI: scrollPosition for auto-scroll (iOS 18)

```swift
// Source: https://developer.apple.com/documentation/swiftui/scrollposition
// iOS 18 native API — matches project's deployment target
@State private var position = ScrollPosition(y: 0)

ScrollView {
    // timeline content
}
.scrollPosition($position)
.onAppear {
    position = ScrollPosition(y: currentTimeYOffset())
}
```

### NSDataDetector: extract date from string

```swift
// Source: Apple Developer Documentation — NSDataDetector
// Source: https://nshipster.com/nsdatadetector/
func detectDate(in text: String) -> Date? {
    guard let detector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.date.rawValue
    ) else { return nil }

    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    var result: Date?
    detector.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
        if result == nil { result = match?.date }
    }
    return result
}
```

### HorizonCalendar: SwiftUI setup (CalendarViewRepresentable)

```swift
// Source: https://github.com/airbnb/HorizonCalendar
import HorizonCalendar

CalendarViewRepresentable(
    calendar: Calendar.current,
    visibleDateRange: Date()...Calendar.current.date(byAdding: .month, value: 3, to: Date())!,
    monthsLayout: .vertical(options: .init(pinDaysOfWeekToTop: true)),
    dataDependency: selectedDate
)
.days { [self] day in
    let date = calendar.date(from: day.components)!
    let hasEvents = !events(for: date).isEmpty
    DayView(day: day, isSelected: day == selectedDay, hasEvents: hasEvents)
}
.onDaySelection { day in
    selectedDay = day
    selectedDate = calendar.date(from: day.components)!
}
.frame(height: 260)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `ScrollViewReader` + `scrollTo(id:)` | `scrollPosition` binding (iOS 18) | iOS 18 / WWDC 2024 | Cleaner, supports offset-based scrolling without IDs |
| `@ObservedObject` with class ViewModel | `@Observable` macro (iOS 17+) | iOS 17 | Removes `@Published` boilerplate; use `@State` instead of `@StateObject` |
| Manual `.onAppear` subscription | `.task {}` modifier with async for-await | iOS 15+ | Task cancellation is automatic |
| `actionSheet` (deprecated) | `.confirmationDialog()` | iOS 15+ | `actionSheet` removed; `confirmationDialog` is correct |

**Deprecated/outdated:**
- `actionSheet`: Removed in iOS 16. Use `.confirmationDialog()` — already the correct API.
- `presentationMode` binding for sheet dismissal: Replaced by `@Environment(\.dismiss)` — use the environment value.

---

## Open Questions

1. **HorizonCalendar on Mac Catalyst**
   - What we know: STATE.md flags this as unverified; "fallback is custom SwiftUI calendar grid (~2-3 weeks additional)"
   - What's unclear: Whether the `CalendarViewRepresentable` renders and responds to taps correctly on Mac
   - Recommendation: Test in the first task of this phase. If it fails, implement a simple custom `LazyVGrid` month grid — it's a 1-2 day fallback, not 2-3 weeks, for the mini month use case.

2. **Drag-to-move event UX on overlapping events**
   - What we know: DragGesture works on individual event cards; Claude's Discretion area
   - What's unclear: How to handle drag origin for events that are rendered narrower (side-by-side overlap columns)
   - Recommendation: Implement drag on full-width cards first (day view only); defer overlap-aware drag to a later task.

3. **Week view event density on iPhone**
   - What we know: 7 columns in portrait iPhone is very narrow (~47pt per column on iPhone 16)
   - What's unclear: Whether event cards at that width are readable
   - Recommendation: In week view, show event cards with colored bars only (no text) below a certain width threshold. This is Claude's Discretion.

4. **Convex subscription scope**
   - What we know: Phase 1 uses `events:list` (all events, no filter). Suitable for Phase 2 given small dataset.
   - What's unclear: Whether subscribing to all events causes performance issues with a populated calendar
   - Recommendation: Use `events:list` for Phase 2. Add `events:listByRange` query (already documented above) if slow. Index `by_start` is already defined in schema.ts.

---

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation — `NSDataDetector`, `ScrollPosition`, `confirmationDialog`, `DragGesture`, `DateFormatter`
- `convex/schema.ts` (project file) — confirmed `by_start` index, `v.int64()` for start/duration
- `convex/events.ts` (project file) — confirmed `events:create`, `events:update`, `events:remove` mutations exist
- `LoomCal/Models/LoomEvent.swift` (project file) — confirmed `@ConvexInt` usage and field names
- Convex Docs (https://docs.convex.dev/database/reading-data/indexes/) — index range query syntax
- NSHipster (https://nshipster.com/nsdatadetector/) — NSDataDetector Swift patterns

### Secondary (MEDIUM confidence)
- HorizonCalendar GitHub README (https://github.com/airbnb/HorizonCalendar/blob/master/README.md) — `CalendarViewRepresentable` is the SwiftUI type; confirmed month/date-picker only (NOT a timeline)
- KVKCalendar GitHub + releases page — v0.6.30 (Nov 2024), iOS 13+, day/week timeline confirmed, `CurrentLineView` (now indicator) confirmed; drag support claimed but delegate method signatures not publicly documented
- Convex Swift docs (https://docs.convex.dev/client/swift) — `subscribe(to:with:yielding:)` pattern with `with:` arguments confirmed
- SerialCoder.dev / Hacking with Swift — `ScrollPosition` iOS 18 API, `@Environment(\.dismiss)` pattern

### Tertiary (LOW confidence)
- KVKCalendar drag-to-move functionality — mentioned indirectly in source code references ("haptic engine") but delegate method signatures for move events not found in web sources. Requires hands-on examination of the library source.

---

## Metadata

**Confidence breakdown:**
- Standard stack: MEDIUM-HIGH — HorizonCalendar verified as month-only (no timeline), iOS 13+ confirmed; KVKCalendar v0.6.30 confirmed active; NSDataDetector confirmed for NL parsing
- Architecture: HIGH — Convex mutation patterns verified against live codebase from Phase 1; SwiftUI ScrollView pattern is standard
- Pitfalls: MEDIUM — Phase 1 notes provide real project-specific gotchas (ConvexInt, Mac entitlements); general SwiftUI pitfalls verified from Apple docs

**Research date:** 2026-02-20
**Valid until:** 2026-03-20 (30 days — stable framework stack)
