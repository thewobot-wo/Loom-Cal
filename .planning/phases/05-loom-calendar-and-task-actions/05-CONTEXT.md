# Phase 5: Loom Calendar and Task Actions - Context

**Gathered:** 2026-02-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Loom gains the ability to create, edit, and delete events and tasks via Convex mutations, with all changes reflected in the app in real-time. The chat UI already exists from Phase 4 — this phase adds mutation capabilities, confirmation flows, and context-aware responses. Daily planning and natural language entry are separate phases (6 and 7).

</domain>

<decisions>
## Implementation Decisions

### Confirmation flow
- All mutations require preview-then-confirm: Loom shows a summary card of the proposed action, user taps Confirm before anything is created/edited/deleted
- Destructive actions (delete event, delete task, complete task) use the same preview card — no extra warning or red styling
- Edits show a before/after diff: old value crossed out, new value shown (e.g., "Thursday 3pm → Friday 3pm")
- After confirming, a brief undo window appears (like Gmail's undo send) for a few seconds before the action is finalized

### Action feedback
- After successful mutation, a brief highlight animation on the affected event/task in the calendar or task list so the user can spot the change
- If Loom fails to perform the action, a friendly inline error bubble appears in chat: "I couldn't create that event — tap to try again"

### Ambiguity handling
- When multiple items match (e.g., "move my meeting" with 3 meetings), Loom lists the matches as tappable options for the user to pick from
- For tasks with missing details: Loom gently asks for missing fields but accepts whatever is provided — creates with what it has (no due date is fine)
- For events with no time specified: defaults to creating an all-day event and shows that in the preview
- For vague requests: Loom offers tappable suggestion chips based on what it sees on the calendar/task list

### Scope of mutations
- Loom can set or change ALL fields in the Convex schema for both events and tasks — not limited to a subset
- Loom has full read access to events and tasks — it can query the calendar and task list to provide context-aware responses (e.g., checking availability before suggesting a time)
- Loom can read studio calendar events (Supabase-synced) for context ("You have a studio session at 2pm") but can only mutate Convex-native events — studio events remain read-only per data ownership rules
- Apple Calendar events follow the same pattern: Loom can see them for context but cannot modify them

### Claude's Discretion
- Confirmation card visual design and layout
- Result feedback format (rich card vs text confirmation after mutation completes)
- Whether multi-action requests use separate or combined preview cards
- Undo window duration
- Highlight animation style and duration
- Suggestion chip content for vague requests
- How Loom phrases clarification questions

</decisions>

<specifics>
## Specific Ideas

- Confirmation flow mirrors the pattern from Phase 4's chat UI — everything stays in the chat bubble stream
- Before/after diff for edits makes it clear what's changing without requiring the user to remember the old values
- Undo window provides a safety net without adding friction to the confirm step
- Full schema access means Loom can handle any field the app supports — no artificial limitations
- Read access to all calendar sources (Convex, studio, Apple Calendar) lets Loom give context-aware suggestions

</specifics>

<deferred>
## Deferred Ideas

- None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-loom-calendar-and-task-actions*
*Context gathered: 2026-02-21*
