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
    exceptionDates: v.optional(v.string()),          // JSON array of UTC ms timestamps where recurrence skips, e.g. "[1708819200000]"
    attachments: v.optional(v.array(v.string())), // file references (upload UI deferred)
    taskId: v.optional(v.id("tasks")),            // links time-blocked events to source task
  })
    .index("by_calendar", ["calendarId"])
    .index("by_start", ["start"])
    .index("by_task_id", ["taskId"]),

  tasks: defineTable({
    title: v.string(),
    dueDate: v.optional(v.int64()),               // UTC milliseconds
    priority: v.union(v.literal("high"), v.literal("medium"), v.literal("low")),  // priority is high/medium/low union literal
    hasDueTime: v.boolean(),                      // true when dueDate includes specific time
    completed: v.boolean(),
    notes: v.optional(v.string()),                // markdown plain text
    attachments: v.optional(v.array(v.string())), // file references (upload UI deferred)
  })
    .index("by_due_date", ["dueDate"])
    .index("by_completed", ["completed"])
    .index("by_priority", ["priority"]),

  chat_messages: defineTable({
    role: v.union(v.literal("user"), v.literal("assistant"), v.literal("pending_action")),
    content: v.string(),
    sentAt: v.int64(),                            // UTC milliseconds
    action: v.optional(v.string()),               // JSON string of the action payload (set for pending_action messages)
    actionStatus: v.optional(v.union(
      v.literal("pending"),
      v.literal("confirmed"),
      v.literal("cancelled"),
      v.literal("undone"),
    )),                                           // lifecycle state of an action card
    audioStorageId: v.optional(v.id("_storage")), // Convex file storage ref for TTS audio
  })
    .index("by_sent_at", ["sentAt"]),

  parse_requests: defineTable({
    requestId: v.string(),                            // client-generated UUID
    text: v.string(),                                 // raw NL input
    type: v.union(v.literal("event"), v.literal("task")),
    status: v.union(v.literal("pending"), v.literal("complete"), v.literal("error")),
    result: v.optional(v.string()),                   // JSON string of parsed fields
    createdAt: v.int64(),                             // UTC milliseconds
  })
    .index("by_request_id", ["requestId"])
    .index("by_status", ["status"]),

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
