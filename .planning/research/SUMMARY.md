# Project Research Summary

**Project:** Loom Cal
**Domain:** Native iOS + Mac calendar/task management app with AI assistant integration
**Researched:** 2026-02-20
**Confidence:** MEDIUM (core stack HIGH; Telegram integration pattern and architecture inferences MEDIUM)

## Executive Summary

Loom Cal is a personal-use SwiftUI multiplatform app (iOS 17+ / macOS 14+) that unifies three calendar sources — Apple Calendar (EventKit), a vocal studio calendar (Supabase via Loom sync), and Convex-native events — alongside a task manager and an embedded AI chat interface powered by Loom, a Telegram bot running on a local gateway. The recommended approach is to build the app as a shared SwiftUI codebase with a single Convex backend for real-time data, EventKit for Apple Calendar read/write, and a minimal URLSession-based Telegram HTTP client for Loom communication. The architecture is mature and well-suited to the problem: Convex provides the reactive data layer, EventKit owns Apple Calendar truth, Loom owns Supabase sync, and the app owns nothing it does not create. The key architectural win is a `UnifiedEvent` merge model that normalizes all three sources before any view sees data.

The recommended stack (SwiftUI + Swift 6 + ConvexMobile 0.8.0 + EventKit + SwiftData) is technically sound for a 2025 greenfield project. iOS 17 as the deployment floor unlocks SwiftData, @Observable, the new EventKit permission APIs, and the full modern Swift concurrency surface. Third-party calendar UI libraries (HorizonCalendar for monthly grid, CalendarKit for timeline) reduce the most complex custom UI work. All other HTTP integration (Telegram Bot API, optional Supabase fallback) is handled with plain URLSession — no third-party SDK dependencies are needed for these integrations.

The most significant risk in this project is Loom's inherent unavailability: it runs on a local home gateway and will be unreachable whenever the user is on cellular, away from home, or when the gateway sleeps. This must be a first-class design constraint, not an afterthought — all AI features must degrade gracefully and all core calendar/task features must work without Loom. Secondary risks include EventKit/Convex sync producing duplicate or phantom events (requires explicit source-of-truth rules from Phase 1), and Convex's Swift-specific numeric type quirks (`@ConvexInt`/`@ConvexFloat` wrappers required) that will silently break deserialization if not addressed early.

---

## Key Findings

### Recommended Stack

The core technology choices are straightforward and well-supported. SwiftUI multiplatform with Swift 6 is the unambiguous recommendation for 2025 — it provides a single codebase for iOS and Mac with native idioms on both platforms, avoiding the known pitfalls of Catalyst. ConvexMobile 0.8.0 is non-negotiable per project constraints and is actively maintained (last commit Feb 17, 2026). SwiftData handles local caching cleanly with iOS 17+ and integrates with @Observable/SwiftUI without friction.

The Telegram integration is simpler than it might appear: the app sends messages via plain URLSession POSTs to the Telegram Bot API; Loom's replies flow back through Convex (Loom writes to a `chat_messages` table via its Convex MCP, and the iOS app subscribes reactively). The bot token must live server-side in Convex environment variables — never in the iOS app. HorizonCalendar's Mac behavior is the single unverified stack risk and needs hands-on evaluation in Phase 1.

**Core technologies:**
- SwiftUI multiplatform (iOS 17+ / macOS 14+): single codebase, true Mac idioms — not Catalyst
- Swift 6: strict concurrency checking catches data race bugs at compile time
- ConvexMobile 0.8.0: real-time WebSocket subscriptions + mutations; single client instance at app scope
- Apple EventKit (iOS 17+ API): only path to Apple Calendar data; `requestFullAccessToEvents()` required
- SwiftData (iOS 17+): local offline cache for Convex data; @Query integrates natively with SwiftUI
- HorizonCalendar (Airbnb, SPM): monthly calendar grid; battle-tested, Mac support unverified
- CalendarKit 1.1.11: day/week timeline view; UIKit-based (UIViewRepresentable); Mac Catalyst supported
- Telegram Bot API (direct HTTP): URLSession POST for outbound; Convex subscription for inbound replies
- Supabase Swift SDK 2.41.1 (PostgREST only): fallback direct read if Loom sync lags; not primary path

