# Loom Cal

## Core Value

Manage projects, tasks and events with my AI personal assistant Loom. The app gives a way to visualize all of this and let Loom use everything she knows to plan my days and keep my sched up to date.

## Description

Morgen-clone calendar + task app for iOS/macOS built with SwiftUI and a Convex real-time backend. Integrates Apple Calendar (read-only via EventKit), Convex-native events/tasks, and a Supabase-synced studio calendar. An AI assistant ("Loom") handles chat, calendar mutations, daily planning, and natural language entry via an OpenClaw bridge. Local notifications alert for upcoming events and task deadlines.

## Tech Stack

| Technology | Role | Version/Notes |
|-----------|------|---------------|
| SwiftUI | UI framework | iOS 17+ / macOS 14+ multiplatform target |
| ConvexMobile | Real-time backend SDK | 0.8.0 |
| HorizonCalendar | Calendar grid (iOS only) | 1.16.0, `platformFilters = (ios, )` |
| Convex Cloud | Backend | Schema, queries, mutations, crons |
| Node.js bridge | Loom AI relay | `bridge/loom-bridge.mjs` polls Convex, calls OpenClaw |
| Supabase | Studio calendar source | Read-only sync into Convex via cron |
| EventKit | Apple Calendar access | On-device read-only, never stored in Convex |
| UserNotifications | Local notifications | Event reminders + task due dates |

## Architecture

### Data Flow

```
SwiftUI Views <- @Published <- ViewModels <- Convex subscriptions (WebSocket)
                                           -> Convex mutations (HTTP)
```

Single `ConvexClient` singleton created in `LoomCalApp.swift` as module-level `let convex`. All ViewModels subscribe through this one client.

### Navigation

| Platform | Navigation Pattern |
|----------|-------------------|
| iOS | TabView with native bottom tab bar (Calendar, Tasks, Loom) |
| macOS | NavigationSplitView with sidebar (Calendar, Tasks, Loom) |

### Data Ownership

| Data | Source of Truth | Access Pattern |
|------|----------------|----------------|
| events | Convex | Full CRUD |
| tasks | Convex | Full CRUD |
| chat_messages | Convex | Full CRUD |
| studio_events | Supabase | Read-only cache in Convex (synced via cron) |
| Apple Calendar | EventKit | Read-only on-device, never stored in Convex |

### Key Directories

| Directory | Contents |
|-----------|----------|
| `LoomCal/App/` | App entry point, ConvexClient singleton, deployment config |
| `LoomCal/Models/` | Decodable structs matching Convex schema tables |
| `LoomCal/ViewModels/` | `@MainActor @ObservableObject` classes with `@Published` properties |
| `LoomCal/Views/` | SwiftUI views organized by feature (Calendar/, Events/, Tasks/, Today/, Chat/) |
| `LoomCal/Services/` | EventKitService, NLParseService, NotificationService |
| `convex/` | TypeScript backend: schema.ts, query/mutation functions, cron jobs |
| `bridge/` | Node.js bridge script connecting Convex to OpenClaw gateway |

## Requirements Summary

| Category | Total | Done | Remaining |
|----------|-------|------|-----------|
| Calendar Views (CALV) | 5 | 5 | 0 |
| Task System (TASK) | 7 | 7 | 0 |
| Loom AI (LOOM) | 11 | 11 | 0 |
| Platform (PLAT) | 5 | 5 | 0 |
| **Total** | **28** | **28** | **0** |

## Constraints

- **Platform**: iOS + Mac via SwiftUI multiplatform — must feel native on both
- **Backend**: Convex (non-negotiable)
- **AI Integration**: Loom via OpenClaw bridge — not embedding an AI model in the app
- **Studio Data**: Supabase vocal studio calendar stays in Supabase — sync only
- **HorizonCalendar**: iOS-only (UIKit); macOS uses LazyVGrid fallback via `#if canImport(UIKit)`

## Key Decisions

| Decision | Phase | Impact |
|----------|-------|--------|
| NavigationSplitView for macOS, TabView for iOS | Phase 8 | Native feel on both platforms |
| NotificationService as NSObject singleton | Phase 8 | UNUserNotificationCenterDelegate for foreground banners |
| mainContent @ViewBuilder pattern | Phase 8 | Shared .task{} and .sheet{} modifiers, no duplication |
| Cancel-all + re-add notification scheduling | Phase 8 | Simple, correct; triggers on every Convex subscription update |

## Pre-PAUL History

Phases 1-4 were executed under the GSD workflow in `.planning/`. That directory is preserved as a read-only archive. See `.planning/phases/` for detailed execution history, plans, summaries, and verification reports.

---
*Last updated: 2026-02-23 after Phase 8*
