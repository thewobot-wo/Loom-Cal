# Architecture Research

**Domain:** SwiftUI multiplatform calendar/task management app with Convex backend and AI assistant
**Researched:** 2026-02-20
**Confidence:** MEDIUM (Convex Swift SDK verified HIGH; Telegram integration pattern MEDIUM; overall system design inferred from components)

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER                                  │
├──────────────────────────────┬──────────────────────────────────────┤
│         iOS App              │           macOS App                  │
│  ┌──────────────────────┐    │  ┌──────────────────────────────┐    │
│  │  SwiftUI Views       │    │  │  SwiftUI Views               │    │
│  │  (iOS-specific)      │    │  │  (Mac-specific windows/menu) │    │
│  └──────────┬───────────┘    │  └──────────┬─────────────────────┘  │
│             │                │             │                         │
│  ┌──────────▼───────────────────────────────▼─────────────────────┐ │
│  │              Shared SwiftUI Views + ViewModels                  │ │
│  │   CalendarVM  │  TaskVM  │  ChatVM  │  PlanningVM               │ │
│  └───┬───────────┴────┬─────┴────┬─────┴────┬────────────────────┘ │
│      │                │          │           │                       │
│  ┌───▼───────────────────────────▼───────────▼────────────────────┐ │
│  │                    Service Layer (Shared)                       │ │
│  │  EventKitService │ ConvexService │ TelegramService │ SyncService│ │
│  └───┬──────────────┴──────┬────────┴────────┬────────────────────┘ │
└──────┼─────────────────────┼─────────────────┼──────────────────────┘
       │                     │                 │
┌──────▼──────┐   ┌──────────▼─────────┐  ┌───▼─────────────────────┐
│ Apple       │   │  Convex Backend    │  │  Telegram Bot API        │
│ Calendar    │   │  (Convex Cloud)    │  │  (api.telegram.org)      │
│ (EventKit)  │   │                   │  │       │                   │
└─────────────┘   │  Functions layer  │  │  Loom AI (local gateway) │
                  │  events | tasks   │  └─────────────────────────┘
                  │  projects | chat  │
                  │  studio_events    │
                  └────────────┬──────┘
                               │ Loom reads/writes via MCP
                  ┌────────────▼──────┐
                  │  Supabase         │
                  │  (vocal studio    │
                  │   calendar data)  │
                  └───────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| SwiftUI Views (iOS) | Platform-specific layout, navigation, touch interactions | NavigationStack, TabView, calendar scroll views |
| SwiftUI Views (macOS) | Window management, sidebar navigation, menu bar | NavigationSplitView, toolbar, NSMenuItem wrappers |
| Shared SwiftUI Views | Cross-platform UI components (event cards, task rows, chat bubbles) | View structs with #if os() for fine-grained differences |
| ViewModels | State ownership, business logic, service coordination | @Observable classes (iOS 17+) or ObservableObject for iOS 16 |
| EventKitService | Read Apple Calendar events, write new events, request permissions | EKEventStore singleton, one per app lifetime |
| ConvexService | Real-time subscriptions to tasks/projects/events, mutations | ConvexClient singleton, Combine publishers → async sequences |
| TelegramService | Send messages to Loom bot, poll or receive responses | URLSession + async/await HTTP to api.telegram.org |
| SyncService | Coordinate EventKit ↔ Convex view merging, change detection | Merge logic, deduplication, conflict resolution |
| Convex Backend | Serverless functions for CRUD, real-time reactive queries | TypeScript functions, schema-validated document store |
| Loom (external) | AI reasoning, planning, Supabase↔Convex sync, event management | Telegram bot on local gateway, uses Convex MCP + Supabase MCP |

## Recommended Project Structure

