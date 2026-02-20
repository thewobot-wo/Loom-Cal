---
phase: 01-foundation
plan: 01
subsystem: database
tags: [convex, typescript, supabase, cron, v.int64, bigint]

# Dependency graph
requires: []
provides:
  - "Convex schema with 4 tables: events, tasks, chat_messages, studio_events"
  - "CRUD functions for events and tasks (list, create, update, remove)"
  - "Chat message functions (list, send)"
  - "Studio events sync functions (list, syncFromSupabase, upsertAll)"
  - "15-minute cron job for Supabase studio events sync"
  - "npm project initialized with convex ^1.32.0"
affects: [02-swift-client, 03-calendar-ui, 04-ai-chat, 05-notifications]

# Tech tracking
tech-stack:
  added:
    - "convex ^1.32.0 — Convex TypeScript SDK and CLI"
    - "typescript ^5.9.3 — TypeScript compiler for local type checking"
    - "@types/node — Node.js type definitions for process/console globals"
  patterns:
    - "v.int64() for all integer fields (timestamps in ms, durations in minutes) — never v.number()"
    - "BigInt() explicit wrapping in all mutations writing v.int64() fields"
    - "internalAction + internalMutation pairing for external fetches with DB writes"
    - "Graceful cron error handling: log and return on fetch failure, no crash"
    - "Partial update mutations: v.optional() for all updatable fields, ctx.db.patch()"

key-files:
  created:
    - "convex/schema.ts — single source of truth for all table definitions"
    - "convex/events.ts — list, create, update, remove for events table"
    - "convex/tasks.ts — list, create, update, remove for tasks table"
    - "convex/chatMessages.ts — list, send for chat_messages table"
    - "convex/studioEvents.ts — list, syncFromSupabase, upsertAll for studio_events table"
    - "convex/crons.ts — 15-minute cron job for Supabase studio events sync"
    - "convex/_generated/server.ts — stub for local TypeScript checking (overwritten by npx convex dev)"
    - "convex/_generated/api.ts — stub for local TypeScript checking (overwritten by npx convex dev)"
    - "package.json — npm project with convex dependency"
    - "tsconfig.json — ES2022/ESNext/Bundler config for Convex compatibility"
    - ".gitignore — excludes node_modules, .env.local, dist, compiled _generated files"
  modified: []

key-decisions:
  - "Used v.int64() exclusively for all integer fields (start, duration, sentAt, dueDate, lastSyncedAt) — v.number() is float64 and causes Swift deserialization issues with BigInt"
  - "flagged field on tasks is boolean-only — no priority tiers (per user decision in CONTEXT.md)"
  - "Studio events deduplication uses title field match — TODO comment added to replace with Supabase PK once schema is known"
  - "Created _generated stubs (server.ts, api.ts) for local TypeScript type-checking before npx convex dev runs — stubs export generic Convex functions, overwritten on first deploy"
  - "syncFromSupabase handles both snake_case (is_all_day) and camelCase (isAllDay) Supabase field names for robustness"

patterns-established:
  - "BigInt pattern: all v.int64() writes use BigInt(value) — never plain numbers"
  - "Partial update pattern: spread args destructuring with id + ...updates, then ctx.db.patch(id, updates)"
  - "Internal sync pattern: internalAction fetches external data, calls ctx.runMutation(internal.X.upsertAll) for DB writes"
  - "Cron error isolation: try/catch in internalAction logs error and returns without re-throwing"

requirements-completed: [PLAT-05]

# Metrics
duration: 4min
completed: 2026-02-20
---

# Phase 1 Plan 01: Convex Backend Schema and Functions Summary

**Convex backend with 4-table schema (events, tasks, chat_messages, studio_events), full CRUD functions, and 15-minute Supabase studio events sync cron — all integer fields use v.int64() with BigInt()**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-20T10:17:24Z
- **Completed:** 2026-02-20T10:21:15Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments
- Defined the complete Convex schema as single source of truth for all table definitions; all Swift models in Plan 02 will derive from this
- Created full CRUD functions for events and tasks (list, create, update with partial patch, remove), plus list+send for chat_messages
- Built studio events sync infrastructure: syncFromSupabase internalAction fetches from Supabase with graceful error handling, upsertAll internalMutation writes with BigInt() on all int64 fields, cron job fires every 15 minutes server-side

## Task Commits

Each task was committed atomically:

1. **Task 1: Initialize npm project and define Convex schema** - `a2332ec` (feat)
2. **Task 2: Create query and mutation functions for all tables** - `42c42fa` (feat)

