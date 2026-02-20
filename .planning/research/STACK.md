# Stack Research

**Domain:** Native iOS + Mac calendar/task management app with AI assistant integration
**Researched:** 2026-02-20
**Confidence:** MEDIUM-HIGH (core stack verified via official docs; Telegram integration pattern is MEDIUM confidence)

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| SwiftUI (multiplatform) | iOS 17+ / macOS 14+ | UI framework for iOS and Mac | Single codebase for both platforms. iOS 17+ baseline unlocks SwiftData, @Observable, and the full modern API surface. Mac runs as a native SwiftUI app (not Catalyst). |
| Swift 6 | 6.x | Language | Strict concurrency checking catches data race bugs at compile time. Convex Swift SDK is built with Swift 6 in mind (ios-convex-workout example uses Swift 6). Non-negotiable for new projects in 2025+. |
| ConvexMobile (Swift SDK) | 0.8.0 | Backend client — real-time queries, mutations, actions | Official Convex Swift client. Built on Rust client (Tokio runtime). Exposes Combine Publishers for reactive UI updates. Actively maintained (last commit Feb 17, 2026). Non-negotiable per project constraints. |
| Apple EventKit | System (iOS 17+) | Read/write Apple Calendar events and reminders | Only way to access Apple Calendar data on-device. EKEventStore is the single entry point. Requires NSCalendarsFullAccessUsageDescription in Info.plist. requestFullAccessToEvents() is the iOS 17+ API. |
| UserNotifications | System (iOS 17+) | Local and remote push notifications for events and task reminders | Apple's unified notification framework. Works for both local scheduling and APNs remote push. Required for reminders and time-sensitive calendar alerts. |
| SwiftData | iOS 17+ | Local cache / offline data layer | Best choice for new SwiftUI-native projects (Apple's active investment). Handles local caching of Convex data for offline-tolerant reads. @Query integrates cleanly with SwiftUI views. If iOS 16 support becomes needed, fall back to Core Data. |

### Convex Backend (TypeScript)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Convex | Latest (cloud) | Backend platform — database, functions, real-time sync | Non-negotiable per project constraints. Provides schema-validated database, server functions (queries/mutations/actions), real-time WebSocket sync, and scheduled jobs. All app data (events, tasks, projects, chat history) lives here. |
| Convex Actions | — | Outbound HTTP calls from backend | Use for: calling Telegram Bot API server-side (forwarding app messages to Loom), fetching from Supabase. Actions run in Convex cloud, not on device. |
| Convex Scheduled Functions | — | Background sync and reminders | Trigger Supabase → Convex sync on a schedule (e.g., every 5 minutes for vocal studio calendar updates). |

### External Integrations

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Telegram Bot API (HTTP) | Bot API 9.4 | Communication channel between app and Loom AI | Loom already runs as a Telegram bot. The iOS app calls Bot API directly via URLSession: POST to `https://api.telegram.org/bot<TOKEN>/sendMessage` to send user input to Loom's chat. For receiving Loom's replies: poll `getUpdates` or route replies through Convex (recommended — see architecture note below). |
| Supabase Swift SDK | 2.41.1 | Read-only access to vocal studio calendar data | Supabase hosts the studio calendar. App reads it directly (or via Convex sync). SDK supports iOS 13+, latest release Feb 6, 2026. Use only `postgrest` module — no auth, realtime, or storage needed from the app side. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| HorizonCalendar (Airbnb) | 1.x (SPM "from: 1.0.0") | High-performance calendar UI component | Use for the main calendar grid view. Battle-tested in Airbnb's production app. Supports month/week views, range selection, custom day decorators. Has SwiftUI wrapper (`CalendarViewRepresentable`). NOT macOS native — evaluate if Mac layout needs custom work. |
| CalendarKit | 1.1.11 (Nov 2024) | Day/week timeline view (Apple Calendar-style) | Use for the day-view timeline with time slots. UIKit-based (use UIViewRepresentable wrapper). Supports Mac Catalyst. Good for showing time-blocked events in hour-row layout. |
| Clerk + ClerkConvex Swift | Latest (SPM) | Authentication | Only needed if the app requires user accounts beyond local device access. Clerk integrates directly with Convex's auth system via OIDC. Official `clerk/clerk-convex-swift` package exists. Defer until multi-user or iCloud sync is required — v1 may be single-user local. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Xcode 16+ | IDE and build system | Required for Swift 6 and SwiftData. Use multiplatform app target (not separate iOS + macOS targets) to maximize code sharing. |
| Convex CLI (`npx convex`) | Backend development and deployment | Run `npx convex dev` during development for live backend sync. Defines schema in TypeScript. |
| Swift Package Manager | Dependency management | All libraries installed via SPM. No CocoaPods or Carthage — SPM is the 2025 standard. |
| Xcode Previews | UI iteration | Central to SwiftUI development speed. Use mock data and preview providers for calendar and task views. |
| Thread Sanitizer | Concurrency debugging | Enable during development to catch Swift 6 data race issues before they ship. |

---

## Installation

```bash
# Convex backend (in project root or /backend folder)
npm install convex
npx convex dev

# iOS — all via Xcode SPM (File > Add Package Dependencies)
# ConvexMobile:    https://github.com/get-convex/convex-swift        (0.8.0)
# Supabase Swift:  https://github.com/supabase/supabase-swift        (2.41.1)
# HorizonCalendar: https://github.com/airbnb/HorizonCalendar         (from: 1.0.0)
# CalendarKit:     https://github.com/richardtop/CalendarKit         (1.1.11)

# Optional (auth, add later):
# ClerkConvex:     https://github.com/clerk/clerk-convex-swift       (latest)
```

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| SwiftUI multiplatform | Mac Catalyst (iOS app on Mac) | Never for this project — Catalyst APIs are incomplete and produce a less-native experience. SwiftUI multiplatform gives true Mac idioms. |
| SwiftData (local cache) | Core Data | If iOS 16 support becomes a requirement (unlikely for new 2025 project). Also if complex migration paths or derived attributes are needed. |
| HorizonCalendar | Custom SwiftUI calendar built from scratch | If HorizonCalendar's Mac behavior is inadequate and CalendarKit doesn't meet timeline needs. Building custom is ~2-3 weeks of UI work. |
| CalendarKit (timeline view) | Custom time-slot grid | If CalendarKit UIViewRepresentable wrapper causes layout issues on Mac. CalendarKit supports Mac Catalyst, not pure SwiftUI Mac. |
| Direct Bot API HTTP calls (URLSession) | Third-party Telegram Swift SDK | Third-party SDKs (swift-telegram-sdk, rapierorg/telegram-bot-swift) are server-side bot frameworks, not iOS client libraries. Direct URLSession calls are 10 lines of code and have no dependencies. |
| Convex Actions (server-side Telegram relay) | Direct iOS → Telegram API calls | Direct calls work for sending messages, but receiving Loom's replies requires either polling from the app or routing Loom's responses through Convex (so iOS can subscribe reactively). Convex Actions + storing chat in Convex is the correct pattern. |
| @Observable (Swift macros) | TCA (Composable Architecture) | TCA is justified for large teams or very complex state machines. For a solo project, native @Observable + focused view models is lower overhead and fully adequate. TCA adds significant learning curve with reducers and stores. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| FSCalendar | UIKit-only, last meaningful update was 2022, requires UIViewRepresentable wrapper with no advantage over CalendarKit | CalendarKit for timeline, HorizonCalendar for monthly grid |
| Mac Catalyst | Broken/missing APIs, doesn't feel native on Mac, community consistently reports poor experience | SwiftUI multiplatform target |
| Alamofire | Adds a large dependency for HTTP calls that URLSession handles natively in Swift concurrency (async/await) | URLSession with async/await |
| Firebase | Google product with different data model, conflicts with Convex as the backend | Convex (non-negotiable) |
| Apollo GraphQL | Convex has its own typed function system — GraphQL layer adds complexity without benefit | ConvexMobile SDK direct function calls |
| Third-party Telegram bot Swift SDKs (nerzh/swift-telegram-sdk, rapierorg/telegram-bot-swift) | These are SERVER-SIDE bot frameworks designed to run on Linux/Vapor. They are not iOS client libraries and don't belong in an iOS app. | Direct URLSession HTTP calls to Telegram Bot API |
| CocoaPods / Carthage | Deprecated workflows in 2025. SPM is first-class in Xcode | Swift Package Manager |
| Core Data (new code) | SwiftData supersedes Core Data for new SwiftUI projects. @Query + @Model is cleaner and Apple-native | SwiftData |

---

## Stack Patterns by Variant

**For real-time Convex data in SwiftUI views:**
- Subscribe via `convex.subscribe("queryName", args)` returning a Combine Publisher
- Pipe into `@State` via `.sink` or wrap in an `@Observable` ViewModel
- Because Convex uses Tokio internally, all calls are main-actor safe

**For sending a message to Loom (Telegram):**
- App POSTs to `https://api.telegram.org/bot<TOKEN>/sendMessage` with the user's `chat_id` and text
- Convex Action (server-side) handles this POST — keeps bot token off the iOS device
- Loom receives the message, processes it, and writes its response back to Convex via the Convex MCP
- iOS app receives Loom's reply via its Convex query subscription (reactive, no polling needed)

**For vocal studio calendar sync:**
- Loom (running on local gateway) uses Supabase MCP + Convex MCP to sync studio events into Convex
- iOS app reads studio events from Convex — no direct Supabase SDK needed in the app if sync is complete
- Include Supabase Swift SDK as fallback for direct read if Loom sync is lagging

**For Apple Calendar integration:**
- Create single `EKEventStore` instance at app startup
- Request `requestFullAccessToEvents` permission on first launch
- Subscribe to `EKEventStoreChanged` notifications to detect external calendar changes
- Merge EKEvent data with Convex events in the ViewModel layer before display

**For offline / Loom unreachable scenarios:**
- Convex Swift SDK uses WebSocket — connection drops gracefully
- SwiftData local cache ensures calendar/task data remains readable offline
- Loom unavailability is expected (local gateway) — show "Loom offline" status in chat UI
- Queue outbound messages locally and retry when connection restored

---

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| ConvexMobile 0.8.0 | iOS 14+, macOS 11+ | Built on Rust/Tokio. Check Package.swift for exact minimum. Likely requires Swift 5.9+. |
| supabase-swift 2.41.1 | iOS 13+, macOS 10.15+ | Modular — only add `PostgREST` module to avoid pulling in auth/realtime. |
| HorizonCalendar | iOS 11+ | No explicit macOS support. Needs evaluation on Mac target. |
| CalendarKit 1.1.11 | iOS 11+, macOS 10.15+ (Catalyst) | UIKit-based, uses UIViewRepresentable in SwiftUI. |
| SwiftData | iOS 17+, macOS 14+ | Hard minimum. Sets deployment target for the whole project. |
| EventKit | iOS 6+, macOS 10.8+ | requestFullAccessToEvents() requires iOS 17+/macOS 14+. |

**Deployment target recommendation:** iOS 17 / macOS 14. This unlocks SwiftData, @Observable, requestFullAccessToEvents(), and the full 2023+ API surface. The tradeoff (dropping iOS 16) is acceptable for a greenfield 2025 personal app.

---

## Sources

- [Convex iOS/macOS Swift Docs](https://docs.convex.dev/client/swift) — ConvexMobile capabilities, authentication patterns (MEDIUM confidence — some gaps in docs re: push notifications and background behavior)
- [convex-swift GitHub](https://github.com/get-convex/convex-swift) — version 0.8.0, updated Feb 17 2026 (HIGH confidence)
- [clerk/clerk-convex-swift GitHub](https://github.com/clerk/clerk-convex-swift) — Clerk auth integration pattern (MEDIUM confidence)
- [Supabase Swift GitHub Releases](https://github.com/supabase/supabase-swift/releases) — version 2.41.1, released Feb 6 2026 (HIGH confidence)
- [Telegram Bot API docs](https://core.telegram.org/bots/api) — Bot API 9.4, sendMessage/getUpdates patterns (HIGH confidence for HTTP API; MEDIUM confidence for recommended iOS integration pattern — this is an architectural inference, not a documented Telegram pattern)
- [HorizonCalendar GitHub](https://github.com/airbnb/HorizonCalendar) — iOS-focused, SwiftUI wrapper available, battle-tested (MEDIUM confidence — Mac support is unclear)
- [CalendarKit GitHub](https://github.com/richardtop/CalendarKit) — v1.1.11, UIKit-based, Mac Catalyst supported (HIGH confidence)
- [Apple EventKit WWDC23](https://developer.apple.com/videos/play/wwdc2023/10052/) — Current permission model (HIGH confidence)
- WebSearch: SwiftData vs Core Data 2025 — multiple sources agree SwiftData is recommended for new iOS 17+ projects (MEDIUM confidence — community consensus, not Apple official statement)
- WebSearch: TCA vs @Observable 2025 — multiple sources; @Observable recommended for solo projects (MEDIUM confidence)

---

## Open Questions / Flags for Phase Research

1. **HorizonCalendar on Mac:** Does `CalendarViewRepresentable` render correctly in a SwiftUI Mac target (not Catalyst)? Needs hands-on verification in Phase 1.

2. **Convex Swift SDK minimum Swift version:** Package.swift not fully inspected. Verify Swift version requirement before setting Xcode build settings.

3. **Telegram reply routing:** The recommended pattern (Loom writes reply to Convex → iOS subscribes) requires Loom's Convex MCP to write to a `chat_messages` table. This is an architectural dependency between Loom's MCP configuration and the Convex schema — needs coordination in Phase 1 design.

4. **Convex Swift background behavior:** No documentation found on how ConvexMobile handles iOS background app refresh or what happens to subscriptions when the app is backgrounded. Needs testing in Phase 2.

5. **Bot token security:** Keeping the Telegram bot token server-side (in Convex environment variables) is architecturally correct but requires Convex Actions to proxy all Telegram calls. Verify Convex environment variable support and action latency before committing to this pattern.

---

*Stack research for: Loom Cal — native iOS + Mac calendar/task management with Convex + Telegram AI integration*
*Researched: 2026-02-20*
