import { mutation, query, internalQuery } from "./_generated/server";
import { v } from "convex/values";

/**
 * List all events ordered by start time (ascending).
 */
export const list = query({
  handler: async (ctx) => {
    return await ctx.db.query("events").withIndex("by_start").collect();
  },
});

/**
 * Create a new event.
 * IMPORTANT: v.int64() fields (start, duration) must be passed as BigInt from TypeScript callers.
 * Swift callers via ConvexMobile send Int which the SDK converts appropriately.
 * taskId is optional — set when this event is a time-block for a task.
 */
export const create = mutation({
  args: {
    calendarId: v.string(),
    title: v.string(),
    start: v.int64(),
    duration: v.int64(),
    timezone: v.string(),
    isAllDay: v.boolean(),
    location: v.optional(v.string()),
    notes: v.optional(v.string()),
    url: v.optional(v.string()),
    color: v.optional(v.string()),
    rrule: v.optional(v.string()),
    recurrenceGroupId: v.optional(v.string()),
    attachments: v.optional(v.array(v.string())),
    taskId: v.optional(v.id("tasks")),
  },
  handler: async (ctx, args) => {
    return await ctx.db.insert("events", args);
  },
});

/**
 * Update an existing event with partial fields.
 * Only pass the fields you want to change.
 */
export const update = mutation({
  args: {
    id: v.id("events"),
    calendarId: v.optional(v.string()),
    title: v.optional(v.string()),
    start: v.optional(v.int64()),
    duration: v.optional(v.int64()),
    timezone: v.optional(v.string()),
    isAllDay: v.optional(v.boolean()),
    location: v.optional(v.string()),
    notes: v.optional(v.string()),
    url: v.optional(v.string()),
    color: v.optional(v.string()),
    rrule: v.optional(v.string()),
    recurrenceGroupId: v.optional(v.string()),
    attachments: v.optional(v.array(v.string())),
    taskId: v.optional(v.id("tasks")),
  },
  handler: async (ctx, { id, ...updates }) => {
    await ctx.db.patch(id, updates);
  },
});

/**
 * Delete an event by ID.
 */
export const remove = mutation({
  args: {
    id: v.id("events"),
  },
  handler: async (ctx, { id }) => {
    await ctx.db.delete(id);
  },
});

/**
 * Internal query: fetch events in a 7-day window (past 7 days through next 7 days).
 * Used by the bridge to inject calendar context into Loom's system prompt.
 * Returns a lightweight subset of fields relevant for Loom decision-making.
 */
export const listForLoom = internalQuery({
  args: {},
  handler: async (ctx) => {
    const now = BigInt(Date.now());
    const sevenDays = BigInt(7 * 24 * 60 * 60 * 1000);
    const windowStart = now - sevenDays;
    const windowEnd = now + sevenDays;

    const events = await ctx.db
      .query("events")
      .withIndex("by_start", (q) =>
        q.gte("start", windowStart).lte("start", windowEnd)
      )
      .collect();

    return events.map((e) => ({
      _id: e._id,
      title: e.title,
      start: e.start,
      duration: e.duration,
      timezone: e.timezone,
      isAllDay: e.isAllDay,
      location: e.location,
      calendarId: e.calendarId,
      taskId: e.taskId,
    }));
  },
});