```
LoomCal/
├── App/
│   ├── LoomCalApp.swift          # App entry point, ConvexClient init
│   ├── AppDependencies.swift     # Dependency injection container
│   └── AppEnvironment.swift      # Environment values (convexClient, etc.)
│
├── Shared/                       # All code shared between iOS and macOS
│   ├── Features/
│   │   ├── Calendar/
│   │   │   ├── CalendarView.swift          # Shared calendar grid/list
│   │   │   ├── CalendarViewModel.swift     # Merges EventKit + Convex events
│   │   │   ├── EventDetailView.swift       # Event detail sheet
│   │   │   └── EventDetailViewModel.swift
│   │   ├── Tasks/
│   │   │   ├── TaskListView.swift
│   │   │   ├── TaskListViewModel.swift
│   │   │   ├── TaskDetailView.swift
│   │   │   └── ProjectListView.swift
│   │   ├── Chat/
│   │   │   ├── ChatView.swift              # Loom chat interface
│   │   │   ├── ChatViewModel.swift         # Telegram send/receive
│   │   │   └── ChatBubble.swift
│   │   └── DailyPlan/
│   │       ├── DailyPlanView.swift         # AI-generated day layout
│   │       └── DailyPlanViewModel.swift
│   │
│   ├── Services/
│   │   ├── ConvexService.swift             # Convex subscriptions + mutations
│   │   ├── EventKitService.swift           # Apple Calendar read/write
│   │   ├── TelegramService.swift           # Loom bot HTTP client
│   │   └── SyncService.swift              # Merge EventKit + Convex data
│   │
│   ├── Models/
│   │   ├── UnifiedEvent.swift              # Merged calendar event (any source)
│   │   ├── ConvexEvent.swift               # Convex-native event Decodable
│   │   ├── ConvexTask.swift                # Task Decodable
│   │   ├── ConvexProject.swift             # Project Decodable
│   │   ├── StudioEvent.swift               # Vocal studio event (from Convex)
│   │   └── ChatMessage.swift               # Telegram message Decodable
│   │
│   └── Common/
│       ├── Extensions/
│       ├── Components/                     # Reusable UI atoms
│       └── Utilities/
│
├── iOS/                                    # iOS-only code
│   ├── Navigation/
│   │   └── iOSRootView.swift              # TabView-based navigation
│   ├── Platform/
│   │   └── iOSCalendarAdapter.swift       # iOS-specific calendar gestures
│   └── Widgets/                           # iOS Home Screen widgets
│
└── macOS/                                  # macOS-only code
    ├── Navigation/
    │   └── macOSRootView.swift            # NavigationSplitView sidebar
    ├── Platform/
    │   └── macOSMenuBar.swift             # Menu bar extras
    └── Windows/
        └── QuickEntryWindow.swift         # Floating quick-add window
```

### Structure Rationale

- **Shared/Features/:** Feature-first organization — each feature owns its views and viewmodels. Makes adding features without cross-contamination straightforward.
- **Shared/Services/:** Services are singletons injected via SwiftUI Environment. Not embedded in ViewModels to allow testing and reuse.
- **Shared/Models/:** All Convex `Decodable` structs live here. `UnifiedEvent` is the crucial merge type that normalizes EventKit + Convex + Supabase-synced events.
- **iOS/ and macOS/:** Only truly platform-specific code (navigation shell, menu bar, widgets). Keep these thin — the goal is 85%+ shared code.

## Architectural Patterns

### Pattern 1: Single ConvexClient as App-Scoped Dependency

**What:** Instantiate one `ConvexClient` at app startup and pass it into the SwiftUI environment. All ViewModels receive it via injection, never create their own.

**When to use:** Always — multiple clients create multiple WebSocket connections and duplicate subscriptions.

**Trade-offs:** Requires discipline to thread the client through environment; pays off in connection efficiency and testability.

