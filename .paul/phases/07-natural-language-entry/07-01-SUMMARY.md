---
phase: 07-natural-language-entry
plan: 01
subsystem: api
tags: [convex, nlparse, bridge, openclaw, natural-language]

requires:
  - phase: 05-loom-actions
    provides: Bridge architecture (polling + OpenClaw call pattern)
  - phase: 06-ai-daily-planning
    provides: Bridge poll loop structure, ACTION block parsing
provides:
  - parse_requests Convex table for NL request/response lifecycle
  - /pending-parse and /parse-result HTTP endpoints
  - Bridge NL parse processing via OpenClaw with focused prompts
  - nlParse.ts module (createParseRequest, getResult, oldestPending, updateResult, cleanup)
affects: [07-02 Swift NLParseService]

tech-stack:
  added: []
  patterns: [ephemeral request/response via Convex table, opportunistic cleanup]

key-files:
  created: [convex/nlParse.ts]
  modified: [convex/schema.ts, convex/http.ts, bridge/loom-bridge.mjs]

key-decisions:
  - "Opportunistic cleanup in /parse-result instead of cron job"
  - "Parse requests independent of chat processing lock"
  - "Focused stateless prompts (no chat history, no calendar context)"

patterns-established:
  - "Ephemeral Convex table for request/response lifecycle (client creates, bridge resolves, cleanup purges)"
  - "checkParseRequests() runs before chat check in poll() but outside processing lock"

duration: ~15min
started: 2026-02-22
completed: 2026-02-22
---

# Phase 7 Plan 01: NL Parse Backend Summary

**Convex parse_requests table, HTTP endpoints, and bridge OpenClaw integration for natural language event/task parsing**

## Performance

| Metric | Value |
|--------|-------|
| Duration | ~15 min |
| Started | 2026-02-22 |
| Completed | 2026-02-22 |
| Tasks | 2 completed |
| Files modified | 4 |

## Acceptance Criteria Results

| Criterion | Status | Notes |
|-----------|--------|-------|
| AC-1: Parse Request Created in Convex | Pass | `createParseRequest` mutation inserts with status "pending", createdAt, requestId |
| AC-2: Bridge Detects and Processes Parse Requests | Pass | `checkParseRequests()` polls /pending-parse, calls OpenClaw with focused prompt, posts result |
| AC-3: Parse Result Stored and Queryable | Pass | `getResult` query returns document by requestId; Swift can subscribe reactively |
| AC-4: Error Handling and Timeout Resilience | Pass | OpenClaw errors → status "error" via postParseResult; try/catch wraps entire flow |

## Accomplishments

- Built complete NL parse request lifecycle: create → pending → complete/error → cleanup
- Bridge processes parse requests independently of chat flow (no processing lock interference)
- Focused, stateless parsing prompts for both event and task types with timezone awareness

## Files Created/Modified

| File | Change | Purpose |
|------|--------|---------|
| `convex/schema.ts` | Modified | Added `parse_requests` table with requestId, text, type, status, result, createdAt; indexes by_request_id and by_status |
| `convex/nlParse.ts` | Created | 5 exports: createParseRequest (public), getResult (public), oldestPending (internal), updateResult (internal), cleanup (internal) |
| `convex/http.ts` | Modified | Added GET /pending-parse and POST /parse-result endpoints with LOOM_WEBHOOK_SECRET auth |
| `bridge/loom-bridge.mjs` | Modified | Added buildParsePrompt(), extractJSON(), postParseResult(), checkParseRequests(); integrated into poll() |

## Decisions Made

None — followed plan as specified.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## Next Phase Readiness

**Ready:**
- Parse infrastructure complete for Swift client consumption
- `nlParse:createParseRequest` mutation ready for Swift to call
- `nlParse:getResult` query ready for Swift subscription
- Bridge processes parse requests on every 2s poll cycle

**Concerns:**
- None

**Blockers:**
- None

---
*Phase: 07-natural-language-entry, Plan: 01*
*Completed: 2026-02-22*
