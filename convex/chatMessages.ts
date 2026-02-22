import { mutation, query, internalMutation, internalQuery } from "./_generated/server";
import { v } from "convex/values";

/**
 * List all chat messages ordered by sentAt time (ascending).
 */
export const list = query({
  handler: async (ctx) => {
    return await ctx.db.query("chat_messages").withIndex("by_sent_at").collect();
  },
});

/**
 * Send a new chat message.
 * sentAt is automatically set to the current time as BigInt(Date.now()).
 * If the role is "user", schedule askLoom to get a reply via the OpenClaw gateway API.
 */
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
    return id;
  },
});

/**
 * Internal query: fetch recent chat messages for Loom context.
 * Safety guard: take last 50 to avoid unbounded payloads.
 */
export const listForLoom = internalQuery({
  args: {},
  handler: async (ctx) => {
    const all = await ctx.db.query("chat_messages").withIndex("by_sent_at").collect();
    return all.slice(-50);
  },
});


/**
 * Internal mutation: write Loom's reply to the chat_messages table.
 */
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

/**
 * Internal mutation: write a pending action card to the chat_messages table.
 * Called by the bridge via /loom-pending-action when Loom proposes a calendar or task action.
 * The iOS client renders this as a confirmation card (not a plain bubble).
 */
export const writePendingAction = internalMutation({
  args: {
    content: v.string(),  // Loom's natural language text (ACTION block stripped)
    action: v.string(),   // JSON string of the action payload
  },
  handler: async (ctx, { content, action }) => {
    // Dedup: skip if a matching pending_action was created in the last 30 seconds.
    // Prevents duplicates when Loom calls the same MCP tool multiple times.
    const thirtySecondsAgo = BigInt(Date.now() - 30_000);
    const recentPending = await ctx.db
      .query("chat_messages")
      .withIndex("by_sent_at")
      .filter((q) =>
        q.and(
          q.eq(q.field("role"), "pending_action"),
          q.eq(q.field("actionStatus"), "pending"),
          q.gte(q.field("sentAt"), thirtySecondsAgo)
        )
      )
      .collect();

    // Check if any recent pending action has the same type and payload title
    let parsedAction: { type?: string; payload?: { title?: string } } | null = null;
    try {
      parsedAction = JSON.parse(action);
    } catch {
      // If action can't be parsed, proceed with insert (no dedup possible)
    }

    if (parsedAction) {
      const isDuplicate = recentPending.some((msg) => {
        try {
          const existing = JSON.parse(msg.action as string);
          return (
            existing.type === parsedAction!.type &&
            existing.payload?.title === parsedAction!.payload?.title
          );
        } catch {
          return false;
        }
      });

      if (isDuplicate) {
        // Skip — duplicate action card already exists
        return;
      }
    }

    await ctx.db.insert("chat_messages", {
      role: "pending_action",
      content,
      action,
      actionStatus: "pending",
      sentAt: BigInt(Date.now()),
    });
  },
});

/**
 * Mutation: update the lifecycle status of an action card.
 * Called from iOS when the user taps Confirm, Cancel, or Undo on an action card.
 */
export const updateActionStatus = mutation({
  args: {
    id: v.id("chat_messages"),
    actionStatus: v.union(
      v.literal("confirmed"),
      v.literal("cancelled"),
      v.literal("undone"),
    ),
  },
  handler: async (ctx, { id, actionStatus }) => {
    await ctx.db.patch(id, { actionStatus });
  },
});