**Example:**
```swift
// LoomCalApp.swift
@main
struct LoomCalApp: App {
    let convex = ConvexClient(deploymentUrl: ProcessInfo.processInfo
        .environment["CONVEX_URL"] ?? "")

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.convexClient, convex)
        }
    }
}

// In a ViewModel
class TaskListViewModel: ObservableObject {
    @Published var tasks: [ConvexTask] = []
    private let convex: ConvexClient

    init(convex: ConvexClient) {
        self.convex = convex
    }

    func startListening() async {
        for await tasks: [ConvexTask] in convex
            .subscribe(to: "tasks:list")
            .replaceError(with: [])
            .values {
            self.tasks = tasks
        }
    }
}
```

### Pattern 2: UnifiedEvent as the Single Display Model

**What:** Never render `EKEvent` and `ConvexEvent` separately. Merge them into a `UnifiedEvent` struct in `SyncService` before any view sees the data.

**When to use:** Whenever displaying events on the calendar. The calendar view binds only to `[UnifiedEvent]`.

**Trade-offs:** Adds a mapping layer but eliminates conditional rendering throughout the UI and simplifies the calendar view dramatically.

**Example:**
```swift
struct UnifiedEvent: Identifiable {
    enum Source { case appleCalendar(String), convex(String), studio(String) }
    let id: String
    let source: Source
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarColor: Color
    var isEditable: Bool {
        // Studio events and Apple Calendar events with write access
        if case .studio(_) = source { return false }
        return true
    }
}

// SyncService merges arrays
func mergedEvents(for date: Date) -> [UnifiedEvent] {
    let ekEvents = eventKitService.events(for: date).map(UnifiedEvent.init)
    let convexEvents = convexEvents.filter { isSameDay($0.startDate, date) }.map(UnifiedEvent.init)
    return (ekEvents + convexEvents).sorted { $0.startDate < $1.startDate }
}
```

### Pattern 3: TelegramService as a Simple HTTP Client (not an SDK)

**What:** Implement Telegram communication as two focused methods — `sendMessage(text:)` and `pollForResponse(afterMessageId:)` — using plain URLSession async/await. Do not use a Telegram Swift SDK.

**When to use:** The app only needs to talk to one specific bot (Loom). A full SDK is overkill and introduces unnecessary complexity.

**Trade-offs:** More manual work than an SDK, but results in a minimal, auditable 100-line service that does exactly what's needed.

**Example:**
```swift
actor TelegramService {
    private let botToken: String
    private let chatId: String  // The user's Telegram chat ID with Loom
    private let baseURL = "https://api.telegram.org"

    func sendMessage(_ text: String) async throws -> Int {
        // POST /bot{token}/sendMessage
        // Returns message_id for tracking the conversation turn
    }

    func pollForResponse(afterUpdateId: Int) async throws -> TelegramMessage? {
        // GET /bot{token}/getUpdates?offset={updateId+1}&timeout=30
        // Long-poll for Loom's reply; returns nil if timeout with no response
    }
}
```

### Pattern 4: ObservableObject over @Observable for Convex ViewModels

**What:** Use `ObservableObject` with `@Published` for ViewModels that own Convex subscriptions, rather than the newer `@Observable` macro.

**When to use:** Current Convex Swift documentation explicitly recommends `ObservableObject` "due to some current quirks" with `@Observable` and Combine publishers. Re-evaluate when Convex Swift SDK updates.

**Trade-offs:** `@Observable` is cleaner and more performant, but compatibility with Convex's Combine publisher pattern is not yet confirmed. Stability matters more than modernity here.

## Data Flow

### Calendar View Render Flow

```
App Launch
    ↓
EventKitService.requestPermission()
    ↓
ConvexService subscribes to:
  - tasks:list (with due dates)
  - events:list (Convex-native events)
  - studio_events:list (synced from Supabase by Loom)
    ↓ (real-time, stays open)
SyncService.mergedEvents(for: selectedDate)
    ↓
CalendarViewModel.displayEvents: [UnifiedEvent]
    ↓
CalendarView renders unified timeline
```

### Chat with Loom Flow

