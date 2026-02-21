import Anthropic from "@anthropic-ai/sdk";
import { mutation, query, internalAction, internalMutation, internalQuery } from "./_generated/server";
import { internal } from "./_generated/api";
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
 * Note: Date.now() is allowed in mutations (not queries) — no cache invalidation issue.
 * If the role is "user", schedule an AI reply via generateReply internalAction.
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
    if (role === "user") {
      await ctx.scheduler.runAfter(0, internal.chatMessages.generateReply, {});
    }
    return id;
  },
});

/**
 * Internal query: fetch all chat messages for AI context.
 * Safety guard: take last 50 to avoid unbounded context windows.
 * Context-window trimming is a Phase 6+ concern.
 */
export const listForAI = internalQuery({
  args: {},
  handler: async (ctx) => {
    const all = await ctx.db.query("chat_messages").withIndex("by_sent_at").collect();
    return all.slice(-50);
  },
});

/**
 * Internal action: call Anthropic Claude API and schedule writing the reply.
 * Uses ANTHROPIC_API_KEY from Convex environment variables (set in dashboard).
 * Uses LOOM_MODEL env var to select model (default: claude-haiku-4-5).
 */
export const generateReply = internalAction({
  args: {},
  handler: async (ctx) => {
    const apiKey = process.env.ANTHROPIC_API_KEY;
    if (!apiKey) throw new Error("ANTHROPIC_API_KEY not set in Convex environment variables");

    const model = process.env.LOOM_MODEL || "claude-haiku-4-5";

    const messages = await ctx.runQuery(internal.chatMessages.listForAI, {});

    const client = new Anthropic({ apiKey });
    const response = await client.messages.create({
      model,
      max_tokens: 1024,
      system:
        "You are Loom, a playful and organized calendar assistant. You're like a buddy who's also really organized — light personality, occasional humor. You help users understand their schedule and tasks. In this phase you can only read and discuss calendar data — you cannot create, edit, or delete events or tasks yet. Keep responses concise and helpful. Use Markdown formatting (bold, lists, code blocks) when it helps clarity.",
      messages: messages.map((m: { role: string; content: string }) => ({
        role: m.role as "user" | "assistant",
        content: m.content,
      })),
    });

    const replyText =
      response.content[0].type === "text" ? response.content[0].text : "";

    await ctx.runMutation(internal.chatMessages.writeAssistantReply, {
      content: replyText,
    });
  },
});

/**
 * Internal mutation: write the AI-generated assistant reply to the chat_messages table.
 * Only callable from generateReply internalAction — not exposed as a public mutation.
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