### Expected Features

The feature set is cleanly split by research into a well-defined MVP and two subsequent expansion tiers. The core thesis — one unified view of everything on the user's plate — requires multiple calendar source aggregation and the Loom chat interface to be present at launch. Time blocking (manual drag of task onto calendar) is also P1 because it is the action that makes the app more than a viewer. AI daily planning is explicitly P2: valuable, but it depends on Loom connectivity and should not gate the v1 launch.

The most important anti-feature finding: AI scheduling must never be fully autonomous. Research across Reclaim, Motion, and Clockwise user complaints consistently shows that removing the human approval step causes user frustration and distrust. Loom Cal must always show a preview and require one-tap confirmation before any AI-generated mutation commits.

**Must have (table stakes — v1 launch):**
- Day and week calendar views with unified EventKit + Convex + studio event display
- Apple Calendar event display and Convex-native event creation/editing
- Vocal studio calendar display (Supabase via Loom sync to Convex, read-only in app)
- Task creation with due date and priority; task list view
- Task due dates rendered as calendar markers; task → calendar slot time blocking (manual drag)
- Today view (current-day events + tasks due today)
- In-app Loom chat (send/receive with graceful offline degradation)
- Reminders and notifications (UNUserNotificationCenter)
- Recurring events display (from Apple Calendar; creation/editing deferred to v1.x)

**Should have (v1.x after validation):**
- AI daily planning with Loom-generated suggestions and required user approval step
- Travel time automation (MapKit routing, buffer event before location-based events)
- Natural language event/task entry ("standup tomorrow 10am")
- Frames / ideal week templates for recurring time-block patterns
- Upcoming multi-day view (Things 3-style interleaved events + tasks)
- Full recurring event creation and editing (RRULE support)
- Search across all events and tasks
- Calendar sets (user-defined named subsets of visible calendars)
- Task subtasks / checklists

**Defer (v2+):**
- Month calendar view; year view (navigation only)
- Buffer time automation; priority factor AI scoring
- iOS home screen widgets
- Mac-specific extras (menu bar item, keyboard shortcut palette)
- Apple Watch support

### Architecture Approach

The architecture follows a clean five-layer model: SwiftUI views (platform-specific shells + shared feature views) → @Observable/ObservableObject ViewModels → service layer (ConvexService, EventKitService, TelegramService, SyncService) → Convex backend (TypeScript schema + serverless functions) → external systems (EventKit, Telegram Bot API, Supabase via Loom only). The critical pattern is the `UnifiedEvent` merge struct: all three event sources (EventKit, Convex-native, Supabase-synced studio events) are normalized into `UnifiedEvent` in SyncService before any view layer sees data. This single decision eliminates conditional rendering throughout the calendar UI.

Convex current documentation explicitly recommends `ObservableObject` with `@Published` over the newer `@Observable` macro for ViewModels that own Convex subscriptions due to Combine publisher compatibility quirks. This is a pragmatic call: use `ObservableObject` now, revisit when the SDK matures. Target 85%+ shared code between iOS and macOS, keeping platform-specific files thin (navigation shell, menu bar, gesture adapters).

**Major components:**
1. EventKitService — singleton EKEventStore; permission request; read-only event fetch; EKEventStoreChanged debounce
2. ConvexService — single ConvexClient app-scoped; subscribe/mutation bridge; all Convex-native data
3. TelegramService — actor; URLSession POST sendMessage + long-poll getUpdates; 8s timeout; bot token never in app
4. SyncService — stateless merge function; UnifiedEvent assembly from EventKit + Convex + studio sources
5. Convex backend — TypeScript schema: events, tasks, projects, studio_events, chat_messages tables
6. Loom (external) — Telegram bot on local gateway; sole Supabase reader; writes to Convex via MCP