```
User types message in ChatView
    ↓
ChatViewModel.send(text:)
    ↓
TelegramService.sendMessage(text:)
    → POST api.telegram.org/bot{token}/sendMessage
    ↓ (returns message_id)
TelegramService.pollForResponse(afterUpdateId:)
    → GET api.telegram.org/bot{token}/getUpdates (long poll, 30s timeout)
    ↓ (Loom processes, may mutate Convex data, then replies via Telegram)
ChatViewModel receives reply text
    ↓
ChatView displays Loom's response bubble
    ↓ (simultaneously)
ConvexService publishers fire if Loom mutated any tasks/events
    ↓
CalendarView / TaskView update reactively via Convex real-time sync
```

### Task Creation (Direct, No AI) Flow

```
User fills TaskDetailView form
    ↓
TaskDetailViewModel.save()
    ↓
ConvexService.mutation("tasks:create", with: taskData)
    → Convex backend validates + writes
    ↓
tasks:list subscription fires on all subscribed clients
    ↓
TaskListViewModel.tasks updates via Publisher
    ↓
TaskListView re-renders
```

### Loom-Initiated Data Change Flow

```
Loom AI (on local gateway, via Telegram)
    ↓ (uses Convex MCP tool)
Convex backend mutation (e.g., creates new task)
    ↓
Convex reactive query fires for all subscribers
    ↓
iOS/macOS ConvexService publisher emits new value
    ↓
ViewModel @Published property updates
    ↓
SwiftUI view re-renders — user sees Loom's action reflected immediately
```

### Studio Event Sync Flow (Loom-mediated)

```
Supabase vocal studio calendar changes
    ↓ (Loom polls or webhooks from Supabase, schedule TBD)
Loom reads via Supabase MCP
    ↓
Loom writes to Convex via Convex MCP (studio_events table)
    ↓
Convex reactive query fires
    ↓
App displays studio events in unified calendar view
```

### Key Data Flows Summary

1. **EventKit → App (read-only):** EKEventStore → EventKitService → SyncService → CalendarViewModel. Apple Calendar events are never written to Convex; they exist only in memory during the session.
2. **Convex → App (real-time):** WebSocket subscription → Combine Publisher → async sequence → ViewModel @Published → SwiftUI re-render. This path is always live.
3. **App → Convex (writes):** User action → ViewModel → ConvexService.mutation → Convex backend. No local optimistic updates required for MVP.
4. **App → Loom:** URLSession POST to Telegram Bot API → Loom processes → Telegram reply. Long-poll for response.
5. **Loom → Convex → App:** Loom mutates Convex via MCP → Convex reactive query fires → App updates. This is the AI-native update path.
6. **Supabase → Convex (Loom-mediated):** Loom is the only component that touches Supabase. App never connects to Supabase directly.

## Convex Data Model

### Tables

```typescript
// schema.ts (TypeScript, Convex backend)
events: {           // Convex-native events (not from Apple Calendar)
  title: string
  startTime: number      // Unix timestamp ms
  endTime: number
  description?: string
  calendarSet?: string   // Which calendar set this belongs to
  isTimeBlocked: boolean // Was this time-blocked from a task?
  taskId?: Id<"tasks">   // Link if time-blocked
}

tasks: {
  title: string
  notes?: string
  projectId?: Id<"projects">
  dueDate?: number       // Unix timestamp ms
  scheduledDate?: number // When user plans to work on it
  status: "todo" | "in_progress" | "done"
  priority: "low" | "normal" | "high"
  estimatedMinutes?: number
}

projects: {
  title: string
  description?: string
  color?: string
  status: "active" | "completed" | "archived"
}

studio_events: {    // Synced from Supabase by Loom — treat as read-only in app
  title: string
  studentName?: string
  startTime: number
  endTime: number
  isRecurring: boolean
  supabaseId: string     // Original Supabase record ID for deduplication
  lastSyncedAt: number
}

chat_messages: {    // Optional: log of Loom conversation for display
  text: string
  sender: "user" | "loom"
  timestamp: number
  telegramMessageId?: number
}
```

### Swift Model Structs (Decodable)

