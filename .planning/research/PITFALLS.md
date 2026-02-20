# Pitfalls Research

**Domain:** AI-powered calendar and task management app (SwiftUI multiplatform + Convex + Telegram bot AI)
**Researched:** 2026-02-20
**Confidence:** MEDIUM-HIGH (specific technology gotchas verified via official docs; architecture pitfalls from multiple community sources)

---

## Critical Pitfalls

### Pitfall 1: EventKit iOS 17+ Deprecated Permission API

**What goes wrong:**
Using the old `requestAccessToEntityType(.event, completion:)` API on iOS 17+ causes silent failures or broken calendar access. The old API was deprecated in iOS 17 and apps targeting iOS 17+ must use `requestFullAccessToEvents()` or `requestWriteOnlyAccessToEvents()`. Apps built against older SDK versions that ask for calendar access may only receive write-only access even when full access is needed — then when they try to fetch events, iOS prompts for an upgrade to full access, creating a confusing two-step permission flow for users.

**Why it happens:**
Tutorials and Stack Overflow answers written before iOS 17 (September 2023) use the old API. Developers following older examples don't realize the API changed. The deprecation warning is easy to miss if targeting an older deployment target.

**How to avoid:**
Use `requestFullAccessToEvents()` from day one. Add `NSCalendarsFullAccessUsageDescription` to Info.plist (not the old `NSCalendarsUsageDescription`). Require iOS 17 as the minimum deployment target — this app has no reason to support iOS 16. Never use `requestAccessToEntityType(.event)`.

```swift
// Correct for iOS 17+
let store = EKEventStore()
try await store.requestFullAccessToEvents()

// Wrong — deprecated, causes permission issues on iOS 17+
store.requestAccess(to: .event) { granted, error in ... }
```

**Warning signs:**
- Calendar access appears granted but event fetching returns empty results
- Users see two separate permission prompts ("add only" then "full access")
- `EKAuthorizationStatus.authorized` but `calendars(for:)` returns nothing
- Compiler deprecation warnings on permission request methods

**Phase to address:** Phase 1 (Calendar Foundation / EventKit Integration)

---

### Pitfall 2: Convex Swift Number Type Mismatch (BigInt vs number)

**What goes wrong:**
Convex's TypeScript backend distinguishes between `BigInt` and `number`. Swift has no such distinction. If your Convex schema uses regular JavaScript `number` types for integer fields (e.g., task priority, duration minutes, position indices), they arrive in Swift as floating-point values and `Int` deserialization silently fails or crashes. Conversely, if you use `Int64` in Swift and send it to a JSON-based backend, values above 2^53 become lossy because JavaScript only supports 53-bit integers as `number`.

**Why it happens:**
The Convex Swift SDK (v0.8.0 as of February 2026) requires explicit property wrappers — `@ConvexInt` for integers and `@ConvexFloat` for floats. Developers used to standard `Codable` assume Swift structs just work. The SDK documentation mentions the gotcha but doesn't surface it prominently.

**How to avoid:**
Always use `@ConvexInt` for fields that are integers in your Convex schema and `@ConvexFloat` for floats. In your Convex TypeScript schema, use `v.int64()` (not `v.number()`) for any integer field that will be read by the Swift client. Enforce this in code review. Write a test for round-trip encoding of numeric types before building any feature that stores numbers.

```swift
// Correct
struct Task: Decodable {
    @ConvexInt var priority: Int
    @ConvexFloat var estimatedHours: Double
}

// Wrong — works in JS client, silently breaks in Swift
struct Task: Decodable {
    var priority: Int        // crashes if backend sends number type
    var estimatedHours: Double
}
```

**Warning signs:**
- Decoding crashes or unexpected nil values on integer fields
- Tests pass in TypeScript but Swift client returns wrong values
- `DecodingError.typeMismatch` at runtime when reading query results
- Fields that "sometimes work" (when value is `0` or small enough to be losslessly converted)

**Phase to address:** Phase 1 (Convex Backend Setup / Swift Client Integration)

---

### Pitfall 3: Loom Local Gateway Unavailability Not Handled Gracefully

**What goes wrong:**
Loom runs on a local network gateway (OpenClaw-based). When the user is away from home, on cellular, or when the gateway machine is asleep/rebooted, Loom is completely unreachable. An app that treats Loom as always-available will hang on AI requests, show infinite spinners, or crash. Worse: if time-blocking or daily planning features block on Loom's response, core calendar functionality becomes unusable when Loom is offline.

