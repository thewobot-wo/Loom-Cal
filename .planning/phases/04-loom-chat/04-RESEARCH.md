# Phase 4: Loom Chat — Research

**Researched:** 2026-02-21
**Domain:** SwiftUI chat UI + Convex real-time messaging + Anthropic Claude API integration
**Confidence:** HIGH (core stack verified via Context7 and official docs)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Chat panel placement**
- Dedicated tab in the tab bar (iPhone) and sidebar (Mac) — alongside Calendar and Tasks
- One continuous conversation thread, not daily sessions or separate threads
- Full-screen chat view when on the Chat tab (standard tab behavior)
- Additionally: a floating action button (bottom-right corner) accessible from any screen that opens a compact chat sheet overlay
- Two ways to reach Loom: the tab (full experience) and the FAB (quick access from anywhere)

**Message presentation**
- Classic iMessage-style bubbles — user messages on the right (accent color), Loom messages on the left (gray)
- Loom responses support Markdown rendering (bold, lists, code blocks) rendered inside bubbles
- Timestamps grouped by time gaps (e.g., "2:30 PM" header when there's a gap) — individual messages don't show times unless tapped
- Animated three-dot typing indicator in a bubble on Loom's side while generating a reply

**Loom's personality**
- Playful and casual tone — like a buddy who's also really organized. Light personality, occasional humor.
- No greeting message on empty state — instead show tappable suggestion chips
- Suggestion chips are conversational starters scoped to Phase 4 capabilities: things like "What's on my calendar?", "Summarize my day", "How's my week look?"
- Loom has a visible name label ("Loom") and avatar/icon next to its messages

**Unavailable & error states**
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

### Deferred Ideas (OUT OF SCOPE)
- None — discussion stayed within phase scope

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| LOOM-01 | User can send messages to Loom via in-app chat | ChatViewModel sends via `chatMessages:send` mutation; message written optimistically to local state, then confirmed via subscription |
| LOOM-02 | User receives Loom responses in-app in real-time | Convex subscription on `chatMessages:list` delivers assistant messages as soon as they are written; no polling needed |
| LOOM-03 | Chat interface displays message history | `chatMessages:list` query (ordered by `by_sent_at` index) fetched on subscription start; full history available from first frame |
| LOOM-04 | App degrades gracefully when Loom is unreachable (clear status, no blocking) | `isLoomAvailable` flag in ChatViewModel; Swift `withThrowingTaskGroup` timeout pattern caps wait at 8 s; ConvexMobile subscription continues independently |

</phase_requirements>

---

## Summary

Phase 4 builds a real-time chat interface between the user and an Anthropic Claude–backed assistant ("Loom"). The data layer is already partially scaffolded: `chat_messages` schema table, `chatMessages:list` query, and `chatMessages:send` mutation exist in the Convex backend, and `ChatMessage.swift` model is defined. The work breaks into three areas: (1) Convex backend — add an `internalAction` that calls the Anthropic Messages API and writes the reply back as an assistant message; (2) Swift ViewModel — `ChatViewModel` subscribing to `chatMessages:list` and managing pending/timeout/offline state; (3) SwiftUI views — a full-screen `ChatView` tab plus a FAB+sheet overlay reachable from anywhere, with iMessage-style bubbles, typing indicator, and Markdown rendering.

The architectural pattern is well-established in the project: mutation triggers `ctx.scheduler.runAfter(0, internal.chatMessages.generateReply, ...)`, which calls the Anthropic API and then runs an internal mutation to write the assistant message. The iOS subscription picks up the new assistant message automatically. The 8-second timeout is implemented purely on the Swift side using `withThrowingTaskGroup` racing a `.sleep` against the reply arriving in the subscription, with no changes needed on the Convex side.

**Primary recommendation:** Wire the Anthropic SDK call inside a Convex `internalAction` scheduled from the `send` mutation. On the Swift side, drive all state from a single `ChatViewModel` following the exact `TaskViewModel` pattern. Use `swift-markdown-ui` (2.x, maintenance mode but stable) for Markdown rendering inside bubbles — Textual is too new (v0.1.0, December 2025). Do not build a custom timeout — use the `withThrowingTaskGroup` racing pattern.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ConvexMobile (Swift) | 0.8.0 (already in project) | Subscribe to `chatMessages:list`, call `chatMessages:send` mutation | Already in project, confirmed compatible with Xcode 16.2/iOS 18.6 |
| @anthropic-ai/sdk (TypeScript) | latest (≥0.70.0) | Call Claude Messages API from Convex internalAction | Official Anthropic SDK; supports Node.js/Deno; `process.env.ANTHROPIC_API_KEY` pattern |
| swift-markdown-ui | 2.0.2+ | Render Markdown inside Loom message bubbles | GitHub Flavored Markdown, iOS 15+, stable SPM package, well-tested in production |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Foundation `AttributedString` + SwiftUI `Text` | iOS 15+ (built-in) | Inline Markdown (bold, italic, code span) inside text if bubble content is simple | Only if bold/italic/code spans are sufficient — no block-level elements |
| swift-timeout (swhitty) | latest | Structured timeout racing for Swift async tasks | Only if the inline `withThrowingTaskGroup` pattern proves too verbose to inline |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| swift-markdown-ui 2.x | gonzalezreal/textual 0.1.0 | Textual is the spiritual successor but is v0.1.0 (December 2025 release); API may change; not recommended for production yet |
| swift-markdown-ui 2.x | Native `Text(LocalizedStringKey(markdown))` | Native approach handles only inline elements (bold, italic, code); no lists, headings, code blocks — insufficient for LLM responses |
| @anthropic-ai/sdk | Direct `fetch` to Anthropic API | SDK handles retries, typing, streaming, error classification; manual fetch is fragile |
| Convex internalAction | External webhook/n8n | internalAction keeps everything in one deployment; no separate infra to maintain |

**Installation (Convex backend):**
```bash
npm install @anthropic-ai/sdk
```

**Installation (Swift — via Xcode SPM):**
```
https://github.com/gonzalezreal/swift-markdown-ui
```
Version: 2.0.2+

---

## Architecture Patterns

### Recommended Project Structure

```
convex/
├── chatMessages.ts          # EXISTING: list query, send mutation — ADD generateReply internalAction
├── schema.ts                # EXISTING: chat_messages table — no changes needed

LoomCal/
├── Models/
│   └── ChatMessage.swift    # EXISTING — no changes needed
├── ViewModels/
│   └── ChatViewModel.swift  # NEW: mirrors TaskViewModel pattern
├── Views/
│   └── Chat/
│       ├── ChatView.swift           # NEW: full-screen tab view
│       ├── ChatBubbleView.swift     # NEW: iMessage-style bubble with Markdown
│       ├── TypingIndicatorView.swift # NEW: animated three-dot indicator
│       ├── ChatInputBar.swift       # NEW: text field + send button
│       ├── SuggestionChipsView.swift # NEW: empty state chips
│       └── ChatFAB.swift            # NEW: floating action button + sheet overlay
```

ContentView.swift will need to be updated to:
1. Add a `TabView` with Chat tab (currently it uses `NavigationStack` without tabs)
2. Add `ChatViewModel` as `@StateObject`
3. Overlay `ChatFAB` using `ZStack` over the `TabView`

### Pattern 1: Convex Mutation → Schedule → internalAction → Write Reply

This is the core async AI reply pattern, identical to the Wikipedia tutorial pattern in Convex docs:

```typescript
// Source: https://docs.convex.dev/functions/actions + Anthropic SDK
// convex/chatMessages.ts

import Anthropic from "@anthropic-ai/sdk";
import { internalAction, internalMutation, mutation, query } from "./_generated/server";
import { internal } from "./_generated/api";
import { v } from "convex/values";

// Public mutation: write user message, schedule reply generation
export const send = mutation({
  args: {
    role: v.union(v.literal("user"), v.literal("assistant")),
    content: v.string(),
  },
  handler: async (ctx, { role, content }) => {
    const id = await ctx.db.insert("chat_messages", {
      role,
      content,
      sentAt: BigInt(Date.now()),
    });
    // Only trigger AI reply for user messages
    if (role === "user") {
      await ctx.scheduler.runAfter(0, internal.chatMessages.generateReply, {});
    }
    return id;
  },
});

// Internal action: fetch history, call Anthropic, write reply
export const generateReply = internalAction({
  args: {},
  handler: async (ctx) => {
    const apiKey = process.env.ANTHROPIC_API_KEY;
    if (!apiKey) throw new Error("ANTHROPIC_API_KEY not set");

    // Load full message history for context
    const messages = await ctx.runQuery(internal.chatMessages.listForAI, {});

    const client = new Anthropic({ apiKey });
    const response = await client.messages.create({
      model: "claude-haiku-4-5",  // fast, cheap — appropriate for chat assistant
      max_tokens: 1024,
      system: "You are Loom, a playful and organized calendar assistant...",
      messages: messages.map((m) => ({
        role: m.role as "user" | "assistant",
        content: m.content,
      })),
    });

    const replyText = response.content[0].type === "text"
      ? response.content[0].text
      : "";

    await ctx.runMutation(internal.chatMessages.writeAssistantReply, {
      content: replyText,
    });
  },
});

// Internal mutation: write assistant reply
export const writeAssistantReply = internalMutation({
  args: { content: v.string() },
  handler: async (ctx, { content }) => {
    await ctx.db.insert("chat_messages", {
      role: "assistant",
      content,
      sentAt: BigInt(Date.now()),
    });
  },
});

// Internal query for AI context (all messages, no filtering)
export const listForAI = internalQuery({
  args: {},
  handler: async (ctx) => {
    return await ctx.db.query("chat_messages").withIndex("by_sent_at").collect();
  },
});
```

### Pattern 2: ChatViewModel — mirrors TaskViewModel exactly

```swift
// LoomCal/ViewModels/ChatViewModel.swift
// Source: project pattern from TaskViewModel.swift + CalendarViewModel.swift

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading: Bool = true
    @Published var pendingMessageId: String? = nil   // tracks user message awaiting reply
    @Published var isLoomAvailable: Bool = true       // false when timeout fires
    @Published var timedOutMessageIds: Set<String> = [] // shows retry error bubble

    private var subscriptionTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?

    func startSubscription() {
        subscriptionTask?.cancel()
        subscriptionTask = Task {
            for await result: [ChatMessage] in convex
                .subscribe(to: "chatMessages:list")
                .replaceError(with: [])
                .values
            {
                guard !Task.isCancelled else { break }
                let previousCount = self.messages.count
                self.messages = result
                self.isLoading = false
                // Reply arrived — clear pending state
                if result.count > previousCount,
                   result.last?.role == "assistant" {
                    self.pendingMessageId = nil
                    self.timeoutTask?.cancel()
                    self.timeoutTask = nil
                }
            }
        }
    }

    func sendMessage(_ content: String) {
        // Optimistic: pending state immediately
        let args: [String: ConvexEncodable?] = [
            "role": "user",
            "content": content
        ]
        Task {
            do {
                try await convex.mutation("chatMessages:send", with: args)
                self.pendingMessageId = content  // placeholder; real ID arrives in subscription
                self.startReplyTimeout()
            } catch {
                self.isLoomAvailable = false
            }
        }
    }

    private func startReplyTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task {
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            // No reply arrived within 8 seconds
            self.isLoomAvailable = false
            if let id = self.pendingMessageId {
                self.timedOutMessageIds.insert(id)
            }
            self.pendingMessageId = nil
        }
    }
}
```

### Pattern 3: TabView — adding Chat tab

ContentView.swift currently uses `NavigationStack` without a `TabView`. This needs to be refactored to a `TabView` with three tabs: Today/Calendar, Tasks, Chat.

```swift
// Updated ContentView.swift structure
TabView {
    // Existing calendar content wrapped in Tab
    Tab("Calendar", systemImage: "calendar") {
        CalendarNavigationView(viewModel: viewModel, taskViewModel: taskViewModel)
    }
    Tab("Tasks", systemImage: "checklist") {
        TaskListNavigationView(taskViewModel: taskViewModel)
    }
    Tab("Loom", systemImage: "bubble.left.and.bubble.right") {
        ChatView(chatViewModel: chatViewModel)
    }
}
.overlay(alignment: .bottomTrailing) {
    ChatFAB(chatViewModel: chatViewModel)
        .padding(.trailing, 20)
        .padding(.bottom, 80)  // above tab bar
}
```

### Pattern 4: 8-Second Timeout with `withThrowingTaskGroup`

The timeout is a Swift-side concern only. The project pattern uses `Task.sleep` racing approach:

```swift
// Race: subscription delivers reply vs. timeout
private func startReplyTimeout() {
    timeoutTask?.cancel()
    timeoutTask = Task {
        try? await Task.sleep(for: .seconds(8))
        guard !Task.isCancelled else { return }
        // Fires only if reply hasn't cancelled this task first
        await MainActor.run {
            self.isLoomAvailable = false
            self.pendingMessageId = nil
        }
    }
}
// In subscription loop: when assistant message arrives, call timeoutTask?.cancel()
```

### Pattern 5: iMessage Bubble with Markdown

```swift
// ChatBubbleView.swift
import MarkdownUI

struct ChatBubbleView: View {
    let message: ChatMessage

    var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 60) }

            if !isUser {
                // Loom avatar
                Circle()
                    .fill(Color.purple.gradient)
                    .frame(width: 28, height: 28)
                    .overlay(Text("L").font(.caption).fontWeight(.bold).foregroundStyle(.white))
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 2) {
                if !isUser {
                    Text("Loom")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Group {
                    if isUser {
                        Text(message.content)
                            .foregroundStyle(.white)
                    } else {
                        // Markdown for assistant messages
                        Markdown(message.content)
                            .markdownTheme(.gitHub)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isUser ? Color.accentColor : Color.gray.opacity(0.15))
                .foregroundStyle(isUser ? Color.white : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }
}
```

### Pattern 6: Typing Indicator (Three Dots)

```swift
struct TypingIndicatorView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.gray.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear { animating = true }
    }
}
```

### Pattern 7: Scroll-to-Bottom on New Messages

iOS 17+ approach using `defaultScrollAnchor`:

```swift
ScrollViewReader { proxy in
    ScrollView {
        LazyVStack(spacing: 12) {
            ForEach(messages) { message in
                ChatBubbleView(message: message)
                    .id(message._id)
            }
            if pendingMessageId != nil {
                TypingIndicatorView()
                    .id("typing-indicator")
            }
        }
        .padding()
    }
    .defaultScrollAnchor(.bottom)  // iOS 17+, starts anchored at bottom
    .onChange(of: messages.count) {
        withAnimation {
            proxy.scrollTo(messages.last?._id ?? "typing-indicator", anchor: .bottom)
        }
    }
}
```

### Anti-Patterns to Avoid

- **Polling for AI response:** Do not use Timer or DispatchQueue.asyncAfter to check for replies. The Convex subscription delivers them automatically.
- **Writing assistant message from the iOS client:** The iOS app never writes `role: "assistant"` messages directly. Only the Convex `internalAction` writes those. This maintains the data-ownership boundary.
- **Creating additional ConvexClient instances:** Project rule — one global `let convex = ConvexClient(...)`. ChatViewModel uses the same singleton.
- **GeometryReader inside ScrollView:** Project pattern — GeometryReader as root if needed, not inside ScrollView.
- **Calling Anthropic API directly from Swift:** No — all AI calls go through Convex. The API key is a backend secret, not exposed to the client.
- **Making `generateReply` a public mutation/action:** It must be `internalAction` to prevent external calls. The `send` mutation schedules it.
- **Loading entire message history for every request without limit:** For long conversations, add a `.take(N)` limit to `listForAI` or summarize history — not needed in Phase 4 but flag for Phase 5+.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Markdown in bubbles | Custom parser | swift-markdown-ui 2.x | GFM-compliant parser, handles code blocks, lists, tables — edge cases are hard |
| Typing animation | Custom timer + offsets | SwiftUI `.animation().repeatForever()` with `scaleEffect` | Standard pattern, no custom state machine |
| AI timeout | Custom DispatchQueue timer | `Task.sleep` + cancel pattern | Cooperative cancellation, no race conditions with @MainActor |
| HTTP to Anthropic | Custom fetch wrapper | `@anthropic-ai/sdk` | SDK handles retries, error classification, type safety |
| Message ordering | Manual sort | Convex `by_sent_at` index | Convex returns documents in index order — already sorted |

**Key insight:** The Convex mutation → scheduler → internalAction → write-back pattern is the standard approach for any LLM integration in Convex. Do not deviate — it handles transactional safety and prevents duplicate writes.

---

## Common Pitfalls

### Pitfall 1: TabView Refactor — Existing ContentView Assumptions

**What goes wrong:** ContentView.swift currently has a single `NavigationStack` without a `TabView`. Adding a `TabView` requires extracting the calendar content into a sub-view. The `@StateObject` ViewModels must remain at the level that encompasses all tabs — if they move into individual tab views, subscriptions restart on tab switch.

**Why it happens:** `@StateObject` lifetime is tied to the view's lifetime. If `CalendarViewModel` is created inside the Calendar tab view, switching away cancels subscriptions.

**How to avoid:** Keep all `@StateObject` ViewModels at the `ContentView` (or App) level. Pass as `@ObservedObject` into tab sub-views.

**Warning signs:** Data disappears when switching tabs, or subscriptions log reconnect messages on every tab switch.

### Pitfall 2: FAB Position Above Tab Bar

**What goes wrong:** A `ZStack` overlay with `alignment: .bottomTrailing` places the FAB at the absolute bottom, obscured by the tab bar on iPhone (typically 83pt on iPhone with home indicator, 49pt on older devices).

**How to avoid:** Use `.padding(.bottom, 80)` on the FAB or detect tab bar height via `safeAreaInsets.bottom`. The project already uses `#if !os(macOS)` guards — FAB should be iOS-only or hidden on Mac (sidebar chat tab is sufficient on Mac).

**Warning signs:** FAB is not tappable at the bottom of the screen on iPhone.

### Pitfall 3: Convex Int64 for `sentAt` in TypeScript

**What goes wrong:** `chat_messages.sentAt` is `v.int64()`. In TypeScript, writing `Date.now()` gives a JavaScript number (float64). BigInt() must wrap it: `BigInt(Date.now())`.

**Why it happens:** Already handled in the existing `chatMessages:send` mutation — but the new `writeAssistantReply` internalMutation must also use `BigInt(Date.now())`.

**How to avoid:** Follow the pattern in the existing `send` mutation exactly. Review any new mutation touching `sentAt`.

**Warning signs:** TypeScript type error: "Type 'number' is not assignable to type 'bigint'."

### Pitfall 4: Anthropic API Key Not Set Causes Silent Failure

**What goes wrong:** If `ANTHROPIC_API_KEY` is not set in the Convex dashboard, `process.env.ANTHROPIC_API_KEY` returns `undefined`. The internalAction throws but the iOS app sees no reply — just a timeout after 8 seconds with no useful error message.

**How to avoid:** Add a guard at the top of `generateReply`: if `!apiKey throw new Error("ANTHROPIC_API_KEY not set in Convex environment")`. This error appears in Convex dashboard logs. Document setup in onboarding.

**Warning signs:** 8-second timeouts on every message in a fresh install. Check Convex logs for the error.

### Pitfall 5: `ChatViewModel` startSubscription Lifetime

**What goes wrong:** If `ChatView` creates a new `ChatViewModel` via `@StateObject`, the subscription (and message history) is only alive while the Chat tab is visible. Switching away and back resets the state.

**How to avoid:** `ChatViewModel` must be a `@StateObject` in `ContentView` (or `LoomCalApp`), not in `ChatView`. Same pattern as `CalendarViewModel` and `TaskViewModel`.

### Pitfall 6: `replaceError(with: [])` Hides Offline Status

**What goes wrong:** The subscription pattern `replaceError(with: [])` silently replaces errors with an empty array. This means the app cannot detect when Convex is unreachable vs. when there are simply no messages.

**How to avoid:** For `isLoomAvailable` detection, use a separate mechanism. The AI unavailability is best detected via the 8-second timeout (Convex subscription itself stays live when Convex is reachable — the AI being offline is orthogonal to Convex connectivity). A separate health check or error handler on the `send` mutation catch block sets `isLoomAvailable = false`.

**Warning signs:** The "Loom offline" banner never appears, even when the Anthropic API key is wrong.

### Pitfall 7: Markdown View in Bubble — Width Constraint

**What goes wrong:** `Markdown()` from swift-markdown-ui renders without a max-width constraint by default. In a bubble layout, it can expand to fill the full screen width.

**How to avoid:** Wrap the `Markdown` view with `.frame(maxWidth: UIScreen.main.bounds.width * 0.75)` or use `Spacer(minLength: 60)` on the opposite side (already in the bubble pattern above).

---

## Code Examples

Verified patterns from official sources:

### Convex Environment Variable Access

```typescript
// Source: https://docs.convex.dev/production/environment-variables
const apiKey = process.env.ANTHROPIC_API_KEY;
if (!apiKey) throw new Error("ANTHROPIC_API_KEY not set");
```

Set via Convex dashboard: Deployment Settings → Environment Variables → Add `ANTHROPIC_API_KEY`.

### Anthropic Messages Create (TypeScript)

```typescript
// Source: https://platform.claude.com/docs/en/api/client-sdks
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic({ apiKey });
const response = await client.messages.create({
  model: "claude-haiku-4-5",
  max_tokens: 1024,
  system: "You are Loom, a helpful calendar assistant...",
  messages: [
    { role: "user", content: "What's on my calendar today?" }
  ],
});
const replyText = response.content[0].type === "text"
  ? response.content[0].text : "";
```

### Convex Mutation → Schedule → internalAction

```typescript
// Source: https://docs.convex.dev/functions/actions
export const send = mutation({
  handler: async (ctx, { role, content }) => {
    await ctx.db.insert("chat_messages", { role, content, sentAt: BigInt(Date.now()) });
    if (role === "user") {
      await ctx.scheduler.runAfter(0, internal.chatMessages.generateReply, {});
    }
  },
});
```

### Swift Timeout Pattern

```swift
// Source: https://gist.github.com/swhitty/9be89dfe97dbb55c6ef0f916273bbb97 (adapted)
// Racing Task.sleep vs. subscription delivering the reply
private func startReplyTimeout() {
    timeoutTask?.cancel()
    timeoutTask = Task {
        try? await Task.sleep(for: .seconds(8))
        guard !Task.isCancelled else { return }
        self.isLoomAvailable = false
        self.pendingMessageId = nil
    }
}
// Cancel on reply: called in subscription loop when assistant message arrives
timeoutTask?.cancel()
timeoutTask = nil
```

### swift-markdown-ui Basic Usage

```swift
// Source: https://github.com/gonzalezreal/swift-markdown-ui
import MarkdownUI

Markdown(message.content)
    .markdownTheme(.gitHub)
    .frame(maxWidth: 280)
```

### LazyVStack scroll-to-bottom (iOS 17+)

```swift
// Source: https://www.hackingwithswift.com/quick-start/swiftui/
ScrollView {
    LazyVStack {
        ForEach(messages) { msg in
            ChatBubbleView(message: msg).id(msg._id)
        }
    }
}
.defaultScrollAnchor(.bottom)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `ScrollViewReader` + manual `scrollTo` on every message | `.defaultScrollAnchor(.bottom)` on `ScrollView` | iOS 17 (2023) | Eliminates scroll glitches on first appear; manual scroll still needed for new messages arriving |
| Polling for AI replies with Timer | Convex subscription delivers assistant messages reactively | Always been the Convex way | No polling code needed |
| Webhook to external server for AI calls | Convex `internalAction` with `ctx.scheduler` | Convex v1+ | All infra in one deployment; transactional |
| swift-markdown-ui as primary Markdown library | swift-markdown-ui in maintenance, Textual 0.1.0 as successor | December 2025 | Use swift-markdown-ui 2.x now; plan migration to Textual when it reaches 1.0 |

**Deprecated/outdated:**
- `ScrollViewReader` + `proxy.scrollTo` in `.onReceive`: Still works but unnecessary with `defaultScrollAnchor(.bottom)` for initial positioning.
- Textual 0.1.0: Too new for production. API may change. Revisit in Phase 5 or 6.

---

## Open Questions

1. **Claude model selection for the assistant**
   - What we know: `claude-haiku-4-5` is fast and cheap — appropriate for a conversational assistant. `claude-sonnet-4-5` provides better reasoning.
   - What's unclear: Whether Phase 4 needs reasoning (just conversational) or will need tool use for Phase 5 anyway.
   - Recommendation: Use `claude-haiku-4-5` for Phase 4 (chat only). The model can be upgraded to `claude-sonnet-4-5` in Phase 5 when tool use is added. Make the model name a Convex environment variable (`LOOM_MODEL`) so it can be changed without redeploy.

2. **Conversation history window**
   - What we know: `listForAI` fetches the full message history. For short conversations this is fine.
   - What's unclear: At what message count does the context window become a cost/latency concern?
   - Recommendation: For Phase 4, send all messages (reasonable for early users). Add a `.take(50)` limit as a guard. Summarization is a Phase 6+ concern.

3. **ContentView → TabView refactor scope**
   - What we know: ContentView.swift uses `NavigationStack` without `TabView`. All calendar logic is in ContentView directly.
   - What's unclear: How much refactoring is needed to extract calendar content into a sub-view — whether it breaks the drag-to-time-block PreferenceKey flow.
   - Recommendation: Extract calendar content into `CalendarTabView.swift` that takes `viewModel` and `taskViewModel` as parameters. The TodayView PreferenceKeys operate within their own subtree — extracting into a sub-view should not affect them.

4. **Mac sidebar pattern for Chat tab**
   - What we know: The project uses `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD`. On Mac, a tab bar renders as a sidebar automatically.
   - What's unclear: Whether the FAB should be hidden on Mac (sidebar chat is the primary access).
   - Recommendation: Hide FAB on Mac using `#if !os(macOS)` guard — the dedicated Chat tab in the sidebar is sufficient.

---

## Sources

### Primary (HIGH confidence)
- `/get-convex/convex-mobile` (Context7) — subscription pattern, mutation pattern, error types
- `/llmstxt/convex_dev_llms_txt` (Context7) — internalAction, scheduler.runAfter, mutation-triggers-action pattern
- `https://platform.claude.com/docs/en/api/client-sdks` — Anthropic TypeScript SDK install, `messages.create` API, model names
- `https://docs.convex.dev/production/environment-variables` — `process.env.ANTHROPIC_API_KEY` pattern
- `https://github.com/gonzalezreal/swift-markdown-ui/blob/main/README.md` — installation, iOS 15+ requirement, maintenance mode status
- `https://gist.github.com/swhitty/9be89dfe97dbb55c6ef0f916273bbb97` — Swift Task timeout pattern

### Secondary (MEDIUM confidence)
- WebSearch: swift-markdown-ui maintenance mode confirmed, Textual 0.1.0 December 2025 release — cross-verified via GitHub repo fetch
- WebSearch: SwiftUI `defaultScrollAnchor(.bottom)` iOS 17 — mentioned in multiple SwiftUI tutorials
- WebSearch: `TabView` + `ZStack` overlay for FAB — standard SwiftUI community pattern

### Tertiary (LOW confidence)
- WebSearch: claude-haiku model performance for chat assistants — community consensus, not benchmarked for this use case

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — ConvexMobile and Anthropic SDK verified against official docs; swift-markdown-ui status confirmed via GitHub fetch
- Architecture: HIGH — internalAction + scheduler pattern verified in Context7 Convex docs; Swift patterns match existing project code directly
- Pitfalls: MEDIUM-HIGH — most derived from project's own accumulated decisions + verified Convex/Swift patterns; FAB positioning is LOW (screen geometry varies)

**Research date:** 2026-02-21
**Valid until:** 2026-03-21 (stable stack; swift-markdown-ui maintenance mode is stable; re-check Textual version before Phase 5)
