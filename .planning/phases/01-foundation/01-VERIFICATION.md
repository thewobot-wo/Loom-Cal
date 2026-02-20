---
phase: 01-foundation
verified: 2026-02-20T12:00:00Z
status: human_needed
score: 5/5 must-haves verified (automated)
human_verification:
  - test: "Launch app on iOS Simulator and confirm it connects to Convex without errors"
    expected: "App displays 'Loom Cal' title, Convex events section renders (even if empty), no crash in Xcode console"
    why_human: "Cannot run iOS Simulator or inspect Xcode console output programmatically"
  - test: "Verify real-time subscription delivers updates within 2 seconds"
    expected: "Run events:create mutation in Convex dashboard; new event appears in iOS Simulator list in under 2 seconds without manual refresh"
    why_human: "Real-time latency requires live runtime observation"
  - test: "Launch app on Mac target and confirm it connects to Convex without errors"
    expected: "App launches on Apple Silicon Mac via Designed for iPad mode, shows same events as iOS"
    why_human: "Cannot run macOS target or verify Mac-specific behavior programmatically"
  - test: "Verify EventKit permission prompt appears on iOS first launch"
    expected: "iOS permission sheet appears asking for calendar access; granting shows Apple Calendar section with event count; denying shows 'Calendar access not granted' with no crash"
    why_human: "Permission UI and graceful denial handling require live device/simulator testing"
---

# Phase 1: Foundation Verification Report

**Phase Goal:** The core infrastructure is correct and stable — Convex schema is defined, data ownership rules are locked, real-time subscriptions work, and the Swift client connects to Convex end-to-end
**Verified:** 2026-02-20T12:00:00Z
**Status:** human_needed — all automated checks pass; 4 items require live runtime confirmation
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (Success Criteria)

| #  | Truth | Status | Evidence |
|----|-------|--------|----------|
| 1  | SwiftUI app launches on both iOS and Mac and connects to Convex without errors | ? HUMAN | ConvexClient wired at `LoomCalApp.swift:6` with real URL `https://kindhearted-goldfish-658.convex.cloud`; runtime behavior needs live testing |
| 2  | Real-time Convex subscriptions deliver updates within 2 seconds | ? HUMAN | `subscribe(to: "events:list")` wired in `ContentView.swift:67`; latency needs live testing; user confirmed in Plan 02 human-verify checkpoint |
| 3  | Convex schema has tables for events, tasks, chat_messages, and studio_events with correct field types | ✓ VERIFIED | `convex/schema.ts` defines all 4 tables; `v.int64()` used for all integer fields; no `v.number()` found; UTC milliseconds and explicit timezone fields present |
| 4  | Source-of-truth ownership documented and enforced in schema | ✓ VERIFIED | Data ownership comment block in `convex/schema.ts` lines 3-10 documents all 5 sources; `studio_events` is read-only cache with `lastSyncedAt`; Convex-native `events` + `tasks` have full CRUD |
| 5  | EventKit permission uses `requestFullAccessToEvents()` and handles denial gracefully | ✓ VERIFIED | `EventKitService.swift:26` calls `store.requestFullAccessToEvents()`; `authStatus = .denied` on failure; comment on line 35: "No retry, no nag" |

**Score:** 3/5 truths fully verified programmatically; 2/5 require human runtime confirmation (but all code artifacts supporting those truths are substantive and wired correctly)

---

## Required Artifacts

### Plan 01-01 Artifacts (Convex Backend)

| Artifact | Status | Details |
|----------|--------|---------|
| `convex/schema.ts` | ✓ VERIFIED | 62 lines; defines all 4 tables with correct field types; data ownership comment block present |
| `convex/events.ts` | ✓ VERIFIED | 75 lines; exports `list`, `create`, `update`, `remove`; all `v.int64()` args declared; `ctx.db.patch()` for partial updates |
| `convex/tasks.ts` | ✓ VERIFIED | 61 lines; exports `list`, `create`, `update`, `remove`; `flagged` is `v.boolean()` (not priority tiers); `dueDate` uses `v.optional(v.int64())` |
| `convex/chatMessages.ts` | ✓ VERIFIED | 30 lines; exports `list`, `send`; `sentAt: BigInt(Date.now())` stamped in mutation |
| `convex/studioEvents.ts` | ✓ VERIFIED | 110 lines; exports `list`, `syncFromSupabase` (internalAction), `upsertAll` (internalMutation); error handling returns without crashing |
| `convex/crons.ts` | ✓ VERIFIED | 15 lines; `cronJobs()` with 15-minute interval calling `internal.studioEvents.syncFromSupabase` |