**Why it happens:**
During development on a local network, Loom is always reachable, so the failure path is never exercised. Async calls to Loom via Telegram bot API timeout slowly (default 30-60 seconds), creating terrible UX before any error is shown. OpenClaw itself has documented reliability issues with Telegram long-polling that cause intermittent silent failures even when the gateway is "running."

**How to avoid:**
Treat Loom as an optional enhancement, never a blocker for core functionality. Design the AI chat panel as independently dismissible from calendar/task views. Implement a Loom reachability check on app launch and cache the status. Use short timeouts (5-8 seconds) for Loom requests, not the default. Show a clear "Loom is unavailable — working offline" state rather than a spinner. The calendar, task creation, and editing must work fully without Loom.

**Warning signs:**
- AI chat requests have no timeout configured
- "Daily planning" feature is required before showing tasks for the day
- UI shows spinner with no cancel mechanism on Loom requests
- No offline mode test in development (always tested on home network)

**Phase to address:** Phase 2 (Loom/Telegram Integration) — must design this phase with explicit offline-first thinking

---

### Pitfall 4: EventKit + Convex Sync Creates Duplicate or Phantom Events

**What goes wrong:**
The app reads Apple Calendar events via EventKit (read-only source of truth) and stores Convex-native events separately. When sync logic is naive, the same event gets written to both stores or appears twice in the unified view. The reverse problem: a Convex event modified by Loom doesn't update in EventKit (they're separate systems), confusing users who see stale data in Apple Calendar alongside current data in the app.

A specific failure mode: `EKEventStoreChanged` notification arrives whenever any calendar changes externally, but carries no information about what changed. Apps that batch-refresh all events on every notification (the only viable option) will overwhelm Convex with redundant write operations if they naively mirror EventKit events to Convex on each refresh.

**Why it happens:**
Developers treat EventKit and Convex as equivalent writable stores instead of defining clear ownership. Without an explicit "source of truth" rule per calendar type, sync logic becomes inconsistent. The `EKEventStoreChanged` notification's complete lack of change details forces full reloads.

**How to avoid:**
Define ownership explicitly and never violate it:
- Apple Calendar events: EventKit is source of truth. Convex stores only a read cache with an `ekIdentifier` field for deduplication. Never write Apple Calendar events back to EventKit from Convex.
- Convex-native events (tasks scheduled on calendar, Loom-created events): Convex is source of truth. Never put these in EventKit.
- Supabase studio events: Supabase is source of truth via Loom sync. Convex holds a read-cached copy.

Use `EKEvent.eventIdentifier` as a stable dedup key when caching EventKit events in Convex. Throttle `EKEventStoreChanged` responses with a debounce (minimum 2 seconds) to avoid sync storms.

**Warning signs:**
- The same event appears twice in the unified calendar view
- Deleting an event in Apple Calendar doesn't remove it from the app view
- High Convex mutation count on calendar open even when nothing changed
- Loom creates a new event but user also sees the old version from EventKit cache

**Phase to address:** Phase 1 (EventKit Integration) and Phase 3 (Unified Calendar View / Multi-Source Sync)

---

### Pitfall 5: Timezone and Date Handling Inconsistencies Across Three Systems

**What goes wrong:**
Three data sources use dates differently. EventKit uses `Date` (absolute time with implicit system timezone). Convex stores timestamps as milliseconds since Unix epoch (timezone-agnostic). Supabase PostgreSQL may store timestamps with or without timezone depending on column type. Loom's AI reasoning about "tomorrow 3pm" is relative to an unspecified timezone (likely Telegram server time or LLM inference time). A recurring event at "9am" during winter is the same UTC time as summer until DST shifts it — Convex stores the UTC value but EventKit represents the local time.

Calendar apps written by developers who store everything as UTC without timezone metadata will break for users in non-UTC timezones, users who travel, and recurring events around DST transitions.

**Why it happens:**
In development, UTC and local time are often the same (or close enough to miss bugs). DST bugs only appear twice a year. Using `Calendar.current` instead of `Calendar.autoupdatingCurrent` means the app doesn't react if the user changes their timezone setting. AI systems routinely get "next Tuesday" and "tomorrow at 3pm" wrong without explicit timezone context.

**How to avoid:**
- Always use `Calendar.autoupdatingCurrent` (not `.current`) in Swift so timezone changes are reflected immediately
- Store all Convex timestamps as UTC milliseconds (never local time) with a separate `timezone` field for display
- Store recurring rule definitions (not just expanded instances) in Convex so rules can be re-expanded for new timezones
- When sending scheduling instructions to Loom, always include the user's current timezone: "Schedule this for tomorrow 3pm [America/New_York]"
- Use `TimeZone(identifier:)` explicitly in `DateFormatter` and `Calendar` instances — never rely on implicit system timezone in date parsing
- Test with a device set to UTC+0 and a device set to UTC-8 before shipping any date-related feature

