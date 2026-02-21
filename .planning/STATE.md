# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-20)

**Core value:** One app where you see everything on your plate — calendars, tasks, projects — and chat with Loom to actively manage your day.
**Current focus:** Phase 3 — Task System

## Current Position

Phase: 3 of 8 (Task System)
Plan: 4 of 4 in current phase — COMPLETE
Status: Phase 3 COMPLETE — all 4 plans executed; drag-to-time-block, complete task system human-verified
Last activity: 2026-02-21 — Plan 03-04 complete (5 min)

Progress: [█████░░░░░] 44%

## Performance Metrics

**Velocity:**
- Total plans completed: 9
- Average duration: 5.67 min
- Total execution time: 0.85 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-foundation | 3 | 15 min | 5 min |
| 02-calendar-views | 3 | 25 min | 8 min |
| 03-task-system | 4 | 17 min | 4.25 min |

**Recent Trend:**
- Last 5 plans: 03-01 (3 min), 03-02 (4 min), 03-03 (5 min), 03-04 (5 min)
- Trend: 3-5 min per plan; consistent velocity

*Updated after each plan completion*

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
- [Plan 02-02]: EventEditView passes @Binding isDetailPresented to parent EventDetailView — sets both false on successful save to auto-dismiss the full event sheet chain
- [Plan 02-02]: NL parsing fires on .onSubmit (not onChange debounce) — simpler, avoids parsing on every keystroke
- [Plan 02-03]: LoomEvent Identifiable via computed var id: String { _id } — avoids CodingKeys issues with @ConvexInt wrapper properties
- [Plan 02-03]: Swipe navigation uses abs(xDelta) > abs(yDelta) disambiguation — prevents day navigation during vertical timeline scroll
- [Plan 02-03]: WeekTimelineView narrow column threshold 60pt — below that, colored bar only (no text)
- [Plan 02-03]: GeometryReader must be ROOT view (outside ScrollView) — GeometryReader inside ScrollView prevents scrolling
- [Plan 02-03]: Color.clear spacer needed as first ZStack child in ScrollView — offset-positioned children don't report correct content height
- [Plan 02-03]: Mini month hidden in week mode — week header IS the navigation, eliminates redundant double-calendar
- [Plan 02-03]: End time pickers replace duration picker — no artificial cap, more natural time entry
- [Plan 02-03]: .alert replaces .confirmationDialog for delete — more reliable in nested sheet contexts
- [Plan 02-03]: HorizonCalendar needs platformFilters = (ios, ) — UIKit dependency fails macOS build
- [Plan 02-03]: Cross-platform colors: Color.gray.opacity(0.15) replaces Color(.systemGray5), .background replaces Color(.systemBackground)
- [Plan 03-01]: priority union (high/medium/low) replaces flagged:boolean — enables sorting/filtering by tier
- [Plan 03-01]: hasDueTime:boolean separates date-only tasks from time-specific tasks within same dueDate field
- [Plan 03-01]: taskId on events table links time-blocked calendar events back to source task
- [Plan 03-01]: LoomTask.Identifiable via computed var id: String { _id } — matches LoomEvent pattern
- [Plan 03-02]: TaskRowView uses .buttonStyle(.plain) on completion circle — prevents row-tap interference
- [Plan 03-02]: TaskDetailView saveChanges uses explicit Color.secondary/Color.blue to avoid HierarchicalShapeStyle ambiguity
- [Plan 03-02]: hasDueDate=false→dueDate=nil; hasDueDate+!hasDueTime→Calendar.startOfDay — consistent with TaskViewModel date filtering
- [Phase 03]: TodayView uses TimelineItem enum for type-erased event+task interleaving in ZStack timeline
- [Phase 03]: Toolbar + button upgraded to Menu (New Event / New Task) — single entry point for both creation flows
- [Plan 03-04]: LongPressGesture(0.2s).sequenced(before: DragGesture(global)) — drag source above ScrollView, avoids scroll conflict
- [Plan 03-04]: TimelineContentOriginKey PreferenceKey computes scroll offset without iOS 26+ ScrollPosition.y
- [Plan 03-04]: isTimeBlock param on TimelineEventCard switches orange/blue styling — single view, single styling source
- [Plan 03-04]: Orange for time-blocked events, blue for regular events — task-linked visual hierarchy

### Pending Todos

- User must run `npx convex dev` to link Convex project and deploy schema/functions
- User must set SUPABASE_EVENTS_URL and SUPABASE_ANON_KEY in Convex Dashboard environment variables

### Blockers/Concerns

- [Phase 2 - RESOLVED]: HorizonCalendar 1.16.0 with platformFilters = (ios, ); macOS uses LazyVGrid fallback via #if canImport(UIKit) guard
- [Phase 1 - RESOLVED]: ConvexMobile 0.8.0 confirmed compatible with Xcode 16.2 / iOS 18.6 SDK
- [Phase 4]: Loom MCP must have write access to `chat_messages` Convex table — coordinate Loom config before Phase 4 planning
- [Phase 5]: Convex background subscription behavior on iOS not documented — test in Phase 4/5 before notification implementation
- [Phase 1 - User Action Required]: npx convex dev must be run interactively to link Convex project and generate real _generated/ files

## Session Continuity

Last session: 2026-02-21
Stopped at: Phase 3 plan 03-04 complete — drag-to-time-block, visual distinction, undo banner, Phase 3 human-verified
Resume file: Continue to Phase 4 — Loom AI chat (requires Loom MCP write access configured)