**Plan metadata:** (to be added after SUMMARY.md commit)

## Files Created/Modified
- `convex/schema.ts` — 4 tables: events (13 fields + 2 indexes), tasks (6 fields + 2 indexes), chat_messages (3 fields + 1 index), studio_events (7 fields + 1 index)
- `convex/events.ts` — list, create, update (partial), remove; v.int64() in create args
- `convex/tasks.ts` — list, create, update (partial), remove; flagged is boolean only
- `convex/chatMessages.ts` — list, send (stamps sentAt = BigInt(Date.now()))
- `convex/studioEvents.ts` — list, syncFromSupabase (internalAction), upsertAll (internalMutation)
- `convex/crons.ts` — 15-minute interval cron for syncFromSupabase
- `convex/_generated/server.ts` — stub re-exporting generic Convex functions for pre-deploy type checking
- `convex/_generated/api.ts` — stub providing typed `internal` and `api` exports for pre-deploy type checking
- `package.json` — npm project, convex ^1.32.0, typescript, @types/node as devDependencies
- `tsconfig.json` — ES2022/ESNext/Bundler, skipLibCheck, @types/node
- `.gitignore` — node_modules, .env.local, dist, compiled _generated .js/.d.ts files

## Decisions Made
- Used v.int64() for all integer fields — the research notes that v.number() is float64 which cannot safely represent millisecond timestamps at large values, and Swift's @ConvexInt wrapper only works with v.int64() fields
- flagged on tasks is a plain boolean with no priority tiers — user's explicit decision recorded in CONTEXT.md
- Studio events deduplication by title field for now — a TODO comment documents that this should be replaced with the actual Supabase primary key once the Supabase schema is confirmed
- Created _generated stubs rather than excluding the directory entirely — this lets the full TypeScript type-check pass before npx convex dev runs, reducing errors during development setup

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Created _generated stub files for TypeScript type-checking**
- **Found during:** Task 2 (creating function files)
- **Issue:** All function files import from `./_generated/server` and `./_generated/api`, which are created by `npx convex dev`. Without a live Convex project linked, these imports fail TypeScript checking entirely.
- **Fix:** Created minimal stub files in `convex/_generated/` that re-export Convex's generic functions (queryGeneric as query, etc.) and provide an AnyApi stub for `internal`. Updated tsconfig to ES2022/Bundler/skipLibCheck. Stubs pass full `tsc --noEmit` with zero errors.
- **Files modified:** `convex/_generated/server.ts`, `convex/_generated/api.ts`, `tsconfig.json`, `.gitignore`
- **Verification:** `npx tsc --noEmit` exits 0 with all 6 Convex files checked
- **Committed in:** 42c42fa (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Auto-fix was necessary to enable pre-deployment type checking. No scope creep. Stubs are documentation of the expected interface and will be overwritten by npx convex dev on first deploy.

## Issues Encountered
- `npx convex dev` requires an interactive login and Convex project link — this cannot be run non-interactively. The plan's `user_setup` section documents this as expected. Schema correctness was verified via TypeScript type-checking instead of live deployment.

## User Setup Required

Before the Convex backend is live, the following manual steps are required:

**1. Link the Convex project:**
```bash
npx convex dev
# Follow prompts to create a new project or link an existing one.
# This generates .env.local with CONVEX_URL and creates the real _generated/ files.
```

**2. Set environment variables in Convex Dashboard:**
- Go to Convex Dashboard > your project > Settings > Environment Variables
- Add `SUPABASE_EVENTS_URL` — e.g. `https://xxx.supabase.co/rest/v1/studio_events`
- Add `SUPABASE_ANON_KEY` — from Supabase Dashboard > Project Settings > API > anon/public key

**3. Verify deployment:**
- Convex Dashboard should show 4 tables: events, tasks, chat_messages, studio_events
- Cron Jobs section should show "sync studio events from Supabase" running every 15 minutes

## Next Phase Readiness
- Schema is the single source of truth — Swift models in Plan 02 (02-swift-client) derive directly from it
- All field types are locked: v.int64() for timestamps/durations, v.string() for text, v.boolean() for flags
- Pattern established: BigInt() in mutations, @ConvexInt in Swift structs — see RESEARCH.md Pattern 4
- Pending: User must run `npx convex dev` and set Supabase env vars before studio events sync functions can be tested

---
*Phase: 01-foundation*
*Completed: 2026-02-20*
