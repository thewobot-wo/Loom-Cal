# Phase 1: Foundation - Research

**Researched:** 2026-02-20
**Domain:** Convex backend schema + Swift multiplatform client setup + EventKit permissions
**Confidence:** HIGH (core Convex/Swift stack verified via Context7 official docs; EventKit verified via Apple and community sources)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- Time stored as **start time + duration** (in minutes). End time is derived.
- Events carry: title, start (UTC ms), duration (minutes), timezone, location (optional text), notes (optional, markdown), url (optional, dedicated field for meeting links), color (optional, user-picked from palette), isAllDay boolean
- **Recurrence fields included in schema** — rrule string, recurrence group ID. Full RRULE support is desired for v1 (currently v2 as CALI-07 — see Deferred Ideas for roadmap promotion note)
- **File attachment fields included in schema** — array of file references. Upload/display UI deferred to a later phase
- Events belong to a **calendar/source concept** — each event has a calendarId linking to a named calendar. This supports future calendar sets and multi-source display
- Tasks carry: title, due date, flagged (boolean, not priority tiers), completed, notes (optional, markdown)
- **No priority levels** — just a boolean flagged marker
- File attachment fields included in schema (same as events, UI deferred)
- Studio events sourced from Supabase, **periodic background sync** into Convex (cron job or similar)
- Studio events: same fields as regular events — no studio-specific extra data
- Displayed **mixed on the calendar** alongside other events, visually distinguished by calendar/source
- Read-only in Convex — source of truth is Supabase
- **Read-only display in v1** — show Apple Calendar events on the calendar but no create/edit
- Read **directly from EventKit on-device** — no Convex caching. Events are always fresh but device-specific
- Request permission using `requestFullAccessToEvents()` (iOS 17+ API)
- On permission denial: **explain briefly and continue** — no nagging, app works with just Convex events
- On first EventKit grant: **user picks which Apple Calendar calendars to display** (selection screen)
- Calendar visibility preferences stored **locally in UserDefaults** (device-specific, no sync)
- Both event and task notes fields support **markdown rendering**
- App name: **Loom Cal** (two words)
- Bundle ID: **com.loomcal** (prefix)
- Target: **iOS 18+** and corresponding macOS version
- Apple Developer account with real team ID (ready for TestFlight)
- SwiftUI multiplatform — shared codebase for iOS and Mac

### Claude's Discretion

- Time-blocking implementation approach (separate event vs embedded in task)
- Exact Convex schema field types and indexing strategy
- Studio events sync frequency and error handling
- Compression/format for file attachment references
- Swift project folder structure and module organization

### Deferred Ideas (OUT OF SCOPE)

- **Full RRULE recurring events in v1** — Schema fields included in Phase 1 regardless; UI is deferred
- **Calendar sets / toggle visibility UI** (CALI-06) — Schema supports it via calendarId; toggle UI is v2
- **File attachment upload/display UI** — Schema fields included, upload interface deferred to a later phase
- **Apple Calendar write support** (CALI-01 write portion) — Read-only in v1, write deferred to v2
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PLAT-05 | Real-time data sync via Convex subscriptions | Verified: ConvexMobile Swift SDK uses Combine Publishers / async-await for subscriptions that auto-update on backend mutation. Sub-2-second delivery is the Convex design guarantee for reactive queries. Patterns documented in Code Examples section. |
</phase_requirements>

---

## Summary

Phase 1 establishes the full end-to-end infrastructure stack. There are three distinct technical domains: (1) the Convex backend — schema definition, TypeScript query/mutation functions, and cron-based Supabase sync; (2) the Swift multiplatform client — ConvexMobile SPM package, ConvexClient setup, SwiftUI subscription wiring, and the `@ConvexInt` wrapper for `v.int64()` fields; and (3) EventKit — iOS 17+ permission request API, Info.plist keys, and denial-graceful handling on iOS.

