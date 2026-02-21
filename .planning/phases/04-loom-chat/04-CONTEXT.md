# Phase 4: Loom Chat - Context

**Gathered:** 2026-02-21
**Status:** Ready for planning

<domain>
## Phase Boundary

In-app chat with Loom — users can send messages, receive real-time replies via Convex subscription, view message history in a single continuous thread, and the app degrades gracefully when Loom is unreachable. Loom cannot create, edit, or delete events or tasks in this phase (that's Phase 5). This phase establishes the chat infrastructure and conversational UI.

</domain>

<decisions>
## Implementation Decisions

### Chat panel placement
- Dedicated tab in the tab bar (iPhone) and sidebar (Mac) — alongside Calendar and Tasks
- One continuous conversation thread, not daily sessions or separate threads
- Full-screen chat view when on the Chat tab (standard tab behavior)
- Additionally: a floating action button (bottom-right corner) accessible from any screen that opens a compact chat sheet overlay
- Two ways to reach Loom: the tab (full experience) and the FAB (quick access from anywhere)

### Message presentation
- Classic iMessage-style bubbles — user messages on the right (accent color), Loom messages on the left (gray)
- Loom responses support Markdown rendering (bold, lists, code blocks) rendered inside bubbles
- Timestamps grouped by time gaps (e.g., "2:30 PM" header when there's a gap) — individual messages don't show times unless tapped
- Animated three-dot typing indicator in a bubble on Loom's side while generating a reply

### Loom's personality
- Playful and casual tone — like a buddy who's also really organized. Light personality, occasional humor.
- No greeting message on empty state — instead show tappable suggestion chips
- Suggestion chips are conversational starters scoped to Phase 4 capabilities: things like "What's on my calendar?", "Summarize my day", "How's my week look?"
- Loom has a visible name label ("Loom") and avatar/icon next to its messages

### Unavailable & error states
- When Loom is unreachable: input field grays out, a banner at the top says "Loom is offline" — clear and obvious
- All calendar and task features remain fully functional when Loom is offline
- Pending state: user's message bubble appears immediately with a "sent" indicator, then typing dots appear on Loom's side
- 8-second timeout: inline error bubble appears where Loom's reply would be — "Loom didn't respond. Tap to retry."
- Reconnection: silent — the offline banner disappears automatically when Loom is available again, no "back online" notice

### Claude's Discretion
- FAB visual design (size, icon, animation)
- Loom's avatar design
- Exact suggestion chip wording and count
- Markdown rendering library/approach
- Message grouping time threshold
- Scroll behavior on new messages

</decisions>

<specifics>
## Specific Ideas

- Chat should feel like iMessage in terms of bubble style and flow
- The FAB provides quick access without leaving context — important for when Loom can do mutations in Phase 5
- Suggestion chips keep the empty state useful without a greeting wall of text
- Loom's personality should feel like "a buddy who's also really organized"

</specifics>

<deferred>
## Deferred Ideas

- None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-loom-chat*
*Context gathered: 2026-02-21*
