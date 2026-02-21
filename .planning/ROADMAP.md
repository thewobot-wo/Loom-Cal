# Roadmap: Loom Cal

## Overview

Loom Cal is built in eight phases that follow the natural dependency graph of the product. The foundation locks in the Convex schema, data ownership rules, and real-time sync infrastructure before any UI exists. Calendar views and the task system are built on top of that foundation as independent vertical slices. The four Loom AI phases layer in progressively: basic chat first, then Loom-driven mutations, then AI daily planning, then natural language entry. Platform polish (iOS and Mac native shells, notifications) runs last, once all core data and AI layers are stable. Every phase ends with something verifiable — either a working user-facing capability or a locked-in architectural decision that enables the next phase.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation** - Convex schema, data model, real-time sync backbone, and source-of-truth ownership rules
- [x] **Phase 2: Calendar Views** - Day and week calendar views with Convex-native event CRUD
- [x] **Phase 3: Task System** - Full task CRUD, today view, task markers on calendar, and time-blocking (completed 2026-02-21)
- [x] **Phase 3.1: Audit Gap Closure** - Retroactive Phase 2 verification, CALV-02 doc fix, WeekView isTimeBlock fix (INSERTED, completed 2026-02-21)
- [ ] **Phase 4: Loom Chat** - In-app chat with Loom, message history, graceful offline degradation
- [ ] **Phase 5: Loom Calendar and Task Actions** - Loom creates, edits, and deletes events and tasks via Convex MCP
- [ ] **Phase 6: AI Daily Planning** - Loom-generated daily plans with required user approval before any mutation commits
- [ ] **Phase 7: Natural Language Entry** - In-app natural language event and task creation
- [ ] **Phase 8: Platform Polish** - Native iOS and Mac shells, local notifications for events and tasks

## Phase Details

### Phase 1: Foundation
**Goal**: The core infrastructure is correct and stable — Convex schema is defined, data ownership rules are locked, real-time subscriptions work, and the Swift client connects to Convex end-to-end
**Depends on**: Nothing (first phase)
**Requirements**: PLAT-05
**Success Criteria** (what must be TRUE):
  1. The SwiftUI app launches on both iOS and Mac and connects to Convex without errors
  2. Real-time Convex subscriptions deliver updates to the Swift client within 2 seconds of a backend mutation
  3. The Convex schema has tables for events, tasks, chat_messages, and studio_events, each with correct field types (`v.int64()` for integers, UTC milliseconds for timestamps, explicit timezone fields)
  4. Source-of-truth ownership is documented and enforced in schema: Convex-native events only, tasks Convex-only, studio_events read-only cache stamped with last-synced time
  5. EventKit permission is requested using `requestFullAccessToEvents()` (iOS 17+ API) and the app handles denial gracefully without crashing
**Plans:** 3/3 plans complete
Plans:
- [x] 01-01-PLAN.md — Convex backend schema and query/mutation functions for all 4 tables
- [x] 01-02-PLAN.md — Xcode multiplatform project, ConvexMobile integration, Swift models, subscription proof
- [x] 01-03-PLAN.md — EventKit permission flow, Apple Calendar read infrastructure, data ownership docs

### Phase 2: Calendar Views
**Goal**: Users can see and manage Convex-native events in a day and week calendar view, and perform full event CRUD from the app
**Depends on**: Phase 1
**Requirements**: CALV-01, CALV-02, CALV-03, CALV-04, CALV-05
**Success Criteria** (what must be TRUE):
  1. User can view the current day's events in a timeline view that shows event titles and times
  2. User can switch to a week view that shows all seven days with events laid out in their time slots
  3. User can tap a time slot to create a new event by entering a title, date, start time, and duration — the event appears on the calendar immediately
  4. User can tap an existing event to edit its title, time, or duration — changes reflect in real-time across both iOS and Mac
  5. User can delete an event from the event detail view and it disappears from the calendar without requiring a reload