### Critical Pitfalls

1. **EventKit deprecated permission API** — Use `requestFullAccessToEvents()` (iOS 17+) from day one. Never use `requestAccessToEntityType(.event)`. Add `NSCalendarsFullAccessUsageDescription` (not the old key) to Info.plist. Must be correct in Phase 1; wrong API causes silent calendar access failures.

2. **Convex Swift numeric type mismatch** — All integer Convex fields require `@ConvexInt`; all float fields require `@ConvexFloat`. Standard Swift `Int`/`Double` with `Decodable` silently fails for `number` vs `BigInt` mismatch. Use `v.int64()` in TypeScript schema for integer fields. Audit every Convex-reading Swift struct in Phase 1.

3. **Loom unreachability not handled** — Loom runs on a local gateway and will regularly be offline. All Telegram requests must have an 8-second max timeout. Core calendar and task features must work fully without Loom. Show a clear "Loom unavailable" state — no infinite spinners. Design this constraint into Phase 2 from the start.

4. **EventKit + Convex duplicate/phantom events** — Define ownership rules before writing a line of sync code: EventKit owns Apple Calendar events (Convex caches with `ekIdentifier` dedup key, never writes back); Convex owns app-native events; Supabase owns studio events (Convex caches, app reads only). Violating these rules requires expensive data migration to recover. Enforce with a 2-second debounce on `EKEventStoreChanged` to prevent sync storms.

5. **Timezone inconsistencies across three systems** — Store all Convex timestamps as UTC milliseconds with a separate `timezone` field. Use `Calendar.autoupdatingCurrent` everywhere in Swift (never `.current`). Include explicit timezone in all Loom scheduling prompts. Lock the timezone approach in Phase 1 data model design — wrong early storage requires full data migration.

---

## Implications for Roadmap

Research reveals clear dependency layers that dictate build order. The foundation (Convex schema, EventKit integration, UnifiedEvent model) must exist before any calendar view can show complete data. Calendar views must exist before time blocking can work. Loom chat is independent of calendar views but enhances them via reactive Convex updates. Platform polish (Mac navigation, notifications) can run in parallel with AI integration. The AI planning features are the last layer: they depend on everything below and require the most careful offline-state design.

### Phase 1: Foundation — Data Model and Calendar Sources

**Rationale:** Everything depends on this. The Convex schema, EventKit integration, and UnifiedEvent merge model are prerequisite for every other feature. Timezone rules and source-of-truth ownership rules must be locked here — they cannot be changed cheaply later. Three of five critical pitfalls are Phase 1 concerns.

**Delivers:** A running app that shows unified calendar events from Apple Calendar + Convex-native events. No AI features yet. Core data model is correct and stable.

**Addresses:** Day/week calendar views (display only), Apple Calendar event display, Convex-native event creation, basic task model with due dates

**Avoids:** EventKit deprecated permission API (use `requestFullAccessToEvents()` from start), Convex numeric type mismatch (enforce `@ConvexInt`/`@ConvexFloat` in all Swift models), timezone inconsistencies (lock UTC storage + timezone field + `autoupdatingCurrent` before any data is persisted), EventKit/Convex duplicate events (source-of-truth ownership rules defined in schema design)

**Research flag:** NEEDS RESEARCH — Verify HorizonCalendar renders correctly in SwiftUI Mac target (not Catalyst). Verify ConvexMobile Package.swift minimum Swift version. Telegram reply routing pattern (Loom writes to `chat_messages` → iOS subscribes) requires coordination with Loom MCP configuration before Phase 3.

### Phase 2: Task System and Loom Chat Integration

**Rationale:** Tasks are P1 and have simpler infrastructure than calendar sync (Convex-only, no EventKit merge needed). Loom chat is P1 but must be built with explicit offline-first design — this requires Loom unreachability testing from the moment it is built. Doing both in Phase 2 allows the Loom integration to be validated against real task data before AI planning features are added.

