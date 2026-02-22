---
phase: 05-loom-calendar-and-task-actions
plan: 01
subsystem: backend
tags: [convex, schema, bridge, loom, actions, context-injection]
requirements: [LOOM-05, LOOM-06, LOOM-07]

dependency_graph:
  requires: [04-03]
  provides: [loom-action-schema, loom-context-endpoint, loom-pending-action-endpoint, bridge-context-injection, bridge-action-extraction]
  affects: [chat_messages-table, bridge-poll-loop]

tech_stack:
  added: []
  patterns:
    - JSON-in-text ACTION envelope for Loom replies (fallback for OpenClaw tool_calls limitation)
    - pending_action role on chat_messages for confirmation card flow
    - internalQuery for listForLoom on events and tasks (7-day window and incomplete filter)
    - System prompt context injection in bridge before each OpenClaw call
    - Graceful degradation in fetchContext (empty arrays on failure)

key_files:
  created: []
  modified:
    - convex/schema.ts
    - convex/chatMessages.ts
    - convex/events.ts
    - convex/tasks.ts
    - convex/http.ts
    - bridge/loom-bridge.mjs

decisions:
  - pending_action as a role value (not a separate table) — keeps chat stream unified in one subscription
  - ACTION JSON block at end of Loom reply — reliable fallback since OpenClaw doesn't pass tools to custom providers
  - fetchContext fresh per message (not cached) — prevents stale context for conflict detection
  - Filter pending_action messages from /pending-messages — prevents infinite reply loop
  - postLoomReply fallback in postPendingAction — degrades gracefully if pending-action endpoint fails
  - Timestamps in ACTION payloads as string ms — avoids JSON number precision issues for v.int64()

metrics:
  duration: 3 min
  completed: 2026-02-22
  tasks_completed: 2
  files_modified: 6
---

# Phase 05 Plan 01: Convex Backend and Bridge Extension for Loom Actions Summary

Extended Convex backend and bridge with action schema, context/action HTTP endpoints, and full bridge context injection + ACTION JSON extraction — enabling Loom to propose calendar and task mutations via a structured confirmation flow.

## What Was Built

### Task 1: Convex Schema and Backend Extensions

**convex/schema.ts** — Extended `chat_messages` table with:
- `role` union now includes `"pending_action"` (in addition to `"user"` and `"assistant"`)
- `action: v.optional(v.string())` — JSON string of the action payload for confirmation cards
- `actionStatus: v.optional(v.union("pending" | "confirmed" | "cancelled" | "undone"))` — full lifecycle tracking

**convex/chatMessages.ts** — Added two new functions:
- `writePendingAction` (internalMutation) — inserts a `pending_action` row with `action` JSON and `actionStatus: "pending"`
- `updateActionStatus` (mutation) — patches `actionStatus` on any chat message (called from iOS on Confirm/Cancel/Undo)

**convex/events.ts** — Added `listForLoom` (internalQuery):
- Returns events in a ±7-day window using `by_start` index range query
- Returns lightweight field subset: `_id, title, start, duration, timezone, isAllDay, location, calendarId, taskId`

**convex/tasks.ts** — Added `listForLoom` (internalQuery):
- Returns all incomplete tasks using `by_completed` index
- Returns: `_id, title, dueDate, priority, hasDueTime, completed, notes`

### Task 2: HTTP Endpoints and Bridge Extension

**convex/http.ts** — Added two new routes (kept existing `/loom-reply` and `/pending-messages`):
- `GET /loom-context` — runs `events.listForLoom` and `tasks.listForLoom` in parallel, returns `{ events, tasks }`
- `POST /loom-pending-action` — receives `{ displayText, action }`, calls `writePendingAction`, returns `{ ok: true }`
- Updated `/pending-messages` to filter out `pending_action` messages — prevents them from triggering a re-reply loop
- Fixed pre-existing TS type cast error in `/loom-reply` handler (Rule 1 - Bug: `body = await request.json()` typed as `unknown`)

**bridge/loom-bridge.mjs** — Major extension of `poll()` loop:
- `extractAction(replyText)` — regex `/ACTION:\s*```json\s*([\s\S]*?)```/` extracts and parses action JSON; strips block from display text
- `fetchContext()` — `GET /loom-context` with auth; degrades to `{ events: [], tasks: [] }` on failure
- `buildSystemPrompt(context)` — formats events and tasks into readable lines; defines 6 action types with full payload schemas; specifies ambiguity rules and timestamp format requirements
- `postLoomReply(content)` — extracted from inline code into reusable function
- `postPendingAction(displayText, action)` — `POST /loom-pending-action`; falls back to `postLoomReply` on failure
- Updated `poll()`: fetch context → build system prompt → forward to OpenClaw with system message prepended → extract action → route to `postPendingAction` or `postLoomReply`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed pre-existing TypeScript type cast in /loom-reply handler**
- Found during: Task 2 (TypeScript typecheck)
- Issue: `body = await request.json()` where `body` was typed as `{ content?: string }` — `request.json()` returns `unknown`, causing TS error TS2322
- Fix: Added explicit cast `(await request.json()) as { content?: string }`
- Files modified: `convex/http.ts`
- Commit: `2b04162`

**2. [Rule 2 - Missing Critical Functionality] Filter pending_action messages from /pending-messages**
- Found during: Task 2 (reasoning about message flow)
- Issue: Without filtering, a `pending_action` message would appear as the "last message" and trigger the bridge to send a new reply to a non-user message — infinite reply loop
- Fix: Added filter in `/pending-messages` handler to exclude `role === "pending_action"` before checking if last message is from user
- Files modified: `convex/http.ts`
- Commit: `2b04162`

## Verification Results

All 8 verification criteria passed:
1. TypeScript type-check: 0 errors (`npx tsc --noEmit`)
2. `schema.ts` has `pending_action`, `action`, `actionStatus` on `chat_messages`
3. `chatMessages.ts` exports `writePendingAction` (internalMutation) and `updateActionStatus` (mutation)
4. `events.ts` exports `listForLoom` (internalQuery) with 7-day window filter
5. `tasks.ts` exports `listForLoom` (internalQuery) filtering incomplete tasks
6. `http.ts` has `GET /loom-context` and `POST /loom-pending-action` routes
7. `bridge/loom-bridge.mjs` has all 5 required functions
8. Bridge poll() flow: fetch context → build system prompt → forward to OpenClaw → extract action → route to correct endpoint

## Commits

| Hash | Message |
|------|---------|
| `d0f44aa` | feat(05-01): extend Convex schema and backend for Loom action support |
| `2b04162` | feat(05-01): add Loom context/action endpoints and extend bridge |

## Self-Check: PASSED

All modified files exist and commits are verified in git log.
