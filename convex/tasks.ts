import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

/**
 * List all tasks ordered by due date (ascending, nulls last via Convex index ordering).
 */
export const list = query({
  handler: async (ctx) => {
    return await ctx.db.query("tasks").withIndex("by_due_date").collect();
  },
});

/**
 * Create a new task.
 * flagged is a boolean — there are no priority tiers.
 * dueDate is v.int64() UTC milliseconds when set.
 */
export const create = mutation({
  args: {
    title: v.string(),
    dueDate: v.optional(v.int64()),
    flagged: v.boolean(),
    completed: v.boolean(),
    notes: v.optional(v.string()),
    attachments: v.optional(v.array(v.string())),
  },
  handler: async (ctx, args) => {
    return await ctx.db.insert("tasks", args);
  },
});

/**
 * Update an existing task with partial fields.
 * Only pass the fields you want to change.
 */
export const update = mutation({
  args: {
    id: v.id("tasks"),
    title: v.optional(v.string()),
    dueDate: v.optional(v.int64()),
    flagged: v.optional(v.boolean()),
    completed: v.optional(v.boolean()),
    notes: v.optional(v.string()),
    attachments: v.optional(v.array(v.string())),
  },
  handler: async (ctx, { id, ...updates }) => {
    await ctx.db.patch(id, updates);
  },
});

/**
 * Delete a task by ID.
 */
export const remove = mutation({
  args: {
    id: v.id("tasks"),
  },
  handler: async (ctx, { id }) => {
    await ctx.db.delete(id);
  },
});