### Plan 01-02 Artifacts (Swift Client)

| Artifact | Status | Details |
|----------|--------|---------|
| `LoomCal/App/LoomCalApp.swift` | ✓ VERIFIED | Global `ConvexClient` singleton at file scope; `@StateObject EventKitService` injected as `.environmentObject` |
| `LoomCal/App/ConvexEnv.swift` | ✓ VERIFIED | Real deployment URL `https://kindhearted-goldfish-658.convex.cloud` (not placeholder) |
| `LoomCal/Models/LoomEvent.swift` | ✓ VERIFIED | 22 lines; `@ConvexInt var start`, `@ConvexInt var duration`; all 13 schema fields present |
| `LoomCal/Models/LoomTask.swift` | ✓ VERIFIED | 15 lines; `@OptionalConvexInt var dueDate`; `flagged: Bool` (no priority tiers) |
| `LoomCal/Models/ChatMessage.swift` | ✓ VERIFIED | 11 lines; `@ConvexInt var sentAt`; role as `String` |
| `LoomCal/Models/StudioEvent.swift` | ✓ VERIFIED | 16 lines; `@ConvexInt var start`, `@ConvexInt var duration`, `@ConvexInt var lastSyncedAt` |
| `LoomCal/Views/ContentView.swift` | ✓ VERIFIED | Substantive 80-line view; `subscribe(to: "events:list")` wired in `.task`; EventKitService used via `.environmentObject` |

### Plan 01-03 Artifacts (EventKit)

| Artifact | Status | Details |
|----------|--------|---------|
| `LoomCal/Services/EventKitService.swift` | ✓ VERIFIED | 84 lines; `requestFullAccessToEvents()` at line 26; `loadCalendars()`, `fetchEvents(from:to:)`, UserDefaults persistence all implemented |
| `LoomCal/LoomCal.entitlements` | ✓ VERIFIED | Contains `com.apple.security.app-sandbox = true` and `com.apple.security.personal-information.calendars = true` |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `convex/crons.ts` | `convex/studioEvents.ts` | `internal.studioEvents.syncFromSupabase` | ✓ WIRED | `crons.ts:12` references `internal.studioEvents.syncFromSupabase` directly |
| `convex/studioEvents.ts` | `convex/schema.ts` | `studio_events` table reads/writes | ✓ WIRED | `studioEvents.ts:11` queries `"studio_events"` table; `studioEvents.ts:98` inserts into it |
| `LoomCal/App/LoomCalApp.swift` | `ConvexMobile` | `import ConvexMobile + ConvexClient init` | ✓ WIRED | `LoomCalApp.swift:6`: `let convex = ConvexClient(deploymentUrl: ConvexEnv.deploymentUrl)` |
| `LoomCal/Views/ContentView.swift` | `convex/events.ts` | `subscribe(to: "events:list")` | ✓ WIRED | `ContentView.swift:67`: `.subscribe(to: "events:list")` with result decoded as `[LoomEvent]` |
| `LoomCal/Models/LoomEvent.swift` | `convex/schema.ts` | `@ConvexInt var start` | ✓ WIRED | `LoomEvent.swift:11`: `@ConvexInt var start: Int` matches `schema.ts:19`: `start: v.int64()` |
| `LoomCal/Services/EventKitService.swift` | `EventKit` | `EKEventStore.requestFullAccessToEvents()` | ✓ WIRED | `EventKitService.swift:26`: `try await store.requestFullAccessToEvents()` |
| `LoomCal/Views/ContentView.swift` | `LoomCal/Services/EventKitService.swift` | `@EnvironmentObject var eventKitService` | ✓ WIRED | `ContentView.swift:11` declares it; `ContentView.swift:62` calls `eventKitService.requestAccess()` |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| PLAT-05 | 01-01, 01-02, 01-03 | Real-time data sync via Convex subscriptions | ✓ SATISFIED | `subscribe(to: "events:list")` wired in ContentView; ConvexMobile 0.8.0 resolved and locked in `Package.resolved`; deployment URL real; user confirmed in Plan 02 human-verify checkpoint |