The biggest non-obvious risk is the `v.int64()` / `@ConvexInt` requirement. Convex stores 64-bit integers as JavaScript `BigInt`, which does not round-trip to Swift `Int` without the property wrapper — silent data corruption is the failure mode. Every integer field (timestamps in ms, duration in minutes) must use `v.int64()` in the schema and `@ConvexInt var` in the Swift struct. This is already noted as a pre-phase decision in STATE.md and must be enforced everywhere.

The second risk is EventKit on macOS: the permission model and Info.plist key names differ from iOS. The `NSCalendarsFullAccessUsageDescription` key must exist in the iOS target, but the macOS entitlement path (`com.apple.security.personal-information.calendars`) is separate. Since the app is multiplatform with shared code, EventKit calls must be wrapped in `#if canImport(EventKit)` or platform `#if os(iOS)` guards where behavior diverges.

**Primary recommendation:** Define the Convex schema first (single source of truth for all field names and types), generate TypeScript types with `npx convex dev`, then write Swift `Decodable` structs to match — never the reverse.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ConvexMobile (Swift) | SPM from `get-convex/convex-swift` | Swift client for Convex subscriptions/mutations | Official Convex Swift SDK; iOS 13+ / macOS 10.15+; built on UniFFI + Rust core |
| convex (npm) | latest via `npm install convex` | Backend schema, functions, CLI (`npx convex dev`) | Required — ships the Convex TypeScript runtime and codegen |
| EventKit (Apple) | Built-in (iOS 6+, iOS 17 new API) | Read Apple Calendar events on-device | Apple's framework — no alternative |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Combine (Apple) | Built-in | Power ConvexMobile subscriptions | Already used internally by ConvexMobile; use `.receive(on: DispatchQueue.main)` for UI updates |
| UserDefaults (Apple) | Built-in | Store EventKit calendar visibility preferences | Device-local, no sync required — correct fit |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `v.int64()` for timestamps | `v.number()` | `v.number()` is float64 — millisecond timestamps fit in float64 but integer arithmetic is unsafe at large values; `v.int64()` is explicit and round-trips correctly to Swift `@ConvexInt` |
| Combine-based subscription in ViewModel | async/await `.values` loop in View `.task` | Both work; ViewModel+ObservableObject is more testable; View `.task` is simpler for Phase 1 |
| Cron job in Convex for Supabase sync | Webhook push from Supabase | Cron is simpler to set up and self-contained in Convex; webhook requires Supabase-side config and HTTP action endpoint |

**Installation:**
```bash
# Backend (run in project root alongside Xcode project)
npm init -y
npm install convex
npx convex dev   # first run: creates Convex project, generates .env.local with CONVEX_URL

# Swift client: add via Xcode
# File > Add Package Dependencies > https://github.com/get-convex/convex-swift
# Target: ConvexMobile
```

---

## Architecture Patterns

### Recommended Project Structure

```
LoomCal/                         # Xcode multiplatform app root
├── convex/                      # Convex backend (TypeScript)
│   ├── schema.ts                # Single schema definition — source of truth
│   ├── events.ts                # Query/mutation functions for events table
│   ├── tasks.ts                 # Query/mutation functions for tasks table
│   ├── chatMessages.ts          # Query/mutation functions for chat_messages table
│   ├── studioEvents.ts          # Read-only queries + internal sync mutation
│   ├── crons.ts                 # Cron job wiring for Supabase sync
│   └── _generated/              # Auto-generated by `npx convex dev` — do not edit
├── LoomCal/                     # Shared SwiftUI source
│   ├── App/
│   │   ├── LoomCalApp.swift     # App entry point, ConvexClient singleton
│   │   └── ConvexEnv.swift      # Deployment URL constant
│   ├── Models/                  # Decodable structs matching Convex schema
│   │   ├── Event.swift
│   │   ├── Task.swift
│   │   ├── ChatMessage.swift
│   │   └── StudioEvent.swift
│   ├── Services/
│   │   └── EventKitService.swift  # EventKit wrapper, permission, calendar fetch
│   └── ...                      # Views, ViewModels (Phase 2+)
├── package.json
└── .env.local                   # CONVEX_URL — generated, do not commit
```

