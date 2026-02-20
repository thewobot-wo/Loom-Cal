// v.int64() fields require BigInt() in mutations and @ConvexInt in Swift structs

// DATA OWNERSHIP RULES:
// - events: Convex-native (Convex is source of truth). Full CRUD.
// - tasks: Convex-only (Convex is source of truth). Full CRUD.
// - chat_messages: Convex-only. Written by app (user role) and Loom (assistant role).
// - studio_events: Read-only cache. Source of truth is Supabase. Synced via cron every 15 min.
//   lastSyncedAt tracks freshness.
// - Apple Calendar events: Read directly from EventKit on-device. NOT stored in Convex.
//   Device-specific, always fresh, no sync needed.

import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  events: defineTable({
    calendarId: v.string(),                       // links to a named calendar/source
    title: v.string(),
    start: v.int64(),                             // UTC milliseconds
    duration: v.int64(),                          // minutes
    timezone: v.string(),                         // IANA timezone, e.g. "America/New_York"
    isAllDay: v.boolean(),
    location: v.optional(v.string()),
    notes: v.optional(v.string()),                // markdown plain text
    url: v.optional(v.string()),                  // dedicated meeting link field
    color: v.optional(v.string()),                // user-picked color from palette
    rrule: v.optional(v.string()),                // RRULE string for recurrence (UI deferred)
    recurrenceGroupId: v.optional(v.string()),    // links recurring instances
    attachments: v.optional(v.array(v.string())), // file references (upload UI deferred)
  })
    .index("by_calendar", ["calendarId"])
    .index("by_start", ["start"]),

  tasks: defineTable({
    title: v.string(),
    dueDate: v.optional(v.int64()),               // UTC milliseconds
    flagged: v.boolean(),                         // boolean flag only — NOT priority tiers
    completed: v.boolean(),
    notes: v.optional(v.string()),                // markdown plain text
    attachments: v.optional(v.array(v.string())), // file references (upload UI deferred)
  })
    .index("by_due_date", ["dueDate"])
    .index("by_completed", ["completed"]),

  chat_messages: defineTable({
    role: v.union(v.literal("user"), v.literal("assistant")),
    content: v.string(),
    sentAt: v.int64(),                            // UTC milliseconds
  })
    .index("by_sent_at", ["sentAt"]),

  studio_events: defineTable({
    calendarId: v.string(),                       // fixed value: "studio"
    title: v.string(),
    start: v.int64(),                             // UTC milliseconds
    duration: v.int64(),                          // minutes
    timezone: v.string(),
    isAllDay: v.boolean(),
    lastSyncedAt: v.int64(),                      // UTC ms timestamp of last Supabase sync
  })
    .index("by_start", ["start"]),
});
