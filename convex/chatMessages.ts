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
    if (role === "user") {
      await ctx.scheduler.runAfter(0, internal.chatMessages.askLoom, {});
    }
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
 * Internal action: call Loom via OpenClaw gateway's OpenAI-compatible API.
 * Sends the full conversation history so Loom has context.
 * Writes the reply back as an assistant message.
 *
 * Env vars (set in Convex Dashboard → Settings → Environment Variables):
 *   LOOM_GATEWAY_URL   — OpenClaw gateway URL (e.g. https://machine.tailnet.ts.net)
 *   LOOM_GATEWAY_TOKEN — Gateway auth token
 */
export const askLoom = internalAction({
  args: {},
  handler: async (ctx) => {
    const gatewayUrl = process.env.LOOM_GATEWAY_URL;
    if (!gatewayUrl) throw new Error("LOOM_GATEWAY_URL not set in Convex environment variables");

    const gatewayToken = process.env.LOOM_GATEWAY_TOKEN;
    if (!gatewayToken) throw new Error("LOOM_GATEWAY_TOKEN not set in Convex environment variables");

    const messages = await ctx.runQuery(internal.chatMessages.listForLoom, {});

    const response = await fetch(
      `${gatewayUrl}/v1/chat/completions`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${gatewayToken}`,
        },
        body: JSON.stringify({
          model: "openclaw",
          messages: messages.map((m: { role: string; content: string }) => ({
            role: m.role as "user" | "assistant",
            content: m.content,
          })),
        }),
      }
    );

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Loom gateway error: ${response.status} ${error}`);
    }

    const data = await response.json() as {
      choices: Array<{ message: { content: string } }>;
    };

    const replyText = data.choices?.[0]?.message?.content ?? "";
    if (replyText) {
      await ctx.runMutation(internal.chatMessages.writeAssistantReply, {
        content: replyText,
      });
    }
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