```swift
struct ConvexTask: Decodable, Identifiable {
    var id: String
    var title: String
    var notes: String?
    var status: TaskStatus
    var dueDate: Double?   // Convex timestamps as Double, convert to Date
    @ConvexInt var estimatedMinutes: Int?  // Use wrapper for Int fields

    enum CodingKeys: String, CodingKey {
        case id = "_id"    // Convex uses _id field name
        case title, notes, status, dueDate, estimatedMinutes
    }
}
```

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Convex (cloud) | WebSocket via ConvexClient SDK; single client instance | Handles reconnection automatically; connection drops cause subscription gaps |
| Apple Calendar (EventKit) | EKEventStore singleton; request full access on first use | iOS 17+ requires `requestFullAccessToEvents()`; macOS has same API |
| Telegram Bot API | Plain HTTPS via URLSession async/await; no SDK | Bot token + user chat_id stored in app keychain; poll with 30s timeout |
| Supabase | No direct connection from app — Loom-only | App reads Supabase data only via studio_events table in Convex |
| Loom local gateway | Via Telegram Bot API only — not direct network call | Must handle unreachable state gracefully (local network, VPN off) |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| ViewModel ↔ ConvexService | Async sequence from Publisher.values; mutation calls | One direction: service owns the publisher, ViewModel iterates it |
| ViewModel ↔ EventKitService | Async function calls returning [EKEvent] | Not reactive — call on view appear and on EKEventStore change notification |
| ViewModel ↔ TelegramService | Async throws functions for send/poll | TelegramService is an actor to serialize concurrent requests |
| SyncService ↔ EventKit + Convex | Pulls from both, returns merged array | Pure function, no side effects — easier to test |
| iOS views ↔ macOS views | No direct communication — shared ViewModels only | Platform shells are thin wrappers around shared feature views |

## Scaling Considerations

This is a single-user personal app. Scaling is not a concern in the traditional sense. The relevant constraints are:

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 1 user (target) | Current architecture is appropriate. No optimization needed. |
| Multiple users (future) | Add Convex Auth before exposing any user-specific data. Add userId to all tables. |
| Large calendar history | Convex queries should filter by date range — never load all events unbounded. |

### Real Bottlenecks for This App

1. **Telegram poll latency:** Long-polling introduces 1-30s delay for Loom responses. This is inherent to the architecture. Mitigate with a loading indicator and streaming display if Loom sends partial messages.
2. **EventKit sync on launch:** Fetching events from EKEventStore is synchronous-ish and can block. Do it in a background task, show skeleton state until ready.
3. **Loom unreachability:** Local gateway offline means chat is unavailable. App must degrade gracefully — show "Loom is offline" state in chat, rest of app stays functional.

## Anti-Patterns

### Anti-Pattern 1: Separate EventKit and Convex Display Paths

**What people do:** Render `EKEvent` objects in one section of the calendar and `ConvexEvent` objects in another, keeping them distinct throughout the UI.

**Why it's wrong:** Results in duplicated calendar rendering logic, inconsistent styling, impossible to implement unified sorting/filtering, and fragile when adding a third source (studio events).

**Do this instead:** Always merge into `UnifiedEvent` in `SyncService` before any view sees the data. The view layer knows nothing about event sources.

### Anti-Pattern 2: Multiple ConvexClient Instances

**What people do:** Create a `ConvexClient` inside each ViewModel or View that needs data.

**Why it's wrong:** Each client opens its own WebSocket connection to Convex. With 4+ ViewModels active simultaneously, that's 4+ persistent WebSocket connections — wasteful and causes subscription conflicts.

**Do this instead:** One `ConvexClient` at app scope, injected via SwiftUI environment. All subscriptions share one connection.

### Anti-Pattern 3: Storing Apple Calendar Events in Convex

**What people do:** Mirror EventKit events into Convex for "unified storage."

