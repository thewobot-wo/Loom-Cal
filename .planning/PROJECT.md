# Loom Cal

## What This Is

A full-featured calendar and task management app for iOS and Mac — a Morgen clone powered by Loom, a personal AI assistant that runs as a Telegram bot on a local gateway. Loom Cal unifies Apple Calendar events, a Supabase-hosted vocal studio calendar, and built-in project/task management into one native interface. Convex serves as the backend data layer; Loom manages and orchestrates data across Convex and Supabase via MCPs.

## Core Value

One app where you see everything on your plate — calendars, tasks, projects — and chat with Loom to actively manage your day.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Unified calendar view (Apple Calendar + vocal studio + Convex-native events)
- [ ] Built-in project and task management
- [ ] In-app chat with Loom AI assistant (via Telegram bot integration)
- [ ] AI daily planning — Loom recommends how to fill the day based on tasks, events, and priorities
- [ ] Supabase ↔ Convex sync for vocal studio events (Loom as the sync bridge via MCPs)
- [ ] Native iOS and Mac apps (SwiftUI multiplatform)
- [ ] Convex backend for all app data (events, tasks, projects, chat history)
- [ ] Time-blocking — schedule tasks directly into calendar slots
- [ ] Travel time and buffer time automation around events
- [ ] Customizable calendar sets (view calendars together, separately, or in subsets)
- [ ] Reminders and notifications for events and tasks
- [ ] Task due dates visible on calendar
- [ ] Loom can create, edit, and delete events and tasks through conversation

### Out of Scope

- Scheduling links (Calendly-like share-a-link booking) — not needed, books manually or through Loom
- Web app — native iOS and Mac only for v1
- Android support — iOS/Mac first
- Third-party task tool integrations (Todoist, Notion, Linear) — Loom Cal IS the task manager
- OAuth/Google Calendar — Apple Calendar is the primary calendar provider
- Team features (shared calendars, team availability) — personal use only for v1

## Context

- **Loom** is a partially-built AI assistant running as a Telegram bot on a local network gateway (OpenClaw-based). It can hold conversations, manage reminders, and track what the user is working on.
- **Vocal studio calendar** lives in Supabase — tracks student lesson schedules (times, names, recurring slots). Must remain in Supabase for the studio's needs; Loom syncs it into Convex for the app.
- **Convex** chosen as the backend — provides real-time sync, which pairs well with a calendar app's need for live updates.
- **Convex MCP** and **Supabase MCP** are the bridge — Loom uses these to read/write data in both systems, acting as the synchronization layer.
- User currently manages tasks conversationally through Loom in Telegram but wants a proper visual interface for calendars, tasks, and projects.
- User occasionally uses Things 3 but not consistently — Loom Cal replaces the need for a separate task app.

## Constraints

- **Platform**: iOS and Mac via SwiftUI multiplatform — must feel native on both
- **Backend**: Convex (non-negotiable — already chosen)
- **AI Integration**: Loom via Telegram bot API — not embedding an AI model in the app
- **Studio Data**: Supabase vocal studio calendar must stay in Supabase — sync only, no migration
- **Local Gateway**: Loom runs on a local machine — app needs to handle when Loom is unreachable

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Convex as backend | Real-time sync, user preference | — Pending |
| SwiftUI multiplatform (iOS + Mac) | Native feel on both platforms, shared codebase | — Pending |
| Loom integration via Telegram | Existing infrastructure, avoids rebuilding AI layer | — Pending |
| Supabase sync via Loom MCPs | Studio data must stay in Supabase, Loom bridges both | — Pending |
| Built-in task management | Replace inconsistent use of external tools | — Pending |

---
*Last updated: 2026-02-20 after initialization*
