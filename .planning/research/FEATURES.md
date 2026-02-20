# Feature Research

**Domain:** AI-powered calendar and task management app (iOS + Mac native)
**Researched:** 2026-02-20
**Confidence:** MEDIUM (Morgen features from official site = HIGH; AI planning nuances from multiple secondary sources = MEDIUM; implementation complexity estimates = MEDIUM)

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete or broken.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Day / Week / Month calendar views | Every calendar app since the 1980s; Apple Calendar sets the baseline | MEDIUM | Custom SwiftUI calendar grid is non-trivial; consider 3rd-party like EKEventViewController for quick start, then replace |
| Event creation and editing | Core calendar operation | LOW | Requires EventKit + Convex write path; support both tapping empty slot and form-based entry |
| Event detail fields (title, time, location, notes, URL, attendees, alerts) | Users expect parity with Apple Calendar | LOW | EventKit provides the model; Convex mirrors for cross-device sync |
| Recurring events | Users heavily rely on these for lessons, meetings, standups | HIGH | Complex edit semantics (this only / this and future / all); one of the hardest calendar features |
| Multiple calendar source aggregation | Morgen, Fantastical, Google Calendar all do this; it's baseline | HIGH | Vocal studio (Supabase/CalDAV) + Apple Calendar (EventKit) + Convex-native events need unified display |
| Color-coded calendars | Every calendar app; users orient by color | LOW | Map source calendars to user-chosen colors; store in Convex preferences |
| Reminders / notifications | Users expect to be alerted before events and task deadlines | LOW | iOS UNUserNotificationCenter; push from Convex for cross-device |
| Task creation with due date | Any task manager that surfaces on calendar must have due dates | LOW | Convex-native tasks; due dates rendered as calendar markers |
| Task completion tracking | Checking off tasks is the payoff moment; must feel native | LOW | Convex mutation; sync back to source (Supabase if studio task) |
| Search (events + tasks) | Users search to find past and future items quickly | MEDIUM | Full-text search on Convex; must search across all calendar sources |
| Time zone support | Frequent travelers and remote workers expect this | MEDIUM | EventKit handles local TZ; Convex stores UTC; display conversion per user |
| Today view (what's happening now) | Morgen, Things 3 "Today" list; expected on mobile | LOW | Composite of current-day events + tasks due today + task blocks |
| Natural language event/task entry | Fantastical set this expectation for iOS power users | MEDIUM | Can use on-device ML or simple NLP library; parse "lunch tomorrow at 1" into structured fields |
| Drag-and-drop rescheduling | Expected on iPad; Morgen and Fantastical both do it | MEDIUM | SwiftUI drag gesture on calendar cells; complex touch target math |
| Event conflict detection | Users expect warnings when events overlap | LOW | Query time window on Convex; surface as inline warning before save |
| Calendar sets / grouping | Morgen's "Calendar Sets" feature; users with multiple accounts want control over what they see | MEDIUM | Store sets in Convex preferences; toggle visibility per view |

### Differentiators (Competitive Advantage)

Features that set Loom Cal apart. Not universally expected, but create strong user attachment when done well.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| In-app chat with Loom AI | Conversational calendar management — ask "what's my week look like?" or "block Thursday morning for deep work"; Morgen has no chat; Clockwise has basic chat; Loom Cal's integration is deeper because Loom already manages tasks | HIGH | Telegram bot API → Convex → app; must handle Loom being unreachable gracefully (local gateway limitation); render chat history from Convex |
| AI daily planning with suggestions | Morgen's AI Planner, Reclaim, Motion all do this; the differentiator here is it's powered by Loom which already knows context about the user's work | HIGH | Loom reads tasks + events from Convex, generates a plan, writes time blocks back; user approves before committing |
| Time blocking from tasks | Drag or AI-assign tasks into calendar slots; central to Morgen's UX; makes tasks visible on the timeline | MEDIUM | Task items rendered as draggable chips; drop zone on calendar grid; creates a Convex "time block" event |
| Travel time automation | Morgen and Fantastical both do this; given studio work (physical travel to lessons), this is high value | MEDIUM | Use MapKit for route estimation; create a buffer event before/after location-based events |
| Buffer time around events | Morgen calls these "buffers"; protects focus before/after intense meetings | LOW | User sets default buffer duration in preferences; create flanking events automatically |
| Vocal studio calendar integration | Unique to this app — the Supabase lesson schedule unified with personal calendar; no competitor offers this | HIGH | Loom as sync bridge via Supabase MCP → Convex; CalDAV or direct API; must preserve studio source of truth |
| Frames (ideal week templates) | Morgen's "Frames" — template recurring time blocks by type (deep work, admin, lessons); guides AI scheduling | MEDIUM | Frame = recurring Convex event with task-filter metadata; AI planner respects frames when scheduling |
| Task → calendar slot rendering | Task due dates appear as markers on calendar day view; overdue tasks float to today; matches Things 3 "Upcoming" logic | LOW | Query tasks by due date; render as banner events beneath time grid |
| "Upcoming" multi-day planner view | Things 3 shows week-ahead with tasks + events interleaved; very useful for planning | MEDIUM | Composite view: EventKit events + Convex tasks sorted by date; infinite scroll |
| Loom-initiated event/task creation | Loom can create or edit calendar items through conversation — user says "block 2 hours for mixing on Friday" and Loom writes the event to Convex | HIGH | Convex functions exposed as MCP tools; Loom calls them; app reflects in real-time via Convex reactivity |
| Priority factor for tasks | Morgen uses "Morgen Priority Factor" (importance + due date + duration + capacity); surfaces what to do next | MEDIUM | Compute priority score on Convex; expose in task list and AI planner sorting |
| Task subtasks / checklists | Things 3, Todoist both have this; useful for lesson prep or project breakdown | LOW | Convex nested task structure; render as checklist in task detail view |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems, scope creep, or conflict with design goals.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Scheduling links (Calendly-style) | Everyone knows Calendly; seems natural to add | Builds an entirely different product (booking flow, external pages, email notifications); out of scope for personal-use v1; PROJECT.md explicitly excludes this | If needed later, integrate Calendly or Cal.com as a link generator, not a built feature |
| Third-party task app sync (Todoist, Notion, Linear pull) | Power users live in these tools | Loom Cal IS the task manager for this user; adding sync creates bidirectional conflict and maintenance burden; PROJECT.md explicitly excludes | Loom can read from these via MCP if needed; don't build a sync engine in the app |
| Full-screen year view with event density | Looks impressive in demos | Almost never useful for actual planning; high complexity to render meaningfully | Show month view; mini-year in sidebar for navigation only |
| Real-time collaborative editing | Teams use shared calendars | This is a personal app for one user; real-time conflict resolution on shared events is massive complexity | Convex real-time updates handle single-user sync perfectly; no collaborative lock needed |
| Widget customization builder | Every calendar app gets requested to have more widget options | Infinite scope; each widget variant is a separate miniapp | Ship 2-3 opinionated widgets (today, upcoming, task count); hardcode them; don't build a widget editor |
| Full-featured notes/docs inside tasks | Notion-like editing in task notes | Conflicts with Loom as the knowledge interface; creates duplicated context | Task description field supports Markdown; deeper notes live in wherever the user keeps them (Loom manages the link) |
| Android support | Broader reach | SwiftUI multiplatform is the explicit architecture choice; Android requires a completely different codebase | iOS + Mac for v1 per PROJECT.md |
| Web app | Desktop users without Mac | Adds a third platform; Convex supports web but the UX would be degraded | Native Mac app covers the desktop use case |
| AI fully autonomous scheduling (no approval step) | Seems faster | Over-automation causes frustration when AI schedules incorrectly; users feel out of control; this is a known pitfall across Reclaim, Motion user complaints | Always show a preview and require one-tap approval before committing AI-generated time blocks |

---

## Feature Dependencies

```
[Multiple Calendar Sources]
    └──requires──> [Unified Event Model in Convex]
                       └──requires──> [Apple Calendar (EventKit) sync]
                       └──requires──> [Vocal Studio (Supabase) sync via Loom]

[Calendar Views (Day/Week/Month)]
    └──requires──> [Unified Event Model in Convex]

[Time Blocking]
    └──requires──> [Calendar Views]
    └──requires──> [Task Model in Convex]

[AI Daily Planning]
    └──requires──> [Task Model in Convex]
    └──requires──> [Calendar Views (to show time blocks)]
    └──requires──> [Loom connectivity (Telegram bot)]
    └──enhances──> [Frames (ideal week templates)]

[Loom Chat Interface]
    └──requires──> [Loom bot reachability (local gateway)]
    └──requires──> [Convex chat history storage]
    └──enhances──> [AI Daily Planning]
    └──enhances──> [Event/Task creation]

[Travel Time Automation]
    └──requires──> [Event location field]
    └──requires──> [MapKit routing]

[Buffer Time]
    └──requires──> [Event creation write path]
    └──enhances──> [Travel Time Automation]

[Frames]
    └──requires──> [Calendar Views]
    └──enhances──> [AI Daily Planning]

[Task → Calendar Rendering]
    └──requires──> [Task Model in Convex]
    └──requires──> [Calendar Views]

[Vocal Studio Calendar Sync]
    └──requires──> [Loom MCP bridge (Supabase MCP)]
    └──requires──> [Convex event model matching Supabase schema]
    └──conflicts──> [Direct Supabase writes from app (must go through Loom)]

[Recurring Events]
    └──requires──> [Event Model with RRULE support]
    └──conflicts──> [Simple Convex event records (need expansion logic)]

[Natural Language Entry]
    └──enhances──> [Event creation]
    └──enhances──> [Task creation]
    └──requires──> [NLP parsing layer (on-device or API)]
```

### Dependency Notes

- **Unified Event Model requires both sync paths**: Apple Calendar (EventKit, read-write) and Vocal Studio (Supabase via Loom, read-mirror) must be resolved before any calendar views can show complete data.
- **AI Daily Planning requires Loom to be reachable**: Since Loom runs on a local gateway, the app must gracefully degrade — show tasks and calendar without AI suggestions when Loom is offline.
- **Recurring events conflict with simple record storage**: RRULE-based recurrence requires either storing the rule and expanding at query time, or pre-generating instances. Convex works best with stored expansions for a bounded future window; raw RRULE requires a library.
- **Vocal Studio sync must not bypass Supabase**: Loom is the single writer to studio data; app reads studio events from Convex mirror only.

---

## MVP Definition

### Launch With (v1)

Minimum viable product — validates the core thesis: "one app to see everything on my plate."

- [ ] **Day and Week calendar views** — primary planning views; month is secondary but needed
- [ ] **Apple Calendar event display** — EventKit read; unified with Convex-native events
- [ ] **Vocal studio calendar display** — Supabase synced to Convex via Loom; read-only in app
- [ ] **Event creation (Convex-native events)** — create events in the app's own calendar
- [ ] **Task creation with due date and priority** — basic Convex task model
- [ ] **Task list view** — separate from calendar; shows all tasks; filterable by project/area
- [ ] **Task due dates on calendar** — tasks appear as markers on the day they're due
- [ ] **Time blocking (manual)** — drag a task onto the calendar to create a time block
- [ ] **Today view** — today's events + tasks due today; the daily anchor
- [ ] **In-app Loom chat** — send messages to Loom, receive responses; Loom can create/edit Convex events+tasks
- [ ] **Reminders / notifications** — UNUserNotificationCenter alerts for events and task deadlines
- [ ] **Recurring events (display)** — show recurring events from Apple Calendar correctly

### Add After Validation (v1.x)

Features to add once core flow is validated and used daily.

- [ ] **AI daily planning** — Loom generates a suggested day plan; user approves; Loom writes time blocks to Convex
- [ ] **Travel time automation** — MapKit routing; buffer event created before location events
- [ ] **Frames / ideal week templates** — recurring template blocks that guide AI planning
- [ ] **Natural language entry** — parse "standup tomorrow 10am" into structured event
- [ ] **Calendar sets** — user-defined named subsets of visible calendars
- [ ] **Upcoming multi-day view** — week-ahead with tasks + events interleaved (Things 3 style)
- [ ] **Recurring events (create/edit)** — full RRULE creation from within the app
- [ ] **Task subtasks / checklists** — nested tasks for project breakdown
- [ ] **Search** — full-text across events and tasks

### Future Consideration (v2+)

Defer until product-market fit is established or a specific need emerges.

- [ ] **Month calendar view** — useful but rarely the primary planning surface; add when week view is solid
- [ ] **Year view (navigation only)** — mini-month scroller for navigation; never full-screen
- [ ] **Buffer time automation** — auto-add buffers around all meetings; needs user configuration
- [ ] **Priority factor AI scoring** — Morgen-style weighted priority factor across tasks; complex
- [ ] **Widgets (iOS home screen)** — today summary widget; add once core app is stable
- [ ] **Mac-specific features** — keyboard shortcuts, menu bar item, multi-window
- [ ] **Apple Watch support** — lightweight today view and task check-off

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Day + Week calendar views | HIGH | MEDIUM | P1 |
| Apple Calendar event display | HIGH | MEDIUM | P1 |
| Vocal studio calendar sync | HIGH | HIGH | P1 |
| Task creation + due dates | HIGH | LOW | P1 |
| Task list view | HIGH | LOW | P1 |
| Task → calendar rendering | HIGH | LOW | P1 |
| Today view | HIGH | LOW | P1 |
| In-app Loom chat | HIGH | HIGH | P1 |
| Reminders / notifications | HIGH | LOW | P1 |
| Time blocking (manual) | HIGH | MEDIUM | P1 |
| Recurring events (display) | HIGH | HIGH | P1 |
| AI daily planning | HIGH | HIGH | P2 |
| Travel time automation | MEDIUM | MEDIUM | P2 |
| Natural language entry | MEDIUM | MEDIUM | P2 |
| Calendar sets | MEDIUM | LOW | P2 |
| Frames / ideal week | MEDIUM | MEDIUM | P2 |
| Upcoming multi-day view | MEDIUM | MEDIUM | P2 |
| Recurring events (create/edit) | MEDIUM | HIGH | P2 |
| Task subtasks / checklists | MEDIUM | LOW | P2 |
| Search | MEDIUM | MEDIUM | P2 |
| Month calendar view | LOW | MEDIUM | P3 |
| Buffer time automation | LOW | LOW | P3 |
| Priority factor scoring | LOW | MEDIUM | P3 |
| Widgets | LOW | MEDIUM | P3 |
| Mac-specific extras | LOW | MEDIUM | P3 |
| Apple Watch | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

---

## Competitor Feature Analysis

| Feature | Morgen | Fantastical | Things 3 | Loom Cal Approach |
|---------|--------|-------------|----------|-------------------|
| Calendar sources | Google, Outlook, Apple, Fastmail, CalDAV | Google, iCloud, Exchange, CalDAV | None (task-only) | Apple Calendar (EventKit) + Vocal Studio (Supabase via Loom) |
| AI planning | YES — AI Planner with Frames, priority factor, approval step | NO | NO | YES — via Loom, conversational + batch planning |
| Time blocking | YES — drag tasks onto calendar | YES — basic | NO | YES — drag tasks onto calendar; AI can also suggest |
| Natural language entry | PARTIAL — tasks only | YES — gold standard; events and tasks | PARTIAL — dates only | YES — parse event/task entry; Loom chat accepts full NL |
| In-app AI chat | NO | NO | NO | YES — unique; Loom chat embedded in app |
| Travel time | YES — automatic via location | NO | NO | YES — MapKit-based |
| Buffer time | YES — configurable | NO | NO | YES — configurable default |
| Recurring events | YES | YES | YES | YES — display v1; create/edit v1.x |
| Task subtasks | YES | YES | YES (checklists) | YES — v1.x |
| Calendar sets | YES — "Calendar Sets" | YES — "Focus Filters" | N/A | YES — customizable named sets |
| Search | YES | YES | YES — "Quick Find" | YES — v1.x |
| Scheduling links | YES (Pro feature) | YES — "Openings" | NO | NO — explicitly out of scope |
| Team features | YES | YES — availability | NO | NO — personal only, v1 |
| Third-party task sync | YES — Notion, Todoist, Linear, etc. | YES — Todoist, Apple Reminders | NO | NO — Loom Cal is the task manager |
| Platform | Windows, Mac, Linux, iOS, Android, web | Mac, iOS only | Mac, iOS only | Mac + iOS (SwiftUI multiplatform) |

---

## Sources

- [Morgen official features](https://www.morgen.so) — HIGH confidence (official site)
- [Morgen integrations page](https://www.morgen.so/integrations) — HIGH confidence (official)
- [Morgen AI Planner guide](https://www.morgen.so/ai-planner) — HIGH confidence (official)
- [Morgen Frames guide](https://www.morgen.so/guides/how-to-use-frames) — HIGH confidence (official)
- [Morgen AI Planner daily planning guide](https://www.morgen.so/guides/plan-your-day-using-the-ai-planner) — HIGH confidence (official)
- [Fantastical features](https://flexibits.com/fantastical) — HIGH confidence (official site)
- [Things 3 features](https://culturedcode.com/things/features/) — HIGH confidence (official site)
- [Morgen vs Fantastical comparison 2026](https://efficient.app/compare/morgen-vs-fantastical) — MEDIUM confidence (third-party review)
- [Fantastical vs Morgen, Akiflow blog](https://akiflow.com/blog/fantastical-vs-morgen) — MEDIUM confidence (competitor blog)
- [Things 3 vs Todoist comparison](https://upbase.io/blog/todoist-vs-things-3/) — MEDIUM confidence (third-party)
- [Best iPhone calendar apps 2025, Zapier](https://zapier.com/blog/best-iphone-calendar-apps/) — MEDIUM confidence (editorial)
- [AI scheduling pitfalls, Clockwise](https://www.getclockwise.com/blog/best-ai-scheduling-task-managers) — MEDIUM confidence
- [Reclaim vs Motion comparison](https://reclaim.ai/compare/motion-alternative) — LOW confidence (competitor marketing)
- [AI calendar app review, Saner.ai](https://www.saner.ai/blogs/best-ai-calendar) — LOW confidence (single source)

---

*Feature research for: AI-powered calendar and task management app (Loom Cal)*
*Researched: 2026-02-20*
