# Roadmap: Loom Cal

## Current Milestone: v0.1 — Loom Intelligence

Fresh milestone covering phases 5-8. Goal: Loom can act on the user's behalf — creating/editing/deleting events and tasks, planning days, and accepting natural language input — with platform polish to make it feel native on both iOS and Mac.

| Phase | Name | Plans | Status |
|-------|------|-------|--------|
| 5 | Loom Calendar & Task Actions | 3/3 | Complete |
| 6 | AI Daily Planning | 2/2 | Complete |
| 7 | Natural Language Entry | 0/TBD | Not Started |
| 8 | Platform Polish | 0/TBD | Not Started |

---

## Phase Details

### Phase 5: Loom Calendar & Task Actions

**Goal:** Loom can create, edit, and delete events and tasks via Convex MCP, and all changes appear in the app in real-time.

**Depends on:** Phase 4 (Loom Chat) — complete

**Success Criteria:**
1. User asks Loom to create an event -> event appears on calendar within 2 seconds
2. User asks Loom to change an event -> calendar reflects update in real-time
3. User asks Loom to delete an event -> event disappears after confirmation
4. User asks Loom to create a task -> task appears in list with correct details
5. User asks Loom to complete/delete a task -> task list updates in real-time

**Plans:**
- [x] 05-01 — Convex schema extension, context/action HTTP endpoints, bridge upgrade with system prompt and action parsing
- [x] 05-02 — Swift models (ChatMessage extension, LoomAction), ChatViewModel confirm/cancel/undo, highlight support
- [x] 05-03 — End-to-end verification (user-tested all 6 scenarios — confirmed working)

### Phase 6: AI Daily Planning

**Goal:** Loom generates a recommended daily plan based on the user's tasks and events, and no plan changes commit without explicit user approval.

**Depends on:** Phase 5

**Success Criteria:**
1. User can request "plan my day" and receive a structured recommendation
2. Plan shown as preview with proposed time blocks — no changes until user approves
3. User can approve plan and all proposed time blocks are created at once
4. User can reject/dismiss plan and calendar remains unchanged

**Plans:**
- [x] 06-01 — Bridge daily planning support, DailyPlanProposal model, ChatViewModel batch approve/reject/undo
- [x] 06-02 — DailyPlanCard UI, ChatView integration, end-to-end verification

### Phase 7: Natural Language Entry

**Goal:** Users can create events and tasks by typing natural language directly in the app without opening the chat panel.

**Depends on:** Phase 5

**Success Criteria:**
1. NL phrase in event entry field parsed into structured event — user confirms before creation
2. NL phrase in task entry field parsed into task with correct details — user confirms before creation
3. When Loom unreachable, user prompted to enter details manually

**Plans:** TBD

### Phase 8: Platform Polish

**Goal:** Native navigation and interaction patterns on both iOS and Mac, plus local notifications for events and task deadlines.

**Depends on:** Phase 3, Phase 4

**Success Criteria:**
1. iPhone uses native tab bar (Calendar, Tasks, Chat) with standard touch gestures
2. Mac uses NavigationSplitView sidebar — no iOS-specific UI artifacts
3. Local notification before upcoming calendar events (configurable lead time)
4. Local notification when task due date arrives

**Plans:** TBD

---

## Pre-PAUL History

<details>
<summary>Phases 1-4 (completed before PAUL adoption)</summary>

| Phase | Name | Plans | Completed |
|-------|------|-------|-----------|
| 1 | Foundation | 3/3 | 2026-02-20 |
| 2 | Calendar Views | 3/3 | 2026-02-20 |
| 3 | Task System | 4/4 | 2026-02-21 |
| 3.1 | Audit Gap Closure | 1/1 | 2026-02-21 |
| 4 | Loom Chat | 3/3 | 2026-02-21 |

Execution history preserved in `.planning/phases/` (read-only archive).

</details>