**Notes:**
- PLAT-05 is the only requirement mapped to Phase 1 in REQUIREMENTS.md (traceability table line 129)
- REQUIREMENTS.md marks it `[x]` (complete) and `Phase 1 | Complete`
- No orphaned requirements — all 3 plans claim PLAT-05; no additional Phase 1 requirements in REQUIREMENTS.md

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `convex/studioEvents.ts` | 77-78 | `TODO: Replace title match with Supabase primary key` | ℹ️ Info | Deduplication works but is fragile — fine for Phase 1; should be replaced when Supabase schema is confirmed |
| `LoomCal/App/ConvexEnv.swift` | 4 | `TODO: Use Xcode build configurations for dev/prod separation` | ℹ️ Info | Dev/prod URL separation deferred to later phase — acceptable for Phase 1 |

No blockers. No stub implementations. No empty handlers. Both TODOs are documented technical debt, not placeholders blocking the phase goal.

---

## Human Verification Required

All automated checks pass. The following 4 items require live runtime testing because they involve UI behavior, real-time latency, and platform-specific runtime conditions that cannot be verified by static code analysis.

### 1. iOS App Launch and Convex Connection

**Test:** Open `LoomCal.xcodeproj` in Xcode, select iPhone 16 Simulator, press Run
**Expected:** App launches showing "Loom Cal" title and Convex events section (even if empty "No events yet"); no errors or crashes in Xcode console
**Why human:** Cannot run iOS Simulator or read Xcode console output programmatically

### 2. Real-Time Subscription Latency

**Test:** With app running on iOS Simulator, open Convex dashboard at `https://dashboard.convex.dev`, navigate to the `kindhearted-goldfish-658` project, run `events:create` mutation with: `{ title: "Test", calendarId: "default", start: BigInt(Date.now()), duration: BigInt(60), timezone: "America/New_York", isAllDay: false }`
**Expected:** New event appears in the iOS app list within 2 seconds without manual refresh
**Why human:** Real-time latency measurement requires live observation; user confirmed this in Plan 02 human-verify checkpoint, but this verifier cannot independently confirm

### 3. Mac Target Launch

**Test:** In Xcode, select "My Mac (Designed for iPad)" destination, press Run
**Expected:** App launches on Mac, connects to same Convex deployment, shows same events
**Why human:** Cannot run macOS target programmatically; requires Apple Developer Team set in Signing & Capabilities

### 4. EventKit Permission Flow

**Test:** On a fresh iOS Simulator (reset with Device > Erase All Content and Settings), run the app
**Expected:** (a) Calendar permission dialog appears; (b) Granting shows "X events today" in Apple Calendar section; (c) Reset simulator, run again, deny — app shows "Calendar access not granted" with no crash
**Why human:** Permission dialogs require live device/simulator interaction; graceful denial handling requires behavioral observation

---

## Verified Commits

All commits documented in summaries exist in the repository:

| Commit | Description |
|--------|-------------|
| `a2332ec` | feat(01-01): initialize npm project and define Convex schema |
| `42c42fa` | feat(01-01): create Convex query/mutation functions for all tables |
| `21641ac` | feat(01-02): create SwiftUI multiplatform Xcode project with ConvexMobile |
| `a8b5280` | feat(01-02): define Swift Decodable models and add subscription proof-of-concept |
| `45c2c47` | feat(01-03): add EventKitService with permission flow and macOS entitlement |
| `ab89cb1` | feat(01-03): wire EventKitService into app and document data ownership |

---

## Summary

Phase 1 foundation is structurally complete. Every artifact exists, is substantive (not a stub), and is wired to adjacent components. The key design constraints are enforced in code:

- All Convex integer fields use `v.int64()` — confirmed zero instances of `v.number()` in `schema.ts`
- All Swift model fields for `v.int64()` use `@ConvexInt var` (or `@OptionalConvexInt var` for optional fields)
- EventKit permission uses `requestFullAccessToEvents()` (iOS 17+ API) at `EventKitService.swift:26`
- Denial handling is graceful: `authStatus = .denied`, comment explicitly says "No retry, no nag"
- ConvexClient singleton is a global `let` at file scope (not inside a ViewModel)
- Deployment URL is a real Convex cloud URL (`kindhearted-goldfish-658.convex.cloud`), not a placeholder
- ConvexMobile 0.8.0 is pinned in `Package.resolved`
- Data ownership is documented in `convex/schema.ts` lines 3-10 covering all 5 data sources
- macOS entitlement file correctly configures `com.apple.security.personal-information.calendars`
- Cron job is wired from `crons.ts` to `internal.studioEvents.syncFromSupabase` at 15-minute interval

The only items unresolvable by static analysis are live runtime behaviors (connection success, 2-second latency, permission dialog flow). The Plan 02 summary notes that the human-verify checkpoint (Task 3) was approved by the user confirming real-time sync on both iOS and Mac.

---

_Verified: 2026-02-20T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