**Delivers:** Full task CRUD (title, due date, priority, project grouping), task list view, task due-date markers on calendar, Today view, and the Loom chat panel (send/receive with "Loom unavailable" graceful degradation). Loom can already create and edit Convex events/tasks via MCP — the app will reflect these in real-time via existing subscriptions.

**Addresses:** Task creation + due dates, task list view, task → calendar rendering, Today view, in-app Loom chat

**Avoids:** Loom unreachability blocking core UI (all Telegram requests get 8s timeout; app never blocks on AI response; chat panel is dismissible independently from calendar), Convex subscription leaks (Task storage + cancellation in ViewModels audited this phase)

**Research flag:** STANDARD PATTERNS — Task CRUD on Convex is well-documented. Telegram Bot API HTTP calls are simple and documented. Offline state patterns are well-understood.

### Phase 3: Unified Calendar View and Multi-Source Sync

**Rationale:** By Phase 3, the individual data sources (EventKit, Convex tasks, Convex events) and the Loom chat are working in isolation. Now they must be unified into a coherent calendar display with proper sync logic. Vocal studio events require the Loom MCP sync pipeline to be operational — this is a cross-system dependency that must be coordinated. Manual time blocking (drag task to calendar slot) is the flagship interaction and belongs here once all sources are visible.

**Delivers:** Unified calendar view showing all three sources without duplication, vocal studio calendar integration, manual time blocking (drag task → calendar slot creates Convex time-block event), conflict detection before time block placement, reminders/notifications.

**Addresses:** Multiple calendar source aggregation, vocal studio calendar display, time blocking (manual), reminders/notifications, recurring event display

**Avoids:** EventKit sync storms (2s+ debounce on EKEventStoreChanged, date-range predicates always used), duplicate/phantom events (ekIdentifier dedup key enforced, source ownership rules verified), large calendar dataset performance (500+ event test required this phase)

**Research flag:** NEEDS RESEARCH — Vocal studio Supabase MCP sync pipeline timing and reliability. CalDAV vs direct Supabase API access for studio data. RRULE library options for recurring event expansion in Convex.

### Phase 4: Platform Polish — iOS and macOS Native Shells

**Rationale:** iOS and macOS navigation shells, notifications, and platform-specific interactions can be built largely in parallel with Phase 3. They belong after the core data layer is stable so the navigation is not rebuilt when data models change. macOS-specific patterns (NavigationSplitView sidebar, toolbar, menu bar extras) require deliberate attention to avoid iOS-only modifier bleedthrough.

**Delivers:** Native iOS tab navigation, macOS NavigationSplitView sidebar layout, platform-appropriate calendar gestures, UNUserNotificationCenter local alerts for events and task deadlines.

**Addresses:** Platform-appropriate UX (iOS sheets vs Mac persistent sidebar), notifications for events and tasks, Mac menu bar extras (future), quick-entry window (future)

**Avoids:** SwiftUI iOS/Mac modifier conflicts (all iOS-only modifiers guarded with `#if os(iOS)`; macOS compilation verified as CI gate)

**Research flag:** STANDARD PATTERNS — Apple's Food Truck sample app documents SwiftUI multiplatform patterns well. NavigationSplitView Mac idioms are well-documented.

### Phase 5: AI Planning and Advanced Features

**Rationale:** AI daily planning is the highest-complexity feature and depends on everything below it: tasks (Phase 2), calendar views (Phase 3), and Loom connectivity (Phase 2). Building it last ensures the foundation is stable and that Loom's Convex MCP integration is proven before adding the approval-flow planning workflow. This phase also includes the v1.x features that add competitive differentiation.

**Delivers:** AI daily planning with Loom-generated suggestions and required user approval step before mutations commit, natural language event/task entry, travel time automation (MapKit routing), Frames/ideal week templates.

**Addresses:** AI daily planning, natural language entry, travel time automation, Frames, Upcoming multi-day view