### Pattern 1: Global ConvexClient Singleton

**What:** One `ConvexClient` instance shared across the app lifecycle.
**When to use:** Always — the library requires a single client per process.

```swift
// Source: https://docs.convex.dev/quickstart/swift
// LoomCal/App/LoomCalApp.swift

import SwiftUI
import ConvexMobile

let convex = ConvexClient(deploymentUrl: ConvexEnv.deploymentUrl)

@main
struct LoomCalApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

```swift
// LoomCal/App/ConvexEnv.swift
struct ConvexEnv {
    static let deploymentUrl = "https://your-deployment.convex.cloud"
}
```

### Pattern 2: ViewModel with ObservableObject Subscription

**What:** Subscribe to Convex queries in an `ObservableObject` ViewModel; publish changes to SwiftUI.
**When to use:** Any screen that displays live Convex data. More testable than inline `.task` subscriptions.

```swift
// Source: https://docs.convex.dev/client/swift
import SwiftUI
import ConvexMobile

class EventsViewModel: ObservableObject {
    @Published var events: [Event] = []

    init() {
        convex.subscribe(to: "events:list")
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .assign(to: &$events)
    }
}
```

### Pattern 3: async/await Subscription in View (simpler, Phase 1 suitable)

**What:** Inline subscription using `.task` modifier and async sequence.
**When to use:** Simple screens; acceptable for Phase 1 proof-of-concept before ViewModel layer exists.

```swift
// Source: https://docs.convex.dev/quickstart/swift
struct ContentView: View {
    @State private var events: [Event] = []

    var body: some View {
        List(events, id: \._id) { event in
            Text(event.title)
        }
        .task {
            for await events: [Event] in convex
                .subscribe(to: "events:list")
                .replaceError(with: [])
                .values
            {
                self.events = events
            }
        }
    }
}
```

### Pattern 4: Decodable Swift Struct with @ConvexInt

**What:** Swift struct matching Convex schema, using `@ConvexInt` for all `v.int64()` fields.
**When to use:** Every table. Non-negotiable — omitting `@ConvexInt` causes silent deserialization failure for BigInt fields.

```swift
// Source: https://docs.convex.dev/client/swift/data-types
import ConvexMobile

