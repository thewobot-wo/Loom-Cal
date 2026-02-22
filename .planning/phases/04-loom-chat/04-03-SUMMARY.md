---
phase: 04-loom-chat
plan: 03
subsystem: integration + ui-polish
tags: [tabview, fab, bridge, openclaw, avatar, keyboard, ui-polish]
dependency_graph:
  requires: [04-01, 04-02]
  provides: [tabview-integration, loom-bridge, chat-fab, loom-chat-complete]
  affects: [phase-05]
tech_stack:
  added: []
  patterns:
    - "@StateObject at ContentView for tab-persistent ViewModels"
    - "Bridge pattern: local polling script connects Convex HTTP endpoints to local OpenClaw gateway"
    - "Expanding TextField with axis: .vertical and lineLimit(1...6)"
    - "scrollDismissesKeyboard(.interactively) for iMessage-style keyboard dismiss"
key_files:
  created:
    - bridge/loom-bridge.mjs
    - convex/http.ts
    - LoomCal/Assets.xcassets/LoomAvatar.imageset/
    - LoomCal/Assets.xcassets/LoomSource.imageset/
    - LoomCal/Views/Chat/ChatFAB.swift
  modified:
    - LoomCal/Views/ContentView.swift
    - LoomCal/Views/Chat/ChatBubbleView.swift
    - LoomCal/Views/Chat/ChatInputBar.swift
    - LoomCal/Views/Chat/ChatView.swift
    - convex/chatMessages.ts
  deleted:
    - convex/loom.ts
decisions:
  - "Bridge pattern over direct Convex→Loom call — Convex cloud cannot reach Tailscale Funnel (ECONNRESET)"
  - "Polling interval 2s default — fast enough for chat, low overhead"
  - "/pending-messages returns messages only when last message is role:user — simple pending detection"
  - "No scheduler in send mutation — bridge handles the full reply flow externally"
  - "Loom.png as circular nav bar profile pic, source.png as circular FAB icon"
  - "Removed L avatar and Loom label from bubbles — only 1:1 chat, labels redundant"
  - "Expanding TextField (axis: .vertical, lineLimit 1-6) replaces single-line TextField"
  - "scrollDismissesKeyboard(.interactively) + tap gesture for keyboard dismiss on iOS"
requirements_completed: [LOOM-01, LOOM-02, LOOM-03, LOOM-04]
metrics:
  duration_min: ~30
  completed_date: "2026-02-21"
  tasks_completed: 3
  files_modified: 12
---

# Phase 4 Plan 03: TabView Integration, Bridge Pattern, and UI Polish

**TabView refactor, ChatFAB, architecture pivot from Anthropic to OpenClaw bridge, avatar images, expanding input, keyboard dismiss**

## Architecture Pivot

The original plan used Anthropic Claude API via `@anthropic-ai/sdk`. During execution, the user pivoted to using their own **OpenClaw "Loom"** AI assistant running on a local machine. The architecture went through 3 iterations:

1. **Telegram Bot API** — worked for sending but Loom ignored bot-sent messages (self-messages)
2. **Direct Convex→OpenClaw** via Tailscale Funnel — Convex cloud got ECONNRESET (can't reach Tailscale)
3. **Bridge pattern** (final) — polling script on Loom machine connects local OpenClaw to Convex HTTP endpoints

## What Was Built

### Task 1: TabView + ChatFAB (commit: bb8aa42)
- ContentView rewritten to TabView with Calendar/Tasks/Chat tabs
- @StateObject for all 3 ViewModels at ContentView level (prevents subscription restarts)
- ChatFAB floating button on iOS (purple gradient circle, later replaced with source.png)

### Architecture Pivot: Bridge Pattern (commits: 645dc3a, d45930f, ea9abfd)
- `convex/http.ts` — POST `/loom-reply` and GET `/pending-messages` HTTP endpoints
- `convex/chatMessages.ts` — removed scheduler call, added `listForLoom` internalQuery
- `bridge/loom-bridge.mjs` — standalone Node.js polling script (no dependencies)
- Removed `@anthropic-ai/sdk` from package.json
- Created then deleted `convex/loom.ts` (intermediate step, became dead code)

### Task 3: UI Polish (commit: 17af26a)
- Added Loom.png and source.png to asset catalog
- Replaced "L" circle avatar with Loom.png in nav bar
- Replaced purple FAB icon with source.png in circle
- Expanding multi-line text input (1–6 lines, iMessage-style)
- Interactive scroll + tap to dismiss keyboard

## Data Flow (Final Architecture)

```
User types → chatMessages.send mutation → Convex DB
Bridge polls GET /pending-messages (2s interval)
Bridge → POST localhost:18789/v1/chat/completions (OpenClaw)
Bridge → POST /loom-reply with response
Convex writeAssistantReply → DB → subscription → app updates
```

## Deviations from Plan

Major — architecture pivoted from Anthropic API to OpenClaw bridge pattern at user request. The UI integration (TabView, FAB) proceeded as planned.

## User Setup Required
- Copy `bridge/loom-bridge.mjs` to Loom machine
- Run with: `OPENCLAW_TOKEN=<token> node loom-bridge.mjs`
- Optional: clean up unused Convex env vars (TELEGRAM_*, LOOM_GATEWAY_*)