**Warning signs:**
- Events appear at wrong times after flying across time zones
- Recurring events shift one hour after DST transition
- "Calendar.current" appears anywhere in the codebase (search for it)
- Date parsing anywhere without explicit timezone specification
- Loom creates events at wrong times ("3pm" becomes "3am" or vice versa)

**Phase to address:** Phase 1 (Data Model Design) — timezone approach must be locked before any persistent storage

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Store EventKit events directly in Convex as writable records | Simpler data model, no cache layer needed | EventKit is source of truth — writes to Convex that contradict EventKit cause split-brain; silent overwrites when EventKit changes | Never |
| Use `Calendar.current` instead of `autoupdatingCurrent` | Shorter code | Timezone changes during app session aren't reflected; invisible bug for traveling users | Never |
| Build AI daily planning as a blocking step before showing calendar | Simpler sequential flow | App is unusable when Loom is offline; terrible UX on slow networks | Never |
| Skip debouncing `EKEventStoreChanged` | Simpler event handling | Sync storms: each external calendar change triggers full Convex sync, cascading into Convex rate limits | Never |
| Hardcode `@ConvexInt` only where needed now | Faster initial development | Number type bugs surface unpredictably as new Convex fields are added; harder to audit | Acceptable for prototype, must be systematic before any persistent data |
| Use naive string matching for Loom's event creation responses | Ships faster | Loom's response format can change; natural language dates are ambiguous; edge cases multiply | Prototype only — switch to structured JSON responses from Loom before shipping |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| EventKit | Using `requestAccessToEntityType` (deprecated iOS 17) | Use `requestFullAccessToEvents()` and add `NSCalendarsFullAccessUsageDescription` to Info.plist |
| EventKit | Treating `EKEventStoreChanged` as a precise change notification | It carries no change details — debounce it and perform selective refresh using `EKEvent.refresh()` on known events; do full reload only when necessary |
| EventKit | Ignoring external calendar source refresh | Call `refreshSourcesIfNecessary()` before fetching events from remote calendar accounts (iCloud, Exchange) to get current data |
| Convex Swift | Assuming standard `Codable` works for numeric types | All integer fields need `@ConvexInt`, all float fields need `@ConvexFloat` — standard `Int`/`Double` with `Decodable` breaks for `number` vs `BigInt` mismatch |
| Convex Swift | Using `ConvexClient` for authenticated endpoints | `ConvexClient` is unauthenticated; use `ConvexClientWithAuth` (Auth0 via separate `convex-swift-auth0` package) or custom `AuthProvider` implementation |
| Convex Swift | Not cancelling subscriptions on view dismiss | Convex `subscribe` returns an async sequence; if the consuming `Task` isn't stored and cancelled on view disappear, subscriptions leak and accumulate |
| Telegram/Loom | No timeout on Telegram sendMessage requests | Default timeout can be 30-60 seconds; set explicit 8-second timeout so UI can recover quickly when Loom is unreachable |
| Telegram/Loom | Polling vs webhook confusion for local gateway | OpenClaw uses long-polling against Telegram API; app sends messages to Loom's bot, not the other way — app does not need to run a webhook receiver |
| Supabase sync | Treating Supabase as a writable mirror | Supabase vocal studio calendar is source of truth; Loom syncs it to Convex read-only; app must never write studio events back to Supabase directly |
| SwiftUI multiplatform | Using iOS-only modifiers without `#if os(iOS)` guards | `navigationBarItems`, `UIApplication`, `.statusBar`, sheet presentation styles — all iOS-only and cause compile failures on macOS |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Loading all calendar events for all time into memory | App hangs on open; memory warnings with heavy iCloud calendar history | Use date-range predicates in EventKit (`predicateForEvents(withStart:end:calendars:)`) — never fetch without a date window | > ~500 events in memory |
| SwiftUI `LazyVStack` for calendar rows without stable IDs | Jank when scrolling; state resets on scroll-back | Use `List` (has view recycling like UITableView) for event lists; always provide stable `id:` in `ForEach` using event's unique identifier | > ~200 rows |
| Convex subscription per calendar cell/row | WebSocket message flood; Convex rate limiting | Subscribe at the view model level for a date range, not per cell | > 20 concurrent subscriptions |
| Re-fetching EventKit events on every view render | Visible lag when switching calendar views | Cache fetched events in an `@Observable` or `ObservableObject` store; invalidate only on `EKEventStoreChanged` | Any dataset > 50 events |
| Debounce too short on `EKEventStoreChanged` | Sync storms — multiple parallel Convex mutations on rapid external changes | Minimum 2-second debounce; coalesce multiple notifications into a single refresh | Multiple rapid external calendar changes (e.g., CalDAV bulk import) |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Storing Telegram bot token in source code or Info.plist | Token exposed if app is reverse-engineered; attacker can impersonate Loom | Store bot token server-side (in Convex environment variables or backend); app communicates via Convex actions that proxy to Loom, never directly |
| Logging full Telegram message content in debug builds | Calendar events, task names, private information leaked to logs | Never log message body content; log only message IDs and status codes |
| Missing Convex function authentication | Any user can call Convex mutations without auth | This is a single-user personal app, but still: protect Convex mutations with Convex auth so the deployment can't be abused if URL is discovered |
| Supabase connection string in Swift app | Direct DB access from client; credentials exposure | App never connects to Supabase directly — Loom is the only bridge; keep Supabase credentials in Loom/OpenClaw environment only |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| AI daily planning blocks showing the calendar | App appears broken when Loom is offline; user can't see their day | Show calendar immediately; load Loom's suggestions as an overlay/panel that appears when ready (or shows "Loom unavailable" state) |
| Time-blocking creates events without conflict detection | User schedules a task into an already-occupied slot; double-booking | Check existing events (both EventKit and Convex-native) before placing a time block; show conflicts before confirming |
| Loom creates events using relative dates without confirmation | "Schedule for tomorrow" at 9am when user meant 2pm; hard to undo | Always show a preview of what Loom is about to create/modify and require explicit confirmation before mutations |
| Dismissing chat panel loses conversation context | User loses pending instructions; has to retype | Persist chat history in Convex (not just in-memory); chat panel restores on reopen |
| macOS sidebar behavior differs from iOS expectations | Mac users expect persistent sidebar; iOS users expect sheet navigation | Use `NavigationSplitView` with platform-appropriate column visibility defaults; don't force iOS sheet patterns on Mac |
| Infinite spinner when Convex WebSocket is establishing | App appears broken on first launch or after offline period | Show a skeleton/placeholder calendar while Convex syncs; never block the UI waiting for real-time data to load |