**Avoids:** Fully autonomous AI scheduling (always require approval step — this is non-negotiable based on competitor research), AI creating events without timezone context (always include explicit timezone in Loom prompts)

**Research flag:** NEEDS RESEARCH — MapKit routing API for travel time estimation. Natural language parsing library options for on-device NLP vs API-based. Loom prompt engineering for structured JSON event creation responses vs naive string parsing.

---

### Phase Ordering Rationale

- **Data model first:** Timezone storage and source-of-truth ownership cannot be changed cheaply after data is persisted. These decisions in Phase 1 affect every subsequent phase.
- **Tasks before AI planning:** AI planning requires a populated task model to be useful. Building tasks in Phase 2 means Phase 5 AI has real data to work with from day one.
- **Loom chat before AI planning:** The Telegram integration must be proven reliable (with offline handling) before adding the more complex AI planning workflow on top of it.
- **Platform polish parallel to sync:** macOS shell and notifications are largely independent of the multi-source sync logic, enabling parallel progress.
- **Advanced features last:** Travel time, natural language entry, and AI planning are all well-defined in scope but high in implementation complexity. Placing them last keeps the critical path short.

### Research Flags

Phases needing deeper research during planning:
- **Phase 1:** HorizonCalendar Mac target behavior (unverified); ConvexMobile Swift version minimum; Telegram reply routing requires Loom MCP coordination before schema is finalized
- **Phase 3:** Vocal studio Supabase sync pipeline details; RRULE library selection for recurring event expansion; CalDAV availability for studio calendar
- **Phase 5:** MapKit routing API details; NLP parsing library selection; Loom prompt engineering for structured event creation

Phases with standard patterns (skip research-phase):
- **Phase 2:** Task CRUD on Convex is well-documented; Telegram Bot API HTTP calls are straightforward; offline state patterns are well-understood
- **Phase 4:** SwiftUI multiplatform navigation patterns are well-documented via Apple's official sample apps

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM-HIGH | Core choices (SwiftUI, Swift 6, Convex, EventKit, SwiftData) verified via official docs. HorizonCalendar Mac behavior is MEDIUM — unverified. Telegram integration pattern is architectural inference, not documented by Telegram. |
| Features | MEDIUM | Morgen/Fantastical/Things 3 competitor features from official sites = HIGH. AI planning nuances and implementation complexity estimates = MEDIUM. MVP scope is well-reasoned and internally consistent. |
| Architecture | MEDIUM | Convex Swift SDK patterns verified HIGH via official docs. UnifiedEvent merge pattern and TelegramService design are architectural inferences — well-reasoned but not directly sourced. `ObservableObject` recommendation over `@Observable` for Convex ViewModels is from official Convex docs. |
| Pitfalls | MEDIUM-HIGH | EventKit permission API, Convex numeric types, and timezone pitfalls verified from official Apple tech notes and Convex docs. Loom unreachability and sync duplicate pitfalls are architectural inferences backed by multiple community sources. OpenClaw Telegram polling reliability issues documented in GitHub issues. |

**Overall confidence:** MEDIUM

### Gaps to Address

- **HorizonCalendar on Mac:** Does `CalendarViewRepresentable` render acceptably in a native SwiftUI Mac target? This needs hands-on testing in Phase 1. If it fails, fallback is a custom SwiftUI calendar grid (estimate: 2-3 weeks additional work).
- **Convex Swift minimum version:** Package.swift not fully inspected. Verify before setting Xcode build settings — may constrain Swift 6 migration timeline.
- **Loom MCP configuration:** The recommended Telegram reply flow (Loom writes replies to Convex `chat_messages` table → iOS subscribes) requires Loom's Convex MCP to be configured with write access to that table. This is a coordination dependency between app schema design and Loom configuration that must be resolved before Phase 2 chat implementation begins.
- **Convex background behavior:** No documentation found on how ConvexMobile handles iOS background app refresh or subscription behavior when backgrounded. Needs testing in Phase 2 before notification implementation.
- **Studio sync pipeline timing:** The Supabase → Loom → Convex sync cadence (polling interval, reliability) is unspecified. Phase 3 planning should define an acceptable staleness window and surface it to the user if studio data is stale.
- **Recurring event expansion:** Convex works best with stored event instances, not raw RRULE strings. A bounded-future expansion strategy (e.g., pre-expand 6 months of instances) needs to be defined before the recurring events feature is built.

