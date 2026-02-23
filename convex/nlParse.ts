import { mutation, query, internalMutation, internalQuery } from "./_generated/server";
import { v } from "convex/values";

/**
 * Public mutation: create a parse request from the Swift client.
 * The client generates the requestId (UUID) so it can subscribe to the result immediately.
 */
export const createParseRequest = mutation({
  args: {
    requestId: v.string(),
    text: v.string(),
    type: v.union(v.literal("event"), v.literal("task")),
  },
  handler: async (ctx, { requestId, text, type }) => {
    await ctx.db.insert("parse_requests", {
      requestId,
      text,
      type,
      status: "pending",
      createdAt: BigInt(Date.now()),
    });
  },
});

/**
 * Public query: get the result for a specific requestId.
 * Swift subscribes to this to receive the parsed result reactively.
 */
export const getResult = query({
  args: { requestId: v.string() },
  handler: async (ctx, { requestId }) => {
    return await ctx.db
      .query("parse_requests")
      .withIndex("by_request_id", (q) => q.eq("requestId", requestId))
      .first();
  },
});

/**
 * Internal query: find the oldest pending parse request.
 * Called by the bridge via /pending-parse HTTP endpoint.
 */
export const oldestPending = internalQuery({
  args: {},
  handler: async (ctx) => {
    return await ctx.db
      .query("parse_requests")
      .withIndex("by_status", (q) => q.eq("status", "pending"))
      .first();
  },
});

/**
 * Internal mutation: update a parse request with the result from the bridge.
 * Called via /parse-result HTTP endpoint.
 */
export const updateResult = internalMutation({
  args: {
    requestId: v.string(),
    status: v.union(v.literal("complete"), v.literal("error")),
    result: v.optional(v.string()),
  },
  handler: async (ctx, { requestId, status, result }) => {
    const doc = await ctx.db
      .query("parse_requests")
      .withIndex("by_request_id", (q) => q.eq("requestId", requestId))
      .first();
    if (!doc) return;
    await ctx.db.patch(doc._id, { status, result });
  },
});

/**
 * Internal mutation: delete parse requests older than 5 minutes.
 * Called opportunistically from /parse-result to prevent table bloat.
 */
export const cleanup = internalMutation({
  args: {},
  handler: async (ctx) => {
    const fiveMinutesAgo = BigInt(Date.now() - 5 * 60 * 1000);
    const old = await ctx.db
      .query("parse_requests")
      .filter((q) => q.lt(q.field("createdAt"), fiveMinutesAgo))
      .collect();
    for (const doc of old) {
      await ctx.db.delete(doc._id);
    }
  },
});