---

## "Looks Done But Isn't" Checklist

- [ ] **EventKit permissions:** Verify both `NSCalendarsFullAccessUsageDescription` AND `NSRemindersFullAccessUsageDescription` are in Info.plist; verify the right permission API is called for iOS 17+; verify graceful degradation when user denies
- [ ] **Convex subscriptions:** Verify all `subscribe` Tasks are stored and cancelled in `onDisappear` or view model deinit; check for memory leaks with Instruments
- [ ] **Loom offline state:** Test the entire app with no network access to local gateway; verify no spinners without timeouts; verify core features (view calendar, add task, edit event) work without Loom
- [ ] **Timezone correctness:** Set device to a non-local timezone; create an event; verify it appears at the correct local time; test DST boundary dates
- [ ] **EventKit + Convex dedup:** Add an event in Apple Calendar; verify it appears exactly once in unified view (not duplicated in both EventKit and Convex layers)
- [ ] **Convex number types:** Verify round-trip encoding for all numeric Convex fields using `@ConvexInt`/`@ConvexFloat`; add a test that reads back what was written
- [ ] **macOS compilation:** Verify app compiles with macOS as a destination target without `#if os(iOS)` guard violations; test toolbar, navigation, and menu bar
- [ ] **Large calendar datasets:** Test with a CalDAV calendar containing 500+ events; verify no UI hangs, memory warnings, or infinite loads
- [ ] **OpenClaw Telegram polling:** Verify the app handles the case where Loom sends no response (not just an error response) — long polling timeouts that return nothing

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| EventKit deprecated API | LOW | Replace `requestAccessToEntityType` with `requestFullAccessToEvents()`; update Info.plist keys; re-test permissions |
| Convex number type mismatch | MEDIUM | Audit all Convex-reading Swift structs for undecorated numeric fields; add `@ConvexInt`/`@ConvexFloat` wrappers; may require Convex schema migration from `v.number()` to `v.int64()` |
| Sync duplicate events | HIGH | Requires data audit of Convex store to deduplicate; rebuild sync logic with explicit ownership rules; add `ekIdentifier` dedup key to Convex schema |
| Timezone data stored incorrectly | HIGH | All stored dates need migration; recurring rules may need re-expansion; potentially visible to users as shifted events |
| Loom blocking core UI | MEDIUM | Refactor AI features from blocking to async/overlay pattern; no data migration needed but UI restructuring required |
| Convex subscription leaks | MEDIUM | Audit all subscription-creating call sites; add Task storage + cancellation; profile with Instruments to confirm resolution |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| EventKit deprecated permission API | Phase 1: EventKit Integration | Permissions flow tested on iOS 17+ device; Info.plist keys verified; no deprecated API warnings |
| Convex number type mismatch | Phase 1: Convex Backend Setup | Round-trip encoding test for all numeric fields passes; `@ConvexInt`/`@ConvexFloat` used throughout |
| Timezone inconsistencies | Phase 1: Data Model Design | All dates stored as UTC + timezone identifier; `autoupdatingCurrent` used throughout; DST boundary test passes |
| EventKit + Convex duplicate events | Phase 1: Data Model Design + Phase 3: Unified View | `ekIdentifier` dedup in place; unified view shows each event exactly once across all sources |
| EventKit sync storms | Phase 3: Multi-Source Sync | `EKEventStoreChanged` handler has 2s+ debounce; Convex mutation count monitored during rapid external changes |
| Loom unreachable not handled | Phase 2: Loom Integration | Full app tested with Loom offline; all timeouts < 8s; "Loom unavailable" state shown; core features work without AI |
| Convex subscription leaks | Phase 2: Convex Real-time | Instruments memory profiling run; all subscriptions cancelled on view dismiss |
| SwiftUI iOS/Mac modifier conflicts | Phase 4: macOS Polish | App compiles and runs on macOS without crashes; toolbar/navigation tested on Mac |
| AI creates events with wrong timezone | Phase 2: Loom Integration | All Loom scheduling prompts include explicit timezone; event preview shown before Loom mutation confirmed |
| Large calendar performance | Phase 3: Calendar View | Tested with 500+ events; date-range predicates used; no memory warnings |

