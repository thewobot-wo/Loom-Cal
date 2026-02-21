import { mutation, query, internalAction, internalMutation } from "./_generated/server";
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
 * If the role is "user", schedule sendToTelegram to forward the message to Loom.
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
      await ctx.scheduler.runAfter(0, internal.chatMessages.sendToTelegram, {
        content,
      });
    }
    return id;
  },
});

/**
 * Internal action: forward the user's message to Loom via Telegram Bot API.
 * Loom's existing webhook picks it up. Messages are tagged with [loom-cal]
 * so Loom knows to reply via the Convex HTTP endpoint instead of Telegram.
 *
 * Env vars (set in Convex Dashboard → Settings → Environment Variables):
 *   TELEGRAM_BOT_TOKEN — Bot token from @BotFather
 *   TELEGRAM_CHAT_ID   — Chat ID where Loom listens
 */
export const sendToTelegram = internalAction({
  args: { content: v.string() },
  handler: async (_ctx, { content }) => {
    const botToken = process.env.TELEGRAM_BOT_TOKEN;
    if (!botToken) throw new Error("TELEGRAM_BOT_TOKEN not set in Convex environment variables");

    const chatId = process.env.TELEGRAM_CHAT_ID;
    if (!chatId) throw new Error("TELEGRAM_CHAT_ID not set in Convex environment variables");

    const taggedMessage = `[loom-cal] ${content}`;

    const response = await fetch(
      `https://api.telegram.org/bot${botToken}/sendMessage`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          chat_id: chatId,
          text: taggedMessage,
        }),
      }
    );

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Telegram API error: ${response.status} ${error}`);
    }
  },
});

/**
 * Internal mutation: write Loom's reply to the chat_messages table.
 * Called from the /loom-reply HTTP endpoint when Loom responds.
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