**Plans:** 3/3 plans complete
Plans:
- [x] 02-01-PLAN.md — CalendarViewModel, HorizonCalendar mini month, and day timeline with event cards
- [x] 02-02-PLAN.md — Event CRUD: NL parser, creation sheet, detail view, edit view, delete confirmation
- [x] 02-03-PLAN.md — Week view, ContentView replacement, navigation gestures, and end-to-end verification

### Phase 3: Task System
**Goal**: Users can create and manage tasks with due dates and priorities, see task due dates on the calendar, and drag tasks into calendar time slots
**Depends on**: Phase 2
**Requirements**: TASK-01, TASK-02, TASK-03, TASK-04, TASK-05, TASK-06, TASK-07
**Success Criteria** (what must be TRUE):
  1. User can create a task with a title, due date, and priority level (high/medium/low) — the task appears in a task list view
  2. User can edit task details and mark a task as complete — completed tasks are visually distinct and removable from the active list
  3. Tasks with due dates appear as markers on the day and week calendar views on their due date
  4. User can drag a task from the task list onto a calendar time slot to time-block it — a calendar event is created for that slot linked to the task
  5. The Today view shows all of the current day's calendar events and all tasks due today in a single unified list
**Plans:** 4/4 plans complete
Plans:
- [x] 03-01-PLAN.md — Schema migration (priority, hasDueTime, taskId), Swift models, TaskViewModel
- [x] 03-02-PLAN.md — Task CRUD UI: TaskRowView, TaskCreationView, TaskDetailView
- [x] 03-03-PLAN.md — Today view (unified event+task timeline), ContentView restructure, week view task dots
- [x] 03-04-PLAN.md — Drag-to-time-block, time-block visual distinction, human verification

### Phase 3.1: Audit Gap Closure (INSERTED)
**Goal**: Close all gaps from v1.0 milestone audit — retroactive Phase 2 verification, documentation fixes, and WeekView integration fix
**Depends on**: Phase 3
**Requirements**: CALV-01, CALV-02, CALV-03, CALV-04, CALV-05, TASK-06
**Gap Closure**: Closes gaps from v1.0 audit (5 orphaned requirements, 1 integration gap)
**Success Criteria** (what must be TRUE):
  1. 02-VERIFICATION.md exists and confirms all 5 CALV-* requirements are satisfied with evidence
  2. CALV-02 checkbox is marked [x] in REQUIREMENTS.md with traceability status Complete
  3. WeekTimelineView renders time-blocked events with orange styling (isTimeBlock passed to TimelineEventCard)
  4. 03-02-SUMMARY.md has requirements-completed frontmatter field listing TASK-04
**Plans:** 1/1 plans complete
Plans:
- [x] 03.1-01-PLAN.md — Wire isTimeBlock in Day/Week views, rename verification file, add summary frontmatter

### Phase 4: Loom Chat
**Goal**: Users can have a real-time conversation with Loom inside the app, see message history, and the app handles Loom being unreachable without blocking any core functionality
**Depends on**: Phase 1
**Requirements**: LOOM-01, LOOM-02, LOOM-03, LOOM-04
**Success Criteria** (what must be TRUE):
  1. User can open a chat panel, type a message, and send it to Loom — the sent message appears in the chat history immediately
  2. Loom's reply appears in the chat panel in real-time via Convex subscription without requiring a manual refresh
  3. The chat panel shows full message history from the current session in chronological order
  4. When Loom is unreachable, the app shows a clear "Loom unavailable" status indicator — the chat input is disabled with an explanation, and all calendar and task features remain fully functional
  5. After sending a message, the app does not block or show an infinite spinner — it shows a pending state for a maximum of 8 seconds before showing an error if no reply arrives
**Plans:** 2/3 plans executed
Plans:
- [ ] 04-01-PLAN.md — Convex AI reply pipeline (Anthropic SDK, internalAction, scheduler) + ChatViewModel
- [ ] 04-02-PLAN.md — Chat UI views (iMessage bubbles, Markdown, typing indicator, input bar, suggestion chips)
- [ ] 04-03-PLAN.md — ContentView TabView refactor, ChatFAB, end-to-end verification

