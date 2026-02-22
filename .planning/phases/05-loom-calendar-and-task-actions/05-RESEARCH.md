# Phase 5: Loom Calendar and Task Actions — Research

**Researched:** 2026-02-21
**Domain:** AI-driven calendar/task mutations via bridge pattern, SwiftUI confirmation flow, real-time feedback
**Confidence:** HIGH (core architecture verified against existing code and official docs)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Confirmation flow**
- All mutations require preview-then-confirm: Loom shows a summary card of the proposed action, user taps Confirm before anything is created/edited/deleted
- Destructive actions (delete event, delete task, complete task) use the same preview card — no extra warning or red styling
- Edits show a before/after diff: old value crossed out, new value shown (e.g., "Thursday 3pm → Friday 3pm")
- After confirming, a brief undo window appears (like Gmail's undo send) for a few seconds before the action is finalized

**Action feedback**
- After successful mutation, a brief highlight animation on the affected event/task in the calendar or task list so the user can spot the change
- If Loom fails to perform the action, a friendly inline error bubble appears in chat: "I couldn't create that event — tap to try again"

**Ambiguity handling**
- When multiple items match (e.g., "move my meeting" with 3 meetings), Loom lists the matches as tappable options for the user to pick from
- For tasks with missing details: Loom gently asks for missing fields but accepts whatever is provided — creates with what it has (no due date is fine)
- For events with no time specified: defaults to creating an all-day event and shows that in the preview
- For vague requests: Loom offers tappable suggestion chips based on what it sees on the calendar/task list

**Scope of mutations**
- Loom can set or change ALL fields in the Convex schema for both events and tasks — not limited to a subset
- Loom has full read access to events and tasks — it can query the calendar and task list to provide context-aware responses (e.g., checking availability before suggesting a time)
- Loom can read studio calendar events (Supabase-synced) for context but can only mutate Convex-native events
- Apple Calendar events: Loom can see them for context but cannot modify them

### Claude's Discretion
- Confirmation card visual design and layout
- Result feedback format (rich card vs text confirmation after mutation completes)
- Whether multi-action requests use separate or combined preview cards
- Undo window duration
- Highlight animation style and duration
- Suggestion chip content for vague requests
- How Loom phrases clarification questions

### Deferred Ideas (OUT OF SCOPE)
- None — discussion stayed within phase scope

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| LOOM-05 | Loom can create events via Convex MCP, reflected in app in real-time | Bridge extends to send context + receive structured action JSON; bridge calls `events:create` mutation via Convex HTTP API; iOS subscription on `events:list` delivers the change immediately |
| LOOM-06 | Loom can edit and delete events via Convex MCP | Same bridge extension; `events:update` and `events:remove` mutations already exist and are fully parameterized; bridge dispatches the correct mutation based on action type |
| LOOM-07 | Loom can create and manage tasks via Convex MCP | `tasks:create`, `tasks:update`, `tasks:remove` mutations already exist; same bridge flow handles task actions; iOS subscription on `tasks:list` delivers changes immediately |

</phase_requirements>

---

## Summary

Phase 5 wires Loom to perform calendar and task mutations in response to user chat messages. The architecture is a direct extension of the Phase 4 bridge pattern — the same polling loop that forwards messages to OpenClaw and posts replies back to Convex. No new infrastructure is required. The extension has two parts: (1) the bridge sends Loom the full calendar and task context alongside each message, giving Loom the information it needs to take action, and (2) Loom's reply is structured JSON that the bridge parses to detect actions. When an action is detected, the bridge calls the appropriate Convex HTTP endpoint to execute the mutation before posting Loom's text reply to the chat.

The iOS side has two jobs: render the confirmation flow inside the chat bubble stream (a SwiftUI preview card that the user confirms), and show a brief highlight animation on the calendar or task list after the mutation succeeds. Critically, all existing Convex mutations (`events:create`, `events:update`, `events:remove`, `tasks:create`, `tasks:update`, `tasks:remove`) are already complete and fully parameterized — Phase 5 calls them, not rebuilds them. The CalendarViewModel and TaskViewModel already subscribe to the data in real time, so mutations written by the bridge will appear in the app automatically with no new subscription code.

The hardest part of this phase is the protocol design: how Loom signals intent (text with embedded JSON block vs. a structured system), how the bridge reliably detects and parses action payloads, and how the confirmation flow threads through from bridge → Convex → SwiftUI → bridge → final mutation. The second hardest part is the confirmation UX: a new message type (a card, not a plain chat bubble) must be inserted into the chat stream and respond to user taps.

**Primary recommendation:** Extend the bridge with a structured JSON envelope for Loom actions, deliver a pending-action chat message with `role: "pending_action"` to the Convex `chat_messages` table (or a separate `pending_actions` table), render it as a confirmation card in SwiftUI, and execute the mutation when the user taps Confirm. This keeps everything in Convex real-time subscriptions with no new polling layers.

---

## Architecture Analysis: What Already Exists

### Existing Convex Backend (nothing new needed here)

All mutations are complete and fully parameterized:

**`convex/events.ts`:**
- `events:create` — accepts all schema fields (calendarId, title, start, duration, timezone, isAllDay, location, notes, url, color, taskId)
- `events:update` — partial patch, accepts id + any subset of fields
- `events:remove` — accepts id

**`convex/tasks.ts`:**
- `tasks:create` — accepts all schema fields (title, dueDate, priority, hasDueTime, completed, notes)
- `tasks:update` — partial patch, accepts id + any subset of fields
- `tasks:remove` — accepts id

**Int64 in HTTP API:** Convex serializes `v.int64()` fields as base-10 strings in JSON export. When the bridge calls Convex mutations via the HTTP API, timestamp values (`start`, `dueDate`, `sentAt`) must be passed as numeric strings, not JavaScript numbers. The existing bridge already works around this for `sentAt` in `writeAssistantReply` by passing through the mutation layer which handles BigInt. The safest pattern for Phase 5 bridge mutations is to call `ctx.runMutation` from a new HTTP action in `http.ts` — the action layer converts the JSON payload before calling the mutation, using `BigInt(value)` for int64 fields.

### Existing iOS Client (minimal new code needed)

- `CalendarViewModel.events` is `@Published` — already updated by Convex subscription when any event is created/updated/deleted
- `TaskViewModel.tasks` is `@Published` — same
- Both ViewModels already exist at ContentView level (`@StateObject`), so mutations by the bridge are immediately visible everywhere in the app
- `CalendarViewModel.createEvent`, `updateEvent`, `deleteEvent` and `TaskViewModel.createTask`, `updateTask`, `deleteTask` already exist — these can be called directly by the iOS client for the confirm tap

### Bridge (extension needed)

Current bridge flow (Phase 4):
```
Poll /pending-messages → POST to OpenClaw → POST /loom-reply
```

Phase 5 extended flow:
```
Poll /pending-messages (+ context payload)
→ POST to OpenClaw (with system prompt + context)
→ Parse Loom's reply for action JSON
→ If action found: POST /loom-pending-action (creates card in chat)
→ If no action: POST /loom-reply (existing)
```

After user confirms (tapped from iOS):
```
iOS taps Confirm → calls Convex mutation directly (via ConvexMobile)
→ Mutation writes to DB → subscription updates UI
→ iOS posts confirmation text to chat as assistant message
```

---

## Standard Stack

### Core (no new dependencies needed)

| Component | Version | Purpose | Status |
|-----------|---------|---------|--------|
| ConvexMobile (Swift) | 0.8.0 | Subscribe to events/tasks, call mutations on confirm | Already in project |
| Convex TypeScript backend | existing | HTTP actions for bridge mutations, context query | Already deployed |
| bridge/loom-bridge.mjs | Phase 4 | Extended with context injection + JSON parsing | Extend in place |
| SwiftUI | iOS 17+ | Confirmation card view, highlight animation | Built-in |

### No New Libraries Required

Phase 5 deliberately avoids new dependencies. All needed capabilities exist:
- Convex real-time subscriptions: `ConvexMobile` already handles this
- Mutations: `convex.mutation(...)` pattern is established
- UI components: SwiftUI animation primitives are sufficient
- Context delivery: Convex HTTP actions + JSON

---

## Architecture Patterns

### Pattern 1: Structured JSON Envelope in Loom Replies

Loom's reply embeds a JSON action block inside its text. The bridge detects it and splits:

```
Loom's raw reply:
"Sure! I've scheduled your dentist appointment.

ACTION:
```json
{
  "type": "create_event",
  "payload": {
    "title": "Dentist",
    "start": "1708988400000",
    "duration": "60",
    "timezone": "America/New_York",
    "isAllDay": false,
    "calendarId": "personal"
  }
}
```"
```

Bridge extraction logic (in `loom-bridge.mjs`):
```javascript
function extractAction(replyText) {
  const match = replyText.match(/ACTION:\s*```json\s*([\s\S]*?)```/);
  if (!match) return { action: null, displayText: replyText };

  try {
    const action = JSON.parse(match[1]);
    // Strip the ACTION block from the display text
    const displayText = replyText.replace(/ACTION:\s*```json[\s\S]*?```/, '').trim();
    return { action, displayText };
  } catch {
    return { action: null, displayText: replyText };
  }
}
```

**Why this approach over tool_calls:**
- OpenClaw does not reliably pass the `tools` parameter to custom OpenAI-compatible endpoints (confirmed via GitHub issue #8923) — tool_calls cannot be relied upon
- The JSON-in-text pattern is the industry fallback when tool_calls are unavailable; Loom can be instructed via system prompt to output this format reliably
- The bridge strips the JSON before posting the display text to chat — the user sees only Loom's natural language text

### Pattern 2: Pending Action in Convex — New Message Type

When the bridge detects an action, it writes a special message to Convex that the iOS app renders as a confirmation card.

**Option A: Extend `chat_messages` with a `messageType` field (recommended)**

```typescript
// schema.ts addition
chat_messages: defineTable({
  role: v.union(v.literal("user"), v.literal("assistant"), v.literal("pending_action")),
  content: v.string(),      // Loom's natural language text (no JSON)
  sentAt: v.int64(),
  action: v.optional(v.string()),     // JSON string of the action payload
  actionStatus: v.optional(v.union(
    v.literal("pending"),
    v.literal("confirmed"),
    v.literal("cancelled"),
    v.literal("undone")
  )),
})
```

**Option B: Separate `pending_actions` table**

Adds complexity; not needed since the action is part of the conversation flow. Option A is simpler and keeps the chat stream unified.

### Pattern 3: Context Injection in Bridge

Before forwarding to OpenClaw, the bridge fetches calendar and task context from Convex and injects it into the system prompt.

New HTTP endpoint `GET /loom-context`:
```typescript
// convex/http.ts addition
http.route({
  path: "/loom-context",
  method: "GET",
  handler: httpAction(async (ctx) => {
    const [events, tasks, studioEvents] = await Promise.all([
      ctx.runQuery(internal.events.listForLoom, {}),
      ctx.runQuery(internal.tasks.listForLoom, {}),
      ctx.runQuery(internal.studioEvents.listForLoom, {}),
    ]);
    return new Response(JSON.stringify({ events, tasks, studioEvents }), {
      headers: { "Content-Type": "application/json" },
    });
  }),
});
```

Bridge injects context into the system message:
```javascript
const context = await fetchContext();
const systemPrompt = buildSystemPrompt(context);  // formats events + tasks into readable text

const loomRes = await fetch(`${OPENCLAW_URL}/v1/chat/completions`, {
  method: "POST",
  body: JSON.stringify({
    model: "openclaw",
    messages: [
      { role: "system", content: systemPrompt },
      ...conversationMessages
    ],
  }),
});
```

### Pattern 4: Bridge Calls Convex HTTP Action for Mutations

When the bridge detects an action after user confirms (or immediately for auto-confirmed actions), it calls a new HTTP endpoint:

```typescript
// convex/http.ts — new endpoint
http.route({
  path: "/loom-action",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const { action } = await request.json();

    switch (action.type) {
      case "create_event":
        await ctx.runMutation(internal.events.create, {
          ...action.payload,
          start: BigInt(action.payload.start),    // string → BigInt for int64
          duration: BigInt(action.payload.duration),
        });
        break;
      case "update_event":
        await ctx.runMutation(internal.events.update, {
          id: action.payload.id,
          ...(action.payload.start && { start: BigInt(action.payload.start) }),
          // ... other fields
        });
        break;
      // ... other action types
    }

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  }),
});
```

**BigInt handling:** JSON does not support BigInt. The bridge sends int64 values as numeric strings (e.g., `"1708988400000"`). The HTTP action converts them with `BigInt(value)` before passing to mutations. Alternatively, the bridge can call Convex mutations directly via the Convex HTTP client API (`POST /api/mutation`) which handles the encoding.

### Pattern 5: iOS Confirmation Flow — SwiftUI

The confirmation card is a new view rendered inside the existing `ChatView` `LazyVStack`, differentiated by `message.role == "pending_action"`.

```swift
// In ChatView's LazyVStack:
ForEach(groupedMessages) { group in
  ForEach(group.messages) { message in
    if message.role == "pending_action" {
      ActionConfirmationCard(
        message: message,
        onConfirm: { chatViewModel.confirmAction(message) },
        onCancel: { chatViewModel.cancelAction(message) }
      )
    } else {
      ChatBubbleView(message: message)
    }
  }
}
```

The card decodes `message.action` (JSON string) and shows the relevant preview.

### Pattern 6: iOS Executes the Mutation on Confirm

When the user taps Confirm on the card:

```swift
// In ChatViewModel
func confirmAction(_ message: ChatMessage) {
  guard let actionJSON = message.action,
        let action = try? JSONDecoder().decode(LoomAction.self, from: Data(actionJSON.utf8))
  else { return }

  // Mark action as confirmed in Convex
  Task {
    let args: [String: ConvexEncodable?] = [
      "id": message.id,
      "actionStatus": "confirmed"
    ]
    try? await convex.mutation("chatMessages:updateActionStatus", with: args)
  }

  // Execute the actual mutation
  Task {
    do {
      switch action.type {
      case "create_event":
        try await calendarViewModel.createEventFromAction(action.payload)
        // Start undo timer
        startUndoTimer(for: action, messageId: message.id)
      case "delete_event":
        pendingUndoAction = action   // Hold for undo window
        startUndoTimer(for: action, messageId: message.id)
      // ...
      }
    } catch {
      showActionError(message: message)
    }
  }
}
```

### Pattern 7: Undo Window Timer

```swift
// ChatViewModel addition
@Published var activeUndoAction: LoomAction? = nil
@Published var undoSecondsRemaining: Int = 5
private var undoTask: Task<Void, Never>?

func startUndoTimer(for action: LoomAction, messageId: String) {
  activeUndoAction = action
  undoSecondsRemaining = 5

  undoTask?.cancel()
  undoTask = Task {
    for remaining in stride(from: 4, through: 0, by: -1) {
      try? await Task.sleep(for: .seconds(1))
      guard !Task.isCancelled else { return }
      self.undoSecondsRemaining = remaining
    }
    // Timer expired — action is finalized
    self.activeUndoAction = nil
    self.undoTask = nil
  }
}

func undoAction() {
  guard let action = activeUndoAction else { return }
  undoTask?.cancel()
  undoTask = nil
  activeUndoAction = nil

  // Reverse the mutation
  Task {
    switch action.type {
    case "create_event":
      if let id = action.result?.id {
        try? await calendarViewModel.deleteEvent(id: id)
      }
    case "delete_event":
      // Re-create with original payload
      // ...
    }
  }
}
```

The undo banner renders as a persistent strip at the bottom of the chat (above the input bar) while `activeUndoAction != nil`.

### Pattern 8: Highlight Animation on Calendar/Task View

After a mutation succeeds, the ID of the newly created/modified item is published so views can animate it:

```swift
// CalendarViewModel addition
@Published var highlightedEventId: String? = nil

func flashHighlight(eventId: String) {
  highlightedEventId = eventId
  Task {
    try? await Task.sleep(for: .seconds(2))
    withAnimation {
      self.highlightedEventId = nil
    }
  }
}
```

In the event view:
```swift
// TimelineEventCard or similar
.overlay {
  if calendarViewModel.highlightedEventId == event._id {
    RoundedRectangle(cornerRadius: 6)
      .stroke(Color.accentColor, lineWidth: 2)
      .opacity(isHighlighted ? 1 : 0)
      .animation(.easeInOut(duration: 0.4).repeatCount(3), value: isHighlighted)
  }
}
```

SwiftUI's `repeatCount` + `easeInOut` creates a pulsing border that draws the eye to the new/changed item without being jarring. Uses `@State var isHighlighted` toggled in `.onAppear` when `highlightedEventId` matches.

### Pattern 9: System Prompt Design for Loom

The system prompt is the key lever for controlling Loom's behavior. It must:
1. Tell Loom what data is available (injected context)
2. Define the JSON action format exactly
3. Specify the decision tree for ambiguity
4. Reinforce that Loom proposes, not executes (the app confirms)

```
You are Loom, a calendar and task assistant for [user's name].

## Current Calendar and Tasks
[Injected: formatted list of upcoming events and active tasks]

## Your Capabilities
You can create, edit, and delete events and tasks. When the user asks you to take action,
always propose the action first with a confirmation card — never act without showing a preview.

## Action Format
When you want to perform a calendar or task action, include this block at the END of your reply:

ACTION:
```json
{
  "type": "create_event" | "update_event" | "delete_event" | "create_task" | "update_task" | "delete_task",
  "displaySummary": "Human-readable summary for the confirmation card",
  "payload": { ... }
}
```

For edits, include "previousValues" alongside the new values in the payload so the app can show a diff.

## Ambiguity Rules
- If multiple events/tasks match, list them as numbered options and ask which one
- If a time is missing for events, default to all-day and mention it in your reply
- If required task fields are missing, create with what you have and note what's missing
```

### Anti-Patterns to Avoid

- **Executing mutations directly from the bridge without user confirmation:** The bridge must write a `pending_action` message and wait; the iOS app executes the mutation on Confirm tap
- **Relying on OpenClaw tool_calls:** OpenClaw does not reliably send `tools` to custom OpenAI-compatible endpoints; use JSON-in-text envelope instead
- **Storing int64 timestamps as JSON numbers in the bridge:** JSON numbers lose precision for large timestamps; use strings and convert to BigInt in the HTTP action handler
- **Making the confirmation card a modal/sheet:** It stays in the chat bubble stream per the locked decisions; sheets break the conversational flow
- **Fetching full event+task history on every poll cycle:** Fetch context once per message (cache it between polls if message count hasn't changed)
- **Writing `role: "assistant"` for pending actions from the bridge:** Use a separate role/status field so the iOS client can distinguish cards from regular bubbles

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Real-time mutation delivery to iOS | Custom polling from iOS | Convex subscription (already live) | `events:list` and `tasks:list` subscriptions push all changes instantly; no polling needed |
| Undo timer | UIKit timers, DispatchQueue | `Task.sleep` + cancel pattern (already in project) | Cooperative cancellation, no race conditions with @MainActor |
| JSON action parsing in bridge | Schema validation library | Simple `JSON.parse` + field checks | Bridge runs in Node.js without bundler; keep it dependency-free per Phase 4 pattern |
| Highlight animation | Third-party animation library | SwiftUI `.animation(.easeInOut.repeatCount(3), value:)` | Built-in, no dependencies |
| Context serialization | Complex serialization | Plain text summary in system prompt | Loom reads natural language better than raw JSON dumps; simpler, more robust |
| int64 conversion | Custom bigint library | `BigInt(stringValue)` in HTTP action handler | JavaScript BigInt is built-in since Node 10.3 |

---

## Common Pitfalls

### Pitfall 1: OpenClaw Tool Calls Are Unreliable with Custom Endpoints

**What goes wrong:** If the bridge sends a `tools` array expecting OpenClaw to use function calling, it may receive plain text back with no `tool_calls` — because OpenClaw does not send the `tools` parameter to custom OpenAI-compatible providers by default.

**Why it happens:** GitHub issue #8923 confirms this limitation. The `compat.supportedParameters` workaround exists but requires OpenClaw configuration that is not guaranteed to be set up.

**How to avoid:** Use the JSON-in-text envelope pattern (Pattern 1). Loom is instructed via system prompt to always output the `ACTION: ```json``` ` block. This is reliable regardless of the underlying provider configuration.

**Warning signs:** Bridge receives plain text replies with no parseable action even for clear mutation requests.

### Pitfall 2: Int64 Timestamp Precision in JSON

**What goes wrong:** JavaScript `JSON.stringify()` converts large numbers (> 2^53) to exponential notation or loses precision. Unix timestamps in milliseconds (e.g., `1708988400000`) are fine as JS numbers, but the issue arises if dates far in the future are used.

**Why it happens:** JavaScript `Number` is a 64-bit float — safe integer range is up to 2^53. Timestamps for 2025 are around 1.7e12, safely within range for JSON number, but Convex's `v.int64()` may be stricter.

**How to avoid:** Always pass timestamps from Loom to the bridge as numeric strings (`"1708988400000"`), convert to `BigInt()` in the HTTP action before calling `ctx.runMutation`. This sidesteps the entire precision question.

**Warning signs:** TypeScript type error "Type 'number' is not assignable to type 'bigint'" in the HTTP action handler, or malformed timestamps in events.

### Pitfall 3: Confirmation Card Creates Duplicate Message Flow

**What goes wrong:** The bridge posts a `pending_action` message to Convex. The iOS subscription picks it up and shows the card. User taps Confirm. But if the bridge also posts a `role: "assistant"` confirmation reply *before* the iOS app does, the chat has two confirmation messages.

**Why it happens:** Race condition between the bridge posting a confirmation and the iOS app posting its own "Done!" message after executing the mutation.

**How to avoid:** Only one side posts confirmation text. Recommended: the iOS app posts a short text reply after the mutation succeeds (`chatMessages:send` with role "assistant", e.g., "Dentist appointment added!"). The bridge does not post a second reply after the action is confirmed.

**Warning signs:** "Event created!" appearing twice in the chat.

### Pitfall 4: Calendar Context Goes Stale

**What goes wrong:** Bridge fetches events/tasks at the start of the poll cycle. If the user has events that change between message polls, Loom's context is stale. It might propose creating an event that conflicts with something that was just added.

**Why it happens:** Bridge is a polling loop; context is fetched once per cycle.

**How to avoid:** Fetch context fresh on every message (not just once at startup). The `/loom-context` endpoint is fast (simple Convex queries). Acceptable latency tradeoff for accuracy.

**Warning signs:** Loom proposes times that conflict with existing events it "doesn't see."

### Pitfall 5: `pending_action` Card Not Dismissing After Confirm/Cancel

**What goes wrong:** The confirmation card stays visible in the chat after the user taps Confirm or Cancel because the `actionStatus` field is not being observed correctly.

**Why it happens:** If `ChatMessage` model doesn't include `actionStatus`, or if the Convex subscription doesn't re-deliver the updated message after the status changes, the card stays in `pending` state forever.

**How to avoid:** Ensure `ChatMessage.swift` includes `actionStatus` as an optional `String`. The subscription will re-deliver the message with the updated field when the mutation patches it. The SwiftUI view conditionally renders the card buttons based on `actionStatus == "pending"`.

**Warning signs:** Multiple Confirm buttons on the same card, or card not changing after user interaction.

### Pitfall 6: Missing `calendarId` in Bridge Event Creation

**What goes wrong:** Bridge sends action payload without `calendarId`. The `events:create` mutation requires it.

**Why it happens:** Loom's system prompt doesn't mention `calendarId`, so it omits it.

**How to avoid:** In the HTTP action handler, default `calendarId` to `"personal"` if absent. Also include it explicitly in the system prompt's action format example.

**Warning signs:** Convex mutation validation error: "Missing required field 'calendarId'."

### Pitfall 7: Highlight Animation Targets Wrong View

**What goes wrong:** After creating an event via Loom, the highlight animation fires but doesn't visually highlight the correct event on screen (the user is on a different date, or the event is off-screen in the timeline).

**Why it happens:** The `highlightedEventId` is set, but if the current date view doesn't include that event, no view reads the highlighted state.

**How to avoid:** When a Loom action creates/modifies an event, also navigate `CalendarViewModel.selectedDate` to the event's date before starting the highlight animation. This ensures the event is on screen.

**Warning signs:** Highlight animation timer fires but nothing visible changes in the calendar.

---

## Code Examples

Verified patterns from official sources and existing project code:

### Bridge: Action Extraction from Loom Reply

```javascript
// bridge/loom-bridge.mjs extension
function extractAction(replyText) {
  const match = replyText.match(/ACTION:\s*```json\s*([\s\S]*?)```/);
  if (!match) return { action: null, displayText: replyText.trim() };

  try {
    const action = JSON.parse(match[1].trim());
    const displayText = replyText.replace(/ACTION:\s*```json[\s\S]*?```/g, '').trim();
    return { action, displayText };
  } catch (e) {
    console.error('[bridge] Failed to parse action JSON:', e.message);
    return { action: null, displayText: replyText.trim() };
  }
}
```

### Bridge: Post Pending Action to Convex

```javascript
// New bridge function: post action card
async function postPendingAction(displayText, action) {
  const headers = { "Content-Type": "application/json" };
  if (WEBHOOK_SECRET) headers["Authorization"] = `Bearer ${WEBHOOK_SECRET}`;

  const res = await fetch(`${CONVEX_SITE_URL}/loom-pending-action`, {
    method: "POST",
    headers,
    body: JSON.stringify({ displayText, action }),
  });

  if (!res.ok) {
    console.error(`[bridge] Failed to post pending action: ${res.status}`);
    // Fall back to posting plain text
    await postLoomReply(displayText);
  }
}
```

### Convex HTTP Action: Pending Action Endpoint

```typescript
// convex/http.ts addition
// Source: existing /loom-reply pattern + ctx.runMutation
http.route({
  path: "/loom-pending-action",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    // Optional auth
    const secret = process.env.LOOM_WEBHOOK_SECRET;
    if (secret) {
      const auth = request.headers.get("Authorization");
      if (auth !== `Bearer ${secret}`) {
        return new Response("Unauthorized", { status: 401 });
      }
    }

    const { displayText, action } = await request.json();

    await ctx.runMutation(internal.chatMessages.writePendingAction, {
      content: displayText,
      action: JSON.stringify(action),
    });

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }),
});
```

### Convex Mutation: Execute Event Create from iOS Confirm

```swift
// CalendarViewModel addition — called when user taps Confirm in iOS
func createEventFromAction(_ payload: [String: Any]) async throws {
  guard let title = payload["title"] as? String,
        let startStr = payload["start"] as? String,
        let durationStr = payload["duration"] as? String,
        let startMs = Int(startStr),
        let durationMin = Int(durationStr)
  else { throw ActionError.invalidPayload }

  let start = Date(timeIntervalSince1970: TimeInterval(startMs) / 1000)
  let isAllDay = payload["isAllDay"] as? Bool ?? false

  try await createEvent(
    title: title,
    start: start,
    durationMinutes: durationMin,
    isAllDay: isAllDay
  )
}
```

### SwiftUI: Highlight Pulse Animation

```swift
// Source: Apple Developer Documentation — SwiftUI Animations
// Applied to event cards in TimelineEventCard or task rows
struct HighlightPulseModifier: ViewModifier {
  let isHighlighted: Bool
  @State private var pulseOpacity: Double = 0

  func body(content: Content) -> some View {
    content
      .overlay {
        if isHighlighted {
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color.accentColor, lineWidth: 2)
            .opacity(pulseOpacity)
            .onAppear {
              withAnimation(.easeInOut(duration: 0.5).repeatCount(3, autoreverses: true)) {
                pulseOpacity = 1.0
              }
            }
        }
      }
  }
}

extension View {
  func highlightPulse(active: Bool) -> some View {
    modifier(HighlightPulseModifier(isHighlighted: active))
  }
}
```

### SwiftUI: Undo Banner

```swift
// Source: project pattern (Task.sleep + cancel, from ChatViewModel.startReplyTimeout)
struct UndoBanner: View {
  let action: LoomAction
  let secondsRemaining: Int
  let onUndo: () -> Void

  var body: some View {
    HStack {
      Text(action.displaySummary)
        .font(.subheadline)
        .lineLimit(1)
      Spacer()
      Button("Undo (\(secondsRemaining)s)") { onUndo() }
        .font(.subheadline.bold())
        .foregroundStyle(.accentColor)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(Color(.systemGray6))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .padding(.horizontal)
    .transition(.move(edge: .bottom).combined(with: .opacity))
  }
}
```

---

## Implementation Strategy: What to Build and Where

### Phase 5 touches these layers (in execution order):

**1. Convex schema (new field on `chat_messages`)**
- Add `action: v.optional(v.string())` — JSON string of the action payload
- Add `actionStatus: v.optional(v.union(v.literal("pending"), v.literal("confirmed"), v.literal("cancelled")))` to `chat_messages`
- Add `role: v.literal("pending_action")` to the role union

**2. Convex chatMessages.ts (new mutations)**
- `writePendingAction` internalMutation — writes a pending_action message with action JSON
- `updateActionStatus` mutation — patches actionStatus (called from iOS on Confirm/Cancel)

**3. Convex http.ts (new endpoints)**
- `POST /loom-pending-action` — receives bridge's action payload, calls `writePendingAction`
- `GET /loom-context` — returns events, tasks, studio_events for bridge context injection

**4. Convex events.ts / tasks.ts (new internal queries)**
- `listForLoom` internalQuery on both — returns upcoming/active items in Loom-readable format

**5. bridge/loom-bridge.mjs (extended)**
- Fetch context before forwarding to OpenClaw
- Build system prompt with context
- Extract action JSON from Loom reply
- Route to `/loom-pending-action` or `/loom-reply` based on parse result

**6. LoomCal Swift models**
- Update `ChatMessage.swift` — add `action: String?` and `actionStatus: String?` fields
- Add `LoomAction.swift` — Codable struct for action payload

**7. LoomCal ChatViewModel.swift**
- `confirmAction(_ message: ChatMessage)` — parse action, call mutation, start undo timer
- `cancelAction(_ message: ChatMessage)` — update actionStatus to cancelled
- `undoAction()` — reverse the most recent action
- `startUndoTimer(for:)` — 5-second countdown with cancel
- `@Published var activeUndoAction: LoomAction?`
- `@Published var undoSecondsRemaining: Int`

**8. LoomCal CalendarViewModel.swift / TaskViewModel.swift**
- `highlightedEventId: String?` / `highlightedTaskId: String?` published properties
- `flashHighlight(eventId:)` / `flashHighlight(taskId:)` — set + clear after 2s

**9. LoomCal SwiftUI Views**
- `ActionConfirmationCard.swift` — new view rendered in ChatView for pending_action messages
- `UndoBanner.swift` — new view shown at bottom of ChatView during undo window
- Update `ChatView.swift` — differentiate pending_action messages, overlay UndoBanner
- Update `ChatBubbleView.swift` / TimelineEventCard / TaskRowView — `.highlightPulse(active:)` modifier

---

## Open Questions

1. **Undo for destructive actions (delete)**
   - What we know: Undo requires re-creating the deleted document. Convex deletes are permanent — the data is gone once the mutation runs.
   - What's unclear: Should delete be held in a "pending delete" state until the undo window expires, rather than executing immediately on Confirm? This would avoid needing to reconstruct the full document for undo.
   - Recommendation: For deletes, don't call `events:remove` immediately. Instead, mark the event as `deletePending: true` (or hide it from queries) during the undo window, then call remove when the window expires. This requires a schema addition. If this adds too much complexity for Phase 5, implement undo only for creates and updates; skip undo for deletes (just confirm immediately).

2. **Multi-action requests (e.g., "move meeting AND add dentist")**
   - What we know: The user decision doc says this is Claude's discretion (separate or combined cards)
   - What's unclear: Does the bridge handle multiple ACTION blocks in one reply? Does Loom output them?
   - Recommendation: For Phase 5, handle only single actions per reply. If Loom returns multiple ACTION blocks, process the first one and post the rest as plain text. Add multi-action support in a later phase.

3. **Context size vs. latency tradeoff**
   - What we know: Fetching all events and tasks on every poll cycle adds latency. Current poll is 2 seconds.
   - What's unclear: How many events/tasks does the user have? A large context could slow down each OpenClaw call.
   - Recommendation: Fetch context on each poll cycle but limit to events in the next 7 days and all incomplete tasks (not all events ever). Add `listForLoom` queries with appropriate date filters.

4. **System prompt location and versioning**
   - What we know: System prompt is hardcoded in the bridge script currently (Phase 4 architecture).
   - What's unclear: Should the system prompt be stored in Convex (for hot updates without bridge restart)?
   - Recommendation: Keep system prompt in the bridge script for Phase 5. Phase 6+ can move it to Convex env var if versioning becomes a concern.

---

## Sources

### Primary (HIGH confidence)
- Existing project code (read directly): `convex/events.ts`, `convex/tasks.ts`, `convex/http.ts`, `convex/chatMessages.ts`, `convex/schema.ts`, `bridge/loom-bridge.mjs`, `LoomCal/ViewModels/CalendarViewModel.swift`, `LoomCal/ViewModels/TaskViewModel.swift`, `LoomCal/ViewModels/ChatViewModel.swift`
- `https://docs.convex.dev/database/types` — Convex int64 serialized as base-10 string in JSON export
- `https://docs.convex.dev/functions/http-actions` — `ctx.runMutation` from HTTP actions, request.json() parsing
- Phase 4 RESEARCH.md (project file) — ConvexMobile mutation pattern, timeout pattern, bridge architecture

### Secondary (MEDIUM confidence)
- `https://github.com/openclaw/openclaw/issues/8923` — OpenClaw does not send `tools` to custom providers; no reliable workaround without `compat.supportedParameters` config
- `https://github.com/openclaw/openclaw/discussions/6922` — `compat.supportedParameters: ["tools", "tool_choice"]` workaround in clawd.json (requires OpenClaw 2026.2.3+)
- Apple Developer Documentation (WebSearch verified) — SwiftUI `.animation(.easeInOut.repeatCount())` for highlight pulse
- Apple Developer Documentation (WebSearch verified) — `Task.sleep` + cancel pattern for undo timer

### Tertiary (LOW confidence)
- WebSearch: OpenClaw tool calling with custom endpoints — community reports confirm issue is real; exact version fix unverified
- WebSearch: Multi-action bridge handling patterns — no authoritative source found; recommendation based on engineering judgment

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new libraries; all existing project dependencies
- Architecture: HIGH — built directly on verified existing patterns (bridge, Convex HTTP actions, ConvexMobile mutations)
- Bridge extension (JSON envelope): MEDIUM-HIGH — industry standard fallback pattern; verified as necessary given OpenClaw tool call limitation
- Confirmation flow UX: HIGH — user decisions are locked; implementation uses standard SwiftUI patterns
- Pitfalls: HIGH — derived from existing code and verified Convex docs; OpenClaw limitation verified via GitHub issue

**Research date:** 2026-02-21
**Valid until:** 2026-03-21 (stable stack; re-verify OpenClaw tool_calls support if user upgrades OpenClaw version)
