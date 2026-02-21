# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Summary

Loom Cal is a Morgen-clone calendar + task app for iOS/macOS built with SwiftUI and a Convex real-time backend. It integrates Apple Calendar (read-only via EventKit), Convex-native events/tasks, and a Supabase-synced studio calendar. An AI assistant ("Loom") is planned for chat, calendar mutations, and daily planning.

## Build & Run

### Swift App (Xcode)
- Open `LoomCal.xcodeproj` in Xcode
- Single multiplatform target builds for iOS 17+ and macOS 14+
- Dependencies (ConvexMobile 0.8.0, HorizonCalendar 1.16.0) resolve via SPM on first build
- No test targets exist yet

### Convex Backend
```bash
npm install              # one-time setup
npx convex dev           # starts dev server, watches convex/ for changes, generates types
```
- Convex deployment URL is hardcoded in `LoomCal/App/ConvexEnv.swift`
- Environment variables for Supabase sync are set in the Convex dashboard, not `.env.local`

## Architecture

### Data Flow
```
SwiftUI Views ← @Published ← ViewModels ← Convex subscriptions (WebSocket)
                                         → Convex mutations (HTTP)
```

A single `ConvexClient` singleton is created in `LoomCalApp.swift` as a module-level `let convex`. All ViewModels subscribe through this one client. Never create additional `ConvexClient` instances.

### Data Ownership Rules (strict boundaries, no overlap)
| Data | Source of Truth | Access Pattern |
|------|----------------|----------------|
| events | Convex | Full CRUD |
| tasks | Convex | Full CRUD |
| chat_messages | Convex | Full CRUD |
| studio_events | Supabase | Read-only cache in Convex (synced via cron every 15 min) |
| Apple Calendar | EventKit | Read-only on-device, never stored in Convex |

### Key Source Directories
- `LoomCal/App/` — App entry point, ConvexClient singleton, deployment config
- `LoomCal/Models/` — Decodable structs matching Convex schema tables
- `LoomCal/ViewModels/` — `@MainActor @ObservableObject` classes with `@Published` properties
- `LoomCal/Views/` — SwiftUI views organized by feature (Calendar/, Events/, Tasks/, Today/)
- `LoomCal/Services/` — EventKitService (Apple Calendar), NLEventParser (date extraction)
- `convex/` — TypeScript backend: schema.ts, query/mutation functions, cron jobs

### Convex Schema
All timestamps are `v.int64()` storing UTC milliseconds. Durations are `v.int64()` in minutes. See `convex/schema.ts` for full table definitions.

## Critical Patterns

### ConvexMobile in Swift
- Mutations require explicitly typed args: `[String: ConvexEncodable?]` — the type annotation is mandatory or the compiler infers wrong types
- Use `@ConvexInt` property wrapper for `v.int64()` fields, `@OptionalConvexInt` for optional int64 fields
- Subscription pattern: `for await items in convex.subscribe(to: "query:name").replaceError(with: []).values { ... }`
- Int fields: Swift `Int` → SDK encodes as BigInt for `v.int64()`

### SwiftUI Layout Rules
- `GeometryReader` MUST be the ROOT view of a body/closure — never nest inside `ScrollView`
- For ScrollView content sizing, use `Color.clear.frame(height:)` as first child in a `ZStack`
- Use `.alert` instead of `.confirmationDialog` when inside nested sheets (confirmationDialog breaks)

### Platform Guards
- HorizonCalendar has `platformFilters = (ios, )` in pbxproj — it's UIKit-only
- Use `#if canImport(UIKit)` for UIKit-dependent code
- Use `#if !os(macOS)` for iOS-only features
- macOS uses `LazyVGrid` fallback where HorizonCalendar is unavailable

## Planning & Workflow

The project uses a GSD (Get Stuff Done) workflow tracked in `.planning/`:
- `PROJECT.md` — Project overview, core value proposition, constraints
- `ROADMAP.md` — All 8 phases with success criteria and dependency graph
- `STATE.md` — Current progress, velocity metrics, accumulated context
- `phases/NN-name/` — Per-phase context, research, plans, summaries, verification

Phases 1-3 are complete (Foundation, Calendar Views, Task System). Phase 4 (Loom Chat) is next.

Use `/gsd:progress` to check current status and route to the appropriate next action.