---

## Sources

- [EventKit Apple Developer Documentation](https://developer.apple.com/documentation/eventkit) — official API reference
- [TN3153: Adopting API Changes for EventKit in iOS 17, macOS 14, watchOS 10](https://developer.apple.com/documentation/technotes/tn3153-adopting-api-changes-for-eventkit-in-ios-macos-and-watchos) — official migration guide
- [TN3152: Migrating to the Latest Calendar Access Levels](https://developer.apple.com/documentation/technotes/tn3152-migrating-to-the-latest-calendar-access-levels) — official permission migration
- [Convex Swift SDK GitHub — convex-swift v0.8.0](https://github.com/get-convex/convex-swift) — official SDK, 38 stars, active as of February 2026
- [Swift and Convex Type Conversion](https://docs.convex.dev/client/swift/data-types) — official docs on number type gotchas (`@ConvexInt`, `@ConvexFloat`)
- [Convex iOS & macOS Swift Documentation](https://docs.convex.dev/client/swift) — official SDK docs
- [Updating with Notifications — EventKit](https://developer.apple.com/documentation/eventkit/updating-with-notifications) — `EKEventStoreChanged` behavior
- [How to monitor system calendar for changes with EventKit](https://nemecek.be/blog/63/how-to-monitor-system-calendar-for-changes-with-eventkit) — `EKEventStoreChanged` has no change details, full reload required
- [iOS calendars — current vs autoupdatingCurrent](https://www.radude89.com/blog/ios-calendars.html) — timezone snapshot vs dynamic calendar pitfall
- [Building Cross-Platform SwiftUI Apps — fatbobman](https://fatbobman.com/en/posts/building-multiple-platforms-swiftui-app/) — macOS/iOS SwiftUI differences
- [SwiftUI for Mac 2025 — TrozWare](https://troz.net/post/2025/swiftui-mac-2025/) — current state of SwiftUI on Mac including 2025 Liquid Glass changes
- [OpenClaw GitHub Issues](https://github.com/openclaw/openclaw/issues) — documented Telegram polling reliability failures (Issues #4942, #7327, #15082)
- [Building Robust Telegram Bots](https://henrywithu.com/building-robust-telegram-bots/) — rate limit and reconnection patterns
- [Optimistic Updates — Convex Developer Hub](https://docs.convex.dev/client/react/optimistic-updates) — mutating objects in optimistic updates corrupts client state
- [Memory management when using async/await in Swift](https://www.swiftbysundell.com/articles/memory-management-when-using-async-await/) — retain cycles and Task lifetime
- [Convex Real-time Documentation](https://docs.convex.dev/realtime) — automatic reconnection and mutation replay behavior

---
*Pitfalls research for: Loom Cal — AI-powered calendar/task management app (SwiftUI + Convex + Telegram bot)*
*Researched: 2026-02-20*