struct Event: Decodable {
    let _id: String
    let calendarId: String
    let title: String
    @ConvexInt var start: Int          // UTC milliseconds — v.int64() in schema
    @ConvexInt var duration: Int       // minutes — v.int64() in schema
    let timezone: String
    let isAllDay: Bool
    let location: String?
    let notes: String?
    let url: String?
    let color: String?
    let rrule: String?
    let recurrenceGroupId: String?
    let attachments: [String]?
}
```

Note: Property wrappers (`@ConvexInt`) require `var`, not `let`.

### Pattern 5: Convex Schema Definition

**What:** `convex/schema.ts` defines all tables, field types, and indexes.
**When to use:** Define once in Phase 1; all other phases read/extend it.

```typescript
// Source: https://docs.convex.dev/database/schemas
// convex/schema.ts
import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  events: defineTable({
    calendarId: v.string(),
    title: v.string(),
    start: v.int64(),                          // UTC milliseconds
    duration: v.int64(),                       // minutes
    timezone: v.string(),                      // IANA timezone, e.g. "America/New_York"
    isAllDay: v.boolean(),
    location: v.optional(v.string()),
    notes: v.optional(v.string()),             // markdown plain text
    url: v.optional(v.string()),               // meeting link
    color: v.optional(v.string()),
    rrule: v.optional(v.string()),             // RRULE string for recurrence
    recurrenceGroupId: v.optional(v.string()), // links recurring instances
    attachments: v.optional(v.array(v.string())),
  })
    .index("by_calendar", ["calendarId"])
    .index("by_start", ["start"]),

  tasks: defineTable({
    title: v.string(),
    dueDate: v.optional(v.int64()),            // UTC milliseconds
    flagged: v.boolean(),
    completed: v.boolean(),
    notes: v.optional(v.string()),             // markdown plain text
    attachments: v.optional(v.array(v.string())),
  })
    .index("by_due_date", ["dueDate"])
    .index("by_completed", ["completed"]),

  chat_messages: defineTable({
    role: v.union(v.literal("user"), v.literal("assistant")),
    content: v.string(),
    sentAt: v.int64(),                         // UTC milliseconds
  })
    .index("by_sent_at", ["sentAt"]),

  studio_events: defineTable({
    calendarId: v.string(),                    // fixed: "studio" or similar
    title: v.string(),
    start: v.int64(),                          // UTC milliseconds
    duration: v.int64(),                       // minutes
    timezone: v.string(),
    isAllDay: v.boolean(),
    lastSyncedAt: v.int64(),                   // UTC ms — when this row was synced from Supabase
  })
    .index("by_start", ["start"]),
});
```

### Pattern 6: Supabase Sync via Cron + Internal Action

**What:** Scheduled Convex cron job triggers an internal action that fetches from Supabase and upserts into `studio_events`.
**When to use:** studio_events is read-only in Convex — source of truth is Supabase. Sync happens periodically (not on every user action).

```typescript
// convex/crons.ts
// Source: https://docs.convex.dev/scheduling/cron-jobs
import { cronJobs } from "convex/server";
import { internal } from "./_generated/api";

const crons = cronJobs();

crons.interval(
  "sync studio events from Supabase",
  { minutes: 15 },               // Claude's discretion: 15 min is reasonable for booking data
  internal.studioEvents.syncFromSupabase,
);

export default crons;
```

```typescript
// convex/studioEvents.ts (partial)
import { internalAction, internalMutation } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";

export const syncFromSupabase = internalAction({
  handler: async (ctx) => {
    const response = await fetch(process.env.SUPABASE_EVENTS_URL!, {
      headers: { apikey: process.env.SUPABASE_ANON_KEY! },
    });
    const rows = await response.json();
    await ctx.runMutation(internal.studioEvents.upsertAll, { rows });
  },
});

export const upsertAll = internalMutation({
  args: { rows: v.array(v.any()) },
  handler: async (ctx, { rows }) => {
    for (const row of rows) {
      // find existing by supabase ID or upsert
      const existing = await ctx.db
        .query("studio_events")
        .filter((q) => q.eq(q.field("title"), row.title))  // refine with real PK
        .first();
      if (existing) {
        await ctx.db.patch(existing._id, { lastSyncedAt: BigInt(Date.now()) });
      } else {
        await ctx.db.insert("studio_events", {
          calendarId: "studio",
          title: row.title,
          start: BigInt(row.start),
          duration: BigInt(row.duration),
          timezone: row.timezone ?? "UTC",
          isAllDay: false,
          lastSyncedAt: BigInt(Date.now()),
        });
      }
    }
  },
});
```

### Pattern 7: EventKit Permission (iOS 17+ API)

**What:** Request full calendar access using the new iOS 17 API, handle denial gracefully.
**When to use:** First time EventKit is needed; check status first before re-requesting.

```swift
// LoomCal/Services/EventKitService.swift
import EventKit

@MainActor
class EventKitService: ObservableObject {
    let store = EKEventStore()
    @Published var authStatus: EKAuthorizationStatus = .notDetermined

    func requestAccess() async {
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .notDetermined else {
            authStatus = status
            return
        }
        do {
            let granted = try await store.requestFullAccessToEvents()
            authStatus = granted ? .fullAccess : .denied
        } catch {
            // System error (e.g., restricted by MDM) — treat as denied
            authStatus = .denied
        }
    }

