# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-20)

**Core value:** One app where you see everything on your plate — calendars, tasks, projects — and chat with Loom to actively manage your day.
**Current focus:** Phase 2 — Calendar Views

## Current Position

Phase: 2 of 8 (Calendar Views)
Plan: 1 of 3 in current phase
Status: In Progress — Plan 01 complete; calendar view infrastructure built
Last activity: 2026-02-20 — Plan 02-01 complete; CalendarViewModel, DayTimelineView, MiniMonthView, and supporting calendar views

Progress: [████░░░░░░] 20%

## Performance Metrics

**Velocity:**
- Total plans completed: 4
- Average duration: 5 min
- Total execution time: 0.32 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-foundation | 3 | 15 min | 5 min |
| 02-calendar-views | 1 (of 3) | 6 min | 6 min |

**Recent Trend:**
- Last 5 plans: 01-01 (4 min), 01-02 (7 min), 01-03 (4 min), 02-01 (6 min)
- Trend: Consistent 4-7 min per plan

*Updated after each plan completion*
| Phase 01-foundation P02 | 7 | 2 tasks | 11 files |
| Phase 01-foundation P03 | 4 | 2 tasks | 6 files |
| Phase 02-calendar-views P01 | 6 | 2 tasks | 8 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Pre-Phase 1]: Convex-native events only in v1 — no Apple Calendar (EventKit) or Supabase integration (deferred to v2)
- [Pre-Phase 1]: Telegram reply routing — Loom writes to Convex `chat_messages` table, iOS subscribes reactively (requires Loom MCP write access configured before Phase 4)
- [Pre-Phase 1]: All Convex integer fields use `v.int64()` / `@ConvexInt` in Swift — standard Int silently fails
- [Plan 01-01]: Studio events deduplication uses title field match — replace with Supabase PK once schema confirmed
- [Plan 01-01]: _generated stubs committed for pre-deploy TypeScript type-checking; overwritten by npx convex dev on first deploy
- [Plan 01-01]: syncFromSupabase handles both snake_case and camelCase Supabase field names for robustness
- [Phase 01-02]: ConvexMobile 0.8.0 confirmed compatible with Xcode 16.2/iOS 18.6 SDK — XCFramework links without errors (resolves RESEARCH open question)
- [Phase 01-02]: SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD used for Mac target — simpler for Phase 1; native Mac target deferred
- [Phase 01-02]: @OptionalConvexInt available in ConvexMobile 0.8.0 — used for LoomTask.dueDate (v.optional(v.int64()))
- [Phase 01-03]: com.apple.security.app-sandbox required alongside calendar entitlement for macOS privacy permissions to work
- [Phase 01-03]: EKAuthorizationStatus switch must include .writeOnly explicitly (iOS 17+ known case) to avoid exhaustiveness warning
- [Phase 01-03]: EventKit events NOT stored in Convex — read on-device via EventKitService, documented in schema.ts comments
- [Phase 02-calendar-views]: HorizonCalendar resolved at 1.16.0 (1.x not 2.x) — CalendarViewRepresentable is 2.x API only; used UIViewRepresentable wrapper instead
- [Phase 02-calendar-views]: ConvexMobile mutation args require [String: ConvexEncodable?] not [String: Any] — explicit type annotation required

### Pending Todos

- User must run `npx convex dev` to link Convex project and deploy schema/functions
- User must set SUPABASE_EVENTS_URL and SUPABASE_ANON_KEY in Convex Dashboard environment variables

### Blockers/Concerns

- [Phase 2 - PARTIALLY RESOLVED]: HorizonCalendar 1.16.0 integrated and building on iOS target; Mac target behavior unverified — MiniDayCellView is UIKit-based so Mac behavior still needs runtime testing
- [Phase 1 - RESOLVED]: ConvexMobile 0.8.0 confirmed compatible with Xcode 16.2 / iOS 18.6 SDK
- [Phase 4]: Loom MCP must have write access to `chat_messages` Convex table — coordinate Loom config before Phase 4 planning
- [Phase 5]: Convex background subscription behavior on iOS not documented — test in Phase 4/5 before notification implementation
- [Phase 1 - User Action Required]: npx convex dev must be run interactively to link Convex project and generate real _generated/ files

## Session Continuity

Last session: 2026-02-20
Stopped at: Plan 02-01 complete — calendar view infrastructure done; CalendarViewModel, DayTimelineView, MiniMonthView, TimelineEventCard, NowIndicatorView, AllDayBannerView all compile
Resume file: .planning/phases/02-calendar-views/02-02-PLAN.md (next: event CRUD UI)