---

## Sources

### Primary (HIGH confidence)
- [Convex iOS/macOS Swift Docs](https://docs.convex.dev/client/swift) — ConvexMobile SDK, subscription patterns, data types, `@ConvexInt`/`@ConvexFloat`
- [convex-swift GitHub v0.8.0](https://github.com/get-convex/convex-swift) — verified active as of Feb 17, 2026
- [Convex Swift Data Types](https://docs.convex.dev/client/swift/data-types) — numeric type conversion gotchas
- [Apple EventKit Documentation](https://developer.apple.com/documentation/eventkit) — EKEventStore, permissions, EKEventStoreChanged
- [TN3153: Adopting EventKit API Changes in iOS 17](https://developer.apple.com/documentation/technotes/tn3153-adopting-api-changes-for-eventkit-in-ios-macos-and-watchos) — `requestFullAccessToEvents()` migration
- [TN3152: Migrating to Latest Calendar Access Levels](https://developer.apple.com/documentation/technotes/tn3152-migrating-to-the-latest-calendar-access-levels) — permission key changes
- [Telegram Bot API Reference v9.4](https://core.telegram.org/bots/api) — sendMessage, getUpdates patterns
- [Supabase Swift GitHub v2.41.1](https://github.com/supabase/supabase-swift/releases) — released Feb 6, 2026
- [Food Truck: SwiftUI Multiplatform Sample](https://developer.apple.com/documentation/SwiftUI/food-truck-building-a-swiftui-multiplatform-app) — iOS/macOS code sharing patterns
- [Morgen official features](https://www.morgen.so) — competitor feature reference
- [Fantastical features](https://flexibits.com/fantastical) — competitor feature reference
- [Things 3 features](https://culturedcode.com/things/features/) — competitor feature reference

### Secondary (MEDIUM confidence)
- [CalendarKit GitHub v1.1.11](https://github.com/richardtop/CalendarKit) — timeline view, Mac Catalyst support
- [HorizonCalendar GitHub](https://github.com/airbnb/HorizonCalendar) — monthly calendar grid, SwiftUI wrapper
- [clerk/clerk-convex-swift GitHub](https://github.com/clerk/clerk-convex-swift) — auth integration pattern
- [SwiftUI MVVM with ObservableObject](https://www.vadimbulavin.com/modern-mvvm-ios-app-architecture-with-combine-and-swiftui/) — ViewModels with Combine publishers
- [Convex Relationship Schemas](https://stack.convex.dev/relationship-structures-let-s-talk-about-schemas) — schema design patterns
- [iOS calendars — current vs autoupdatingCurrent](https://www.radude89.com/blog/ios-calendars.html) — timezone snapshot bug
- [Building Cross-Platform SwiftUI Apps](https://fatbobman.com/en/posts/building-multiple-platforms-swiftui-app/) — iOS/macOS conditional compilation
- [How to monitor system calendar changes with EventKit](https://nemecek.be/blog/63/how-to-monitor-system-calendar-for-changes-with-eventkit) — EKEventStoreChanged full reload behavior

### Tertiary (LOW confidence)
- [OpenClaw GitHub Issues #4942, #7327, #15082](https://github.com/openclaw/openclaw/issues) — Telegram polling reliability failures; needs validation against current OpenClaw version
- [AI calendar reviews (Reclaim, Motion, Clockwise)](https://reclaim.ai/compare/motion-alternative) — AI autonomy pitfall pattern; competitor marketing, use directionally only

---
*Research completed: 2026-02-20*
*Ready for roadmap: yes*