    // On denial: app continues with Convex-only events. No retry, no nag.
    var isAuthorized: Bool { authStatus == .fullAccess }
}
```

Info.plist entry required (add via Xcode target > Info > Custom iOS Target Properties):
```
Key:   NSCalendarsFullAccessUsageDescription
Value: "Loom Cal reads your Apple Calendar events to display them alongside your Loom events."
```

### Anti-Patterns to Avoid

- **Using `v.number()` for integer timestamps/durations:** `v.number()` is float64. Use `v.int64()` for all integer data. Swift will silently fail to decode `BigInt` fields without `@ConvexInt`.
- **Using `let` with `@ConvexInt`:** Property wrappers require `var`. The Swift compiler will error, but it's easy to miss in code review.
- **Creating multiple `ConvexClient` instances:** Only one per process. Use a global `let` constant at file scope, not inside a ViewModel init.
- **Calling `store.requestFullAccessToEvents()` on macOS:** On macOS, EventKit works differently. Wrap in `#if os(iOS)` if the behavior is iOS-only in Phase 1, or verify macOS entitlement is set.
- **Storing dates as `v.string()` (ISO 8601):** Convex docs recommend storing timestamps as numbers (milliseconds). Strings can't be indexed for range queries.
- **Using `Date.now()` in Convex query handlers:** Causes frequent cache invalidation. Store "current time" comparisons as mutations that stamp a field, query that field instead.
- **Hand-rolling the Supabase sync without an internal mutation:** Actions can fetch, but database writes must go through mutations for transactional integrity. Always `ctx.runMutation` from within an action.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Real-time data delivery to Swift client | Manual polling loop or WebSocket manager | `convex.subscribe(to:)` — ConvexMobile's built-in Combine publisher | Handles reconnect, multiplexing, differential updates automatically |
| Integer field serialization (BigInt ↔ Swift Int) | Custom Decodable implementation | `@ConvexInt` / `@OptionalConvexInt` property wrappers from ConvexMobile | Correct round-trip; custom impl is fragile to BigInt edge cases |
| Schema enforcement / field validation | Manual validation in mutation handlers | `v.` validator builder in `defineTable` — enforced by Convex runtime | Convex rejects writes that don't match schema; no extra code needed |
| Supabase → Convex sync scheduling | Timer in Swift app | `crons.interval()` in `convex/crons.ts` | Server-side — runs even when no client is connected; reliable |
| EventKit permission UI | Custom modal + NSUserDefaults | Standard `EKEventStore.requestFullAccessToEvents()` | OS manages single-prompt behavior; re-prompting is impossible anyway |

**Key insight:** ConvexMobile is thin but complete — the only things you write in Swift are your `Decodable` data structs and the call sites. Everything else (connection management, subscription multiplexing, error propagation) is inside the SDK.

---

## Common Pitfalls

### Pitfall 1: `v.int64()` Silently Failing in Swift

**What goes wrong:** Convex `v.int64()` fields serialize as JavaScript `BigInt` over the wire. Swift's standard `Codable` does not know how to decode `BigInt`. The field is silently `nil` or the decode fails at runtime with an opaque error — not a compile-time error.

**Why it happens:** The ConvexMobile SDK provides `@ConvexInt` to handle this, but there is no compiler enforcement if you forget it. If you define `let start: Int` instead of `@ConvexInt var start: Int`, the struct decodes with `start = 0` or throws.

**How to avoid:** Audit every `v.int64()` field in schema.ts and confirm there is a matching `@ConvexInt var` in the Swift struct. Add a `// MARK: ConvexInt required` comment pattern for reviewability.

**Warning signs:** Events appearing with `start = 0`, subscriptions returning empty arrays when the Convex dashboard shows data, or decoding errors in console logs.

