# Phase 1: Foundation - Context

**Gathered:** 2026-02-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Core infrastructure — Convex schema with tables for events, tasks, chat_messages, and studio_events. Data ownership rules locked. Real-time Convex subscriptions working. Swift client connects end-to-end on iOS and Mac. EventKit permission and read-only Apple Calendar display infrastructure.

</domain>

<decisions>
## Implementation Decisions

### Event data model
- Time stored as **start time + duration** (in minutes). End time is derived.
- Events carry: title, start (UTC ms), duration (minutes), timezone, location (optional text), notes (optional, markdown), url (optional, dedicated field for meeting links), color (optional, user-picked from palette), isAllDay boolean
- **Recurrence fields included in schema** — rrule string, recurrence group ID. Full RRULE support is desired for v1 (currently v2 as CALI-07 — see Deferred Ideas for roadmap promotion note)
- **File attachment fields included in schema** — array of file references. Upload/display UI deferred to a later phase
- Events belong to a **calendar/source concept** — each event has a calendarId linking to a named calendar. This supports future calendar sets and multi-source display

### Task data model
- Tasks carry: title, due date, flagged (boolean, not priority tiers), completed, notes (optional, markdown)
- **No priority levels** — just a boolean flagged marker
- File attachment fields included in schema (same as events, UI deferred)

### Time-blocking (Phase 3 prep)
- **Claude's discretion** — pick the best approach for linking tasks to calendar time blocks (separate linked event vs embedded fields) based on what works with Convex subscriptions

### Studio events
- Vocal studio booking calendar sourced from Supabase
- **Periodic background sync** into Convex (cron job or similar)
- Same fields as regular events (title, start, duration) — no studio-specific extra data
- Displayed **mixed on the calendar** alongside other events, visually distinguished by calendar/source
- Read-only in Convex — source of truth is Supabase

### EventKit / Apple Calendar
- **Read-only display in v1** — show Apple Calendar events on the calendar but no create/edit
- Read **directly from EventKit on-device** — no Convex caching. Events are always fresh but device-specific
- Request permission using `requestFullAccessToEvents()` (iOS 17+ API)
- On permission denial: **explain briefly and continue** — no nagging, app works with just Convex events
- On first EventKit grant: **user picks which Apple Calendar calendars to display** (selection screen)
- Calendar visibility preferences stored **locally in UserDefaults** (device-specific, no sync)

### Notes and markdown
- Both event and task notes fields support **markdown rendering**
- Stored as plain text, rendered as markdown in the UI

### App identity & project setup
- App name: **Loom Cal** (two words, as displayed on home screen and Mac dock)
- Bundle ID: **com.loomcal** (prefix)
- Target: **iOS 18+** and corresponding macOS version
- Apple Developer account with real team ID (ready for TestFlight)
- SwiftUI multiplatform — shared codebase for iOS and Mac

### Claude's Discretion
- Time-blocking implementation approach (separate event vs embedded in task)
- Exact Convex schema field types and indexing strategy
- Studio events sync frequency and error handling
- Compression/format for file attachment references
- Swift project folder structure and module organization

</decisions>

<specifics>
## Specific Ideas

- User wants to toggle calendar visibility — "I want to see my family calendar or just my kids ice skating schedule all on separate calendars that I can turn on and off in the views." The schema should support a calendar/source concept even though the full calendar sets UI is v2.
- Markdown in notes — both events and tasks should render notes as markdown
- Dedicated URL field on events for meeting links (separate from notes)
- Color on events for visual grouping without full calendar sets

</specifics>

<deferred>
## Deferred Ideas

- **Full RRULE recurring events in v1** — User wants CALI-07 (full iCalendar RRULE support) promoted from v2 to v1. Schema fields will be included in Phase 1 regardless. Roadmap needs revision to add recurring event creation/editing UI to a v1 phase.
- **Calendar sets / toggle visibility UI** (CALI-06) — User wants to show/hide individual calendars. Schema supports it via calendarId; the toggle UI is v2.
- **File attachment upload/display UI** — Schema fields included in Phase 1, but the upload interface and file display are deferred to a later phase.
- **Apple Calendar write support** (CALI-01 write portion) — Read-only in v1, write deferred to v2.

</deferred>

---

*Phase: 01-foundation*
*Context gathered: 2026-02-20*