**Why it's wrong:** Creates a sync problem — EventKit is the source of truth for Apple Calendar. Duplicate storage requires change detection, conflict resolution, and bidirectional sync. EventKit already provides real-time change notifications.

**Do this instead:** Read Apple Calendar events from EventKit at render time. Only persist to Convex what Convex owns: tasks, projects, Convex-native events.

### Anti-Pattern 4: Blocking on Loom Response Before Confirming User Action

**What people do:** When user sends a message to Loom, disable the UI until Loom responds.

**Why it's wrong:** Loom runs on a local gateway. Any network hiccup — VPN off, gateway asleep — causes the app to appear frozen. Telegram's long-poll can take 30 seconds to time out.

**Do this instead:** Optimistically add the user's message to the chat display immediately on send. Show a "waiting for Loom" indicator that can be dismissed. If poll times out, show a retry option.

### Anti-Pattern 5: Fetching All Tasks/Events Without Date Filtering

**What people do:** Subscribe to `tasks:list` with no parameters, loading all tasks ever created.

**Why it's wrong:** Over time, the dataset grows unbounded. Convex queries must be bounded to remain performant.

**Do this instead:** Always filter by date range and/or status. Load "this week + next 2 weeks" of events. Load "active" tasks (not completed). Paginate historical data if needed.

## Build Order Implications

The architecture has clear dependency layers that dictate build order:

**Layer 1 — Foundation (build first):**
- `ConvexService` with basic subscription + mutation
- `EventKitService` with permission request and event fetch
- Convex backend schema (events, tasks, projects tables)
- `UnifiedEvent` model and `SyncService` merge logic

**Layer 2 — Core Features (build second, requires Layer 1):**
- `CalendarViewModel` consuming merged events
- `TaskListViewModel` consuming Convex tasks
- Basic calendar view (day/week display)
- Basic task list view

**Layer 3 — AI Integration (build third, requires Layer 2 for context):**
- `TelegramService` HTTP client
- `ChatViewModel` with send/poll loop
- Chat UI
- Loom-triggered Convex mutation handling (already works via subscriptions)

**Layer 4 — Platform Polish (can be built in parallel with Layer 3):**
- iOS-specific navigation shell
- macOS NavigationSplitView shell
- Platform-specific calendar gestures/interactions
- Notifications

**Layer 5 — Advanced Features (build last):**
- Time-blocking (drag task → calendar slot → create Convex event)
- Travel/buffer time automation
- Calendar set customization
- Studio event display (requires Loom sync pipeline to be operational)

## Sources

- [Convex Swift Client Docs](https://docs.convex.dev/client/swift) — HIGH confidence, official Convex documentation
- [Convex Swift Quickstart](https://docs.convex.dev/quickstart/swift) — HIGH confidence, official Convex documentation
- [Introducing Convex for Swift](https://stack.convex.dev/introducing-convex-for-swift) — HIGH confidence, official Convex engineering blog
- [Convex Swift Data Types](https://docs.convex.dev/client/swift/data-types) — HIGH confidence, official Convex documentation
- [EventKit Apple Developer Documentation](https://developer.apple.com/documentation/eventkit) — HIGH confidence, official Apple docs
- [Telegram Bot API Reference](https://core.telegram.org/bots/api) — HIGH confidence, official Telegram documentation
- [Food Truck: SwiftUI Multiplatform Sample](https://developer.apple.com/documentation/SwiftUI/food-truck-building-a-swiftui-multiplatform-app) — HIGH confidence, official Apple sample
- [SwiftUI MVVM with ObservableObject](https://www.vadimbulavin.com/modern-mvvm-ios-app-architecture-with-combine-and-swiftui/) — MEDIUM confidence, well-regarded community source verified against Apple patterns
- [Convex Relationship Schemas](https://stack.convex.dev/relationship-structures-let-s-talk-about-schemas) — HIGH confidence, official Convex engineering blog

---
*Architecture research for: Loom Cal — SwiftUI multiplatform calendar/task app*
*Researched: 2026-02-20*
