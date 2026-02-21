# Requirements: Loom Cal

**Defined:** 2026-02-20
**Core Value:** One app where you see everything on your plate — calendars, tasks, projects — and chat with Loom to actively manage your day.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Calendar Views

- [x] **CALV-01**: User can view events in a day calendar view
- [ ] **CALV-02**: User can view events in a week calendar view
- [x] **CALV-03**: User can create events with title, date/time, and duration
- [x] **CALV-04**: User can edit existing events (title, time, duration)
- [x] **CALV-05**: User can delete events

### Tasks

- [x] **TASK-01**: User can create tasks with title, due date, and priority
- [x] **TASK-02**: User can edit task details
- [ ] **TASK-03**: User can mark tasks as complete
- [ ] **TASK-04**: User can delete tasks
- [x] **TASK-05**: Task due dates appear as markers on calendar views
- [x] **TASK-06**: User can drag a task onto a calendar slot to time-block it
- [ ] **TASK-07**: Today view shows current-day events and tasks due today

### Loom AI

- [ ] **LOOM-01**: User can send messages to Loom via in-app chat
- [ ] **LOOM-02**: User receives Loom responses in-app in real-time
- [ ] **LOOM-03**: Chat interface displays message history
- [ ] **LOOM-04**: App degrades gracefully when Loom is unreachable (clear status, no blocking)
- [ ] **LOOM-05**: Loom can create events via Convex MCP, reflected in app in real-time
- [ ] **LOOM-06**: Loom can edit and delete events via Convex MCP
- [ ] **LOOM-07**: Loom can create and manage tasks via Convex MCP
- [ ] **LOOM-08**: Loom generates a recommended daily plan based on tasks and events
- [ ] **LOOM-09**: User must approve AI-generated plan before changes commit
- [ ] **LOOM-10**: User can type natural language to create events ("standup tomorrow 10am")
- [ ] **LOOM-11**: User can type natural language to create tasks ("remind me to call plumber Friday")

### Platform

- [ ] **PLAT-01**: Native iOS app built with SwiftUI
- [ ] **PLAT-02**: Native Mac app via SwiftUI multiplatform (shared codebase)
- [ ] **PLAT-03**: Local notifications for upcoming events
- [ ] **PLAT-04**: Local notifications for task deadlines
- [x] **PLAT-05**: Real-time data sync via Convex subscriptions

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Calendar Integrations

- **CALI-01**: Apple Calendar integration (read/write via EventKit)
- **CALI-02**: Vocal studio calendar display (Supabase via Loom sync, read-only)
- **CALI-03**: Recurring event display (from Apple Calendar)
- **CALI-04**: Month calendar view
- **CALI-05**: Year calendar view (navigation only)
- **CALI-06**: Calendar sets (user-defined named subsets of visible calendars)
- **CALI-07**: Full recurring event creation and editing (RRULE support)

### Tasks & Projects

- **TSKV-01**: Task subtasks and checklists
- **TSKV-02**: Project grouping for tasks
- **TSKV-03**: Upcoming multi-day view (Things 3-style interleaved events + tasks)

### AI Advanced

- **AIADV-01**: Travel time automation (MapKit routing, buffer event before location-based events)
- **AIADV-02**: Frames / ideal week templates for recurring time-block patterns
- **AIADV-03**: Search across all events and tasks

### Platform Extras

- **PLTX-01**: Mac menu bar item
- **PLTX-02**: iOS home screen widgets
- **PLTX-03**: Apple Watch support
- **PLTX-04**: Quick-entry keyboard shortcut (Mac)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Scheduling links (Calendly-like) | Not needed — books manually or through Loom |
| Web app | Native iOS and Mac only for v1 |
| Android support | iOS/Mac first |
| Third-party task integrations (Todoist, Notion, Linear) | Loom Cal IS the task manager |
| OAuth / Google Calendar | Apple Calendar is the primary provider (deferred to v2) |
| Team features (shared calendars, team availability) | Personal use only for v1 |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| CALV-01 | Phase 2 | Complete |
| CALV-02 | Phase 2 | Pending |
| CALV-03 | Phase 2 | Complete |
| CALV-04 | Phase 2 | Complete |
| CALV-05 | Phase 2 | Complete |
| TASK-01 | Phase 3 | Complete |
| TASK-02 | Phase 3 | Complete |
| TASK-03 | Phase 3 | Pending |
| TASK-04 | Phase 3 | Pending |
| TASK-05 | Phase 3 | Complete |
| TASK-06 | Phase 3 | Complete |
| TASK-07 | Phase 3 | Pending |
| LOOM-01 | Phase 4 | Pending |
| LOOM-02 | Phase 4 | Pending |
| LOOM-03 | Phase 4 | Pending |
| LOOM-04 | Phase 4 | Pending |
| LOOM-05 | Phase 5 | Pending |
| LOOM-06 | Phase 5 | Pending |
| LOOM-07 | Phase 5 | Pending |
| LOOM-08 | Phase 6 | Pending |
| LOOM-09 | Phase 6 | Pending |
| LOOM-10 | Phase 7 | Pending |
| LOOM-11 | Phase 7 | Pending |
| PLAT-01 | Phase 8 | Pending |
| PLAT-02 | Phase 8 | Pending |
| PLAT-03 | Phase 8 | Pending |
| PLAT-04 | Phase 8 | Pending |
| PLAT-05 | Phase 1 | Complete |

**Coverage:**
- v1 requirements: 28 total
- Mapped to phases: 28
- Unmapped: 0

---
*Requirements defined: 2026-02-20*
*Last updated: 2026-02-20 after roadmap creation — all 28 requirements mapped*
