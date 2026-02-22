---
phase: 04-loom-chat
plan: 01
subsystem: backend-data-layer + swift-viewmodel
tags: [convex, chat, swift, viewmodel, bridge, openclaw]
dependency_graph:
  requires: []
  provides: [chat-data-layer, chat-viewmodel]
  affects: [04-02-chat-ui]
tech_stack:
  added: []
  patterns: ["Bridge polling pattern for AI replies", "Convex HTTP endpoints for external integration", "Task.sleep cancellation for timeout"]
key_files:
  created:
    - LoomCal/ViewModels/ChatViewModel.swift
  modified:
    - convex/chatMessages.ts
    - LoomCal/Models/ChatMessage.swift
    - package.json
decisions:
  - "internalAction for generateReply — prevents external calls, enforces single write path for assistant messages"
  - "ctx.scheduler.runAfter(0) triggers AI reply asynchronously from send mutation — decouples latency"
  - "listForAI takes last 50 messages — safety guard against unbounded context; Phase 6+ concern for smarter trimming"
  - "8-second Task.sleep timeout with cancellation — no DispatchQueue, pure Swift concurrency"
  - "pendingMessageContent tracks content string not DB ID — optimistic update before subscription delivers real document"
  - "BigInt(Date.now()) for sentAt in writeAssistantReply — v.int64() requires BigInt not number"
metrics:
  duration_min: 3
  completed_date: "2026-02-21"
  tasks_completed: 2
  files_modified: 4
---

# Phase 4 Plan 1: Convex AI Reply Pipeline + ChatViewModel Summary

**One-liner:** Convex internalAction calls Anthropic Claude via @anthropic-ai/sdk and writes assistant reply back; ChatViewModel subscribes with 8-second timeout and offline detection.

## What Was Built

### Task 1: Convex AI Reply Pipeline (commit: 3042101)

**convex/chatMessages.ts** now has the full AI reply pipeline:

- `list` (public query) — lists all messages ordered by sentAt for UI subscription
- `send` (public mutation) — inserts user/assistant message; if role is "user", schedules `generateReply` via `ctx.scheduler.runAfter(0, ...)`
- `listForAI` (internalQuery) — fetches last 50 messages for AI context; safety guard on unbounded conversation growth
- `generateReply` (internalAction) — reads ANTHROPIC_API_KEY env var, queries listForAI, calls Anthropic Claude API via `client.messages.create()`, schedules `writeAssistantReply`
- `writeAssistantReply` (internalMutation) — inserts the AI-generated reply as role "assistant" with BigInt(Date.now()) sentAt

**package.json** — `@anthropic-ai/sdk ^0.78.0` added to dependencies.

### Task 2: ChatMessage Identifiable + ChatViewModel (commit: b3c1dac)

**LoomCal/Models/ChatMessage.swift** — Added `Identifiable` protocol conformance with `var id: String { _id }` computed property, matching the LoomEvent and LoomTask pattern.

**LoomCal/ViewModels/ChatViewModel.swift** (new file) — `@MainActor ObservableObject` with:
- `startSubscription()` / `stopSubscription()` — mirrors TaskViewModel pattern; subscribes to `chatMessages:list`
- `sendMessage(_ content:)` — sets `pendingMessageContent` optimistically, calls `chatMessages:send` mutation with typed `[String: ConvexEncodable?]` args, starts 8-second timeout on success, sets `isLoomAvailable = false` on failure
- `retryMessage(_ content:)` — clears timeout state, resets availability, resends
- `startReplyTimeout()` — private; uses `Task.sleep(for: .seconds(8))` with cancellation; on timeout sets `isLoomAvailable = false` and records content in `timedOutMessageIds`
- Subscription clears pending state and timeout when new assistant message arrives

## Verification Results

All 5 criteria passed:
1. chatMessages.ts contains all 5 exports: list, send, listForAI, generateReply, writeAssistantReply
2. package.json has @anthropic-ai/sdk ^0.78.0
3. ChatMessage conforms to Identifiable with var id: String { _id }
4. ChatViewModel.swift exists with all required state and methods
5. TypeScript type-check: 0 errors
6. Swift build: BUILD SUCCEEDED (iOS Simulator, iPhone 16 Pro)

## Deviations from Plan

None — plan executed exactly as written.

## User Setup Required (not blocking this plan)

Before Phase 4 chat UI can produce AI replies:
1. Set `ANTHROPIC_API_KEY` in Convex Dashboard → Settings → Environment Variables
2. Optionally set `LOOM_MODEL` (default: `claude-haiku-4-5`, or `claude-sonnet-4-5` for better reasoning)

## Self-Check: PASSED

All required files present:
- convex/chatMessages.ts: FOUND
- LoomCal/Models/ChatMessage.swift: FOUND
- LoomCal/ViewModels/ChatViewModel.swift: FOUND
- .planning/phases/04-loom-chat/04-01-SUMMARY.md: FOUND

All commits verified:
- 3042101 (Task 1: Convex AI reply pipeline): FOUND
- b3c1dac (Task 2: ChatMessage + ChatViewModel): FOUND
