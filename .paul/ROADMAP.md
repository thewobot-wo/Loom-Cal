# Roadmap: Loom Cal

## Current Milestone: v0.2 — Voice & Depth

Deepen the core experience with recurring events, Loom's voice, and quality-of-life improvements.

| Phase | Name | Plans | Status |
|-------|------|-------|--------|
| 9 | Recurring Events | 1/3 | In progress |
| 10 | Loom Voice | TBD | Not started |
| 11 | Chat & Settings Polish | TBD | Not started |

---

## Phase Details

### Phase 9: Recurring Events

**Goal:** RRULE support for creating repeating events (daily, weekly, monthly, custom), expanding them on calendar views, and handling edit/delete of single vs all occurrences.

**Depends on:** Phase 5 (Loom Calendar & Task Actions)

**Success Criteria:**
1. User can create a recurring event with daily, weekly, or monthly patterns
2. Calendar views correctly expand recurring events into individual occurrences
3. User can edit a single occurrence without affecting the series
4. User can edit all future occurrences of a series
5. User can delete a single occurrence or the entire series

**Plans:** TBD (defined during /paul:plan)

### Phase 10: Loom Voice

**Goal:** Audio I/O in chat — ElevenLabs voice output with playback controls, speech-to-text input for hands-free messaging, and a voice toggle preference.

**Depends on:** Phase 4 (Loom Chat)

**Success Criteria:**
1. Loom's responses play as audio via ElevenLabs TTS with play/pause controls
2. User can record voice input that gets transcribed and submitted as a chat message
3. Voice toggle enables/disables audio output globally
4. Audio playback works correctly on both iOS and macOS

**Plans:** TBD (defined during /paul:plan)

### Phase 11: Chat & Settings Polish

**Goal:** UX quality improvements — selectable/copyable chat text and a minimal settings screen consolidating user preferences.

**Depends on:** Phase 10 (Loom Voice — for voice toggle setting)

**Success Criteria:**
1. User can select and copy text from Loom's chat responses
2. Settings screen shows notification lead time, voice toggle, and default calendar preferences
3. Settings accessible from both iOS and macOS navigation patterns
4. All settings persist across app launches

**Plans:** TBD (defined during /paul:plan)

---

## Previous Milestones

<details>
<summary>v0.1 — Loom Intelligence (complete)</summary>

| Phase | Name | Plans | Status |
|-------|------|-------|--------|
| 5 | Loom Calendar & Task Actions | 3/3 | Complete |
| 6 | AI Daily Planning | 2/2 | Complete |
| 7 | Natural Language Entry | 2/2 | Complete |
| 8 | Platform Polish | 2/2 | Complete |

</details>

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