### Pitfall 2: Unverified ConvexMobile Minimum Swift/Platform Version

**What goes wrong:** Package.swift for `convex-swift` declares `ios: .v13, macOS: .v10_15` as minimums. The app targets iOS 18+. However, the underlying XCFramework (`libconvexmobile-rs.xcframework`) is a pre-built binary — if it was compiled against a minimum that conflicts with Xcode 16 bitcode or simulator architectures, the build will fail with link errors.

**Why it happens:** STATE.md explicitly flags this: "ConvexMobile minimum Swift version not confirmed — verify before setting Xcode build settings."

**How to avoid:** In Phase 1, create the Xcode project, add the ConvexMobile package, and do a clean build for both iOS Simulator and Mac (Designed for iPad) immediately. Do not defer this validation. If it fails, check the `convex-swift` GitHub releases for a newer XCFramework.

**Warning signs:** Build errors referencing `libconvexmobile-rs.xcframework`, architecture `arm64` not found, or bitcode stripping failures.

### Pitfall 3: EventKit macOS vs iOS Permission Divergence

**What goes wrong:** On macOS, `EKEventStore.authorizationStatus(for:)` and `requestFullAccessToEvents()` exist but require a macOS entitlement (`com.apple.security.personal-information.calendars`) in the app sandbox, not just a plist key. Forgetting this means the macOS target crashes or silently returns `.denied` even before the user is prompted.

**Why it happens:** Multiplatform SwiftUI apps share code. The iOS plist key is not sufficient for macOS. The entitlement must be added to the Mac target's `.entitlements` file.

**How to avoid:** Phase 1 should conditionally gate EventKit: implement the full flow on iOS first. Add macOS entitlement explicitly. Test on both platforms before marking Phase 1 complete.

**Warning signs:** Permission prompt never appears on Mac; `authorizationStatus` returns `.denied` immediately on macOS with no user interaction.

### Pitfall 4: Multiple Convex Environment URLs (dev vs prod)

**What goes wrong:** `npx convex dev` generates `.env.local` with a dev deployment URL. If that URL is hardcoded into `ConvexEnv.swift`, the production build will point at the dev backend.

**Why it happens:** The Swift quickstart hardcodes the URL into source for simplicity.

**How to avoid:** In Phase 1, establish the pattern of using Xcode build configurations (Debug / Release) with `xcconfig` files or a build phase script to inject the correct URL. Alternatively, put dev/prod URLs in separate Swift files with target-membership control.

**Warning signs:** Production TestFlight builds hitting dev Convex backend (data mismatch, dev-only data visible).

### Pitfall 5: `BigInt` Insertion from TypeScript Sync Action

**What goes wrong:** When inserting into `studio_events` from a TypeScript action, `v.int64()` fields must be passed as JavaScript `BigInt` literals (e.g., `BigInt(Date.now())`), not plain numbers. Passing a plain number to a `v.int64()` field causes a Convex validation error at runtime.

**Why it happens:** TypeScript's type system won't always catch this — `BigInt` and `number` are both valid JS primitives.

**How to avoid:** In all Convex mutations that write `v.int64()` fields, use `BigInt(value)` explicitly. Add a comment in schema.ts: `// v.int64() fields require BigInt() in mutations`.

**Warning signs:** `ArgumentValidationError` in Convex dashboard logs when the sync cron runs; studio_events table remains empty.

---

## Code Examples

Verified patterns from official sources:

### ConvexClient Singleton + App Entry Point

```swift
// Source: https://docs.convex.dev/quickstart/swift
import SwiftUI
import ConvexMobile

let convex = ConvexClient(deploymentUrl: "https://your-deployment.convex.cloud")

@main
struct LoomCalApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

### Subscribe to Query with Combine (ViewModel pattern)

```swift
// Source: https://docs.convex.dev/client/swift
class EventsViewModel: ObservableObject {
    @Published var events: [Event] = []