### Phase 5: Loom Calendar and Task Actions
**Goal**: Loom can create, edit, and delete events and tasks via Convex MCP, and all changes appear in the app in real-time
**Depends on**: Phase 4
**Requirements**: LOOM-05, LOOM-06, LOOM-07
**Success Criteria** (what must be TRUE):
  1. When user asks Loom in chat to create an event (e.g., "add dentist appointment Thursday 3pm"), the event appears on the calendar within 2 seconds of Loom confirming it
  2. When user asks Loom to change an event's time or title, the calendar reflects the updated event in real-time without requiring a reload
  3. When user asks Loom to delete an event, it disappears from the calendar after Loom confirms the deletion
  4. When user asks Loom to create a task, the task appears in the task list in real-time with correct title, due date, and priority as specified
  5. When user asks Loom to complete or delete a task, the task list updates in real-time to reflect the change
**Plans**: TBD

### Phase 6: AI Daily Planning
**Goal**: Loom generates a recommended daily plan based on the user's tasks and events, and no plan changes commit without explicit user approval
**Depends on**: Phase 5
**Requirements**: LOOM-08, LOOM-09
**Success Criteria** (what must be TRUE):
  1. User can request a daily plan from Loom (e.g., "plan my day") and receive a structured recommendation showing which tasks to work on and when, based on current tasks and calendar events
  2. The recommended plan is shown as a preview with proposed time blocks — no changes are made to the calendar until the user explicitly approves
  3. User can approve the plan with a single action and all proposed time blocks are created on the calendar at once
  4. User can reject or dismiss the plan preview and the calendar remains unchanged
**Plans**: TBD

### Phase 7: Natural Language Entry
**Goal**: Users can create events and tasks by typing natural language directly in the app without opening the chat panel
**Depends on**: Phase 5
**Requirements**: LOOM-10, LOOM-11
**Success Criteria** (what must be TRUE):
  1. User can type a natural language phrase into an event entry field (e.g., "standup tomorrow 10am") and Loom parses it into a structured event with correct title, date, and time — the user confirms before the event is created
  2. User can type a natural language phrase into a task entry field (e.g., "remind me to call plumber Friday") and Loom parses it into a task with correct title and due date — the user confirms before the task is created
  3. When Loom is unreachable during natural language entry, the user is prompted to enter the details manually instead of seeing an error
**Plans**: TBD

### Phase 8: Platform Polish
**Goal**: The app has native navigation and interaction patterns on both iOS and Mac, and delivers local notifications for upcoming events and task deadlines
**Depends on**: Phase 3, Phase 4
**Requirements**: PLAT-01, PLAT-02, PLAT-03, PLAT-04
**Success Criteria** (what must be TRUE):
  1. On iPhone, the app uses a native tab bar for navigation between Calendar, Tasks, and Chat — all standard iOS touch gestures (swipe, pull-to-refresh) work correctly
  2. On Mac, the app uses a NavigationSplitView sidebar layout — all iOS-only SwiftUI modifiers are conditionally compiled out, and the Mac build produces no iOS-specific UI artifacts
  3. User receives a local notification before an upcoming calendar event (at a user-configurable lead time) — tapping the notification opens the app to the event detail
  4. User receives a local notification when a task's due date arrives — tapping the notification opens the app to the task detail
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8

Note: Phase 4 (Loom Chat) depends only on Phase 1 and can proceed in parallel with Phase 2 and 3 if desired. Phase 8 depends on Phase 3 and Phase 4.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 3/3 | Complete    | 2026-02-20 |
| 2. Calendar Views | 3/3 | Complete | 2026-02-20 |
| 3. Task System | 4/4 | Complete    | 2026-02-21 |
| 3.1 Audit Gap Closure | 1/1 | Complete   | 2026-02-21 |
| 4. Loom Chat | 2/3 | In Progress|  |
| 5. Loom Calendar and Task Actions | 0/TBD | Not started | - |
| 6. AI Daily Planning | 0/TBD | Not started | - |
| 7. Natural Language Entry | 0/TBD | Not started | - |
| 8. Platform Polish | 0/TBD | Not started | - |

---
*Roadmap created: 2026-02-20*
*Coverage: 28/28 v1 requirements mapped*