    init() {
        convex.subscribe(to: "events:list")
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .assign(to: &$events)
    }
}
```

### Execute a Mutation

```swift
// Source: https://docs.convex.dev/client/swift
Task {
    try await convex.mutation("events:create", with: [
        "title": "Team Standup",
        "start": 1708416000000,   // NOTE: verify if Int or BigInt required here
        "duration": 30,
        "timezone": "America/New_York",
        "isAllDay": false,
        "calendarId": "default",
        "flagged": false,
        "completed": false,
    ])
}
```

### Define a Convex Query Function

```typescript
// Source: https://docs.convex.dev/database/schemas
// convex/events.ts
import { query } from "./_generated/server";

export const list = query({
  handler: async (ctx) => {
    return await ctx.db.query("events").withIndex("by_start").collect();
  },
});
```

### Define a Cron Job

```typescript
// Source: https://docs.convex.dev/scheduling/cron-jobs
import { cronJobs } from "convex/server";
import { internal } from "./_generated/api";

const crons = cronJobs();
crons.interval(
  "sync studio events",
  { minutes: 15 },
  internal.studioEvents.syncFromSupabase,
);
export default crons;
```

### EventKit Permission Request (iOS 17+)

```swift
// Source: https://developer.apple.com/documentation/eventkit + Apple TN3153
let store = EKEventStore()
do {
    let granted = try await store.requestFullAccessToEvents()
    // granted == true: show calendar picker
    // granted == false: show brief explanation, continue without EventKit
} catch {
    // System-level restriction — treat as denied
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `EKEventStore.requestAccess(to:completion:)` | `requestFullAccessToEvents()` async/await | iOS 17 / macOS 14 (WWDC 2023) | Old API deprecated; new API is async-native and requires `NSCalendarsFullAccessUsageDescription` plist key |
| `v.bigint()` alias | `v.int64()` (explicit alias) | Convex SDK (both are valid — `v.int64()` is preferred for clarity) | Functionally identical; prefer `v.int64()` to match Convex docs convention |
| React-based Convex queries (`useQuery`) | N/A for Swift — not applicable | — | SwiftUI uses ConvexMobile's Combine publisher, not React hooks |

**Deprecated/outdated:**
- `EKEventStore.requestAccess(to:completion:)`: Deprecated iOS 17. Still works but shows a deprecation warning in Xcode. App Store review may flag if targeting iOS 17+ SDK.
- `NSCalendarsUsageDescription` (old plist key): Replaced by `NSCalendarsFullAccessUsageDescription` (full access) or `NSCalendarsWriteOnlyAccessUsageDescription` (write only). For read-only display, only `NSCalendarsFullAccessUsageDescription` is needed since v1 reads all events.

---

## Open Questions

1. **ConvexMobile XCFramework compatibility with Xcode 16 / iOS 18 SDK**
   - What we know: Package.swift declares `ios: .v13` minimum. The binary XCFramework is pre-built Rust.
   - What's unclear: Whether the pre-built `libconvexmobile-rs.xcframework` ships arm64 slices compatible with macOS (Apple Silicon) builds and the iOS 18 simulator.
   - Recommendation: First task of Phase 1 must be "add package + build for iOS Simulator + Mac target." If it fails, open a GitHub issue on `get-convex/convex-swift` immediately.

2. **TypeScript BigInt mutation args from Swift**
   - What we know: Swift sends mutation args as JSON via ConvexMobile. JSON does not natively represent BigInt.
   - What's unclear: Whether ConvexMobile's Swift SDK automatically converts `Int` Swift values to Convex `BigInt` when the schema field is `v.int64()`, or whether mutations must pass a special type.
   - Recommendation: Test a mutation that writes to a `v.int64()` field in Phase 1 validation step. Check the Convex dashboard to confirm the value stored matches what was sent.

3. **Studio events Supabase API endpoint and credentials**
   - What we know: Supabase is the source of truth for studio booking data. A cron action in Convex will fetch it.
   - What's unclear: The Supabase project URL, anon key, and exact table/view name for studio events. These must be set as Convex environment variables before the cron runs.
   - Recommendation: Set `SUPABASE_EVENTS_URL` and `SUPABASE_ANON_KEY` in Convex environment (dashboard > Settings > Environment Variables) before testing the cron. The planner should include this as an explicit task.

4. **EventKit on macOS — scope of Phase 1**
   - What we know: The app is iOS + Mac multiplatform. EventKit exists on macOS. macOS requires a sandbox entitlement.
   - What's unclear: Whether Phase 1 should implement EventKit fully on both platforms or gate it to iOS only.
   - Recommendation: Implement EventKit on iOS in Phase 1. Add the macOS entitlement scaffolding (even if the Mac UI does not show Apple Calendar events yet). This prevents a surprise rewrite in a later phase.

---

## Sources

### Primary (HIGH confidence)
- `/llmstxt/convex_dev_llms_txt` (Context7) — schema validators (`v.int64`, `v.optional`, `v.union`), cron jobs, best practices (no `Date.now()` in queries), timestamp storage as number/ms
- `/get-convex/convex-swift` (Context7) — Swift client basic usage, `@ConvexInt` wrapper, `ConvexClient` init
- `https://docs.convex.dev/client/swift` (WebFetch) — ViewModel subscription pattern, async/await pattern, error handling, multiplatform note, SPM installation
- `https://docs.convex.dev/quickstart/swift` (via Context7 + WebFetch) — step-by-step setup, `ConvexClient` singleton, `struct Todo: Decodable` with `_id`
- `https://docs.convex.dev/client/swift/data-types` (WebFetch) — `@ConvexInt`, `@ConvexFloat`, `@OptionalConvexInt`, `var` requirement for wrappers, CodingKeys workaround for reserved words
- `https://raw.githubusercontent.com/get-convex/convex-swift/main/Package.swift` (WebFetch) — Swift tools version 5.10, iOS 13.0+, macOS 10.15+ platform requirements

### Secondary (MEDIUM confidence)
- `https://www.createwithswift.com/getting-access-to-the-users-calendar/` (WebFetch) — `requestFullAccessToEvents()` async/await pattern, `EKAuthorizationStatus` cases, Info.plist key names — verified against Apple doc references
- WebSearch (EventKit iOS 17) — `NSCalendarsFullAccessUsageDescription`, deprecation of `requestAccessToEntityType`, new write-only vs full-access split — consistent across multiple community and Apple sources
- WebSearch (Convex Actions pattern) — actions for external fetch + `ctx.runMutation` for DB writes — confirmed by Context7 Convex docs

### Tertiary (LOW confidence)
- Specific Supabase API format for studio events fetch endpoint — not verified; project-specific, depends on actual Supabase schema
- Whether ConvexMobile Swift SDK auto-converts `Int` to `BigInt` in mutation args — not confirmed by docs; needs empirical test in Phase 1

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — ConvexMobile SPM package, `convex` npm, EventKit all verified via official sources
- Convex schema patterns: HIGH — all field types verified via Context7 official Convex docs
- Swift subscription patterns: HIGH — verified via Context7 + official docs.convex.dev
- `@ConvexInt` requirement: HIGH — verified in both Context7 and official data-types page
- Cron/sync pattern: HIGH — cron API verified via Context7; Supabase-specific endpoint is LOW
- EventKit iOS 17 API: MEDIUM-HIGH — `requestFullAccessToEvents()` confirmed; macOS entitlement path is MEDIUM (community sources, consistent)
- Phase 1 pitfalls: MEDIUM — based on STATE.md known concerns + documented SDK behavior

**Research date:** 2026-02-20
**Valid until:** 2026-04-20 (60 days — Convex SDK updates periodically; EventKit iOS policy is stable)
