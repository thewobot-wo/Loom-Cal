import { httpRouter } from "convex/server";
import { httpAction } from "./_generated/server";
import { internal } from "./_generated/api";

const http = httpRouter();

/**
 * POST /loom-reply
 *
 * Receives Loom's reply and writes it as an assistant message.
 * Loom calls this endpoint after processing a [loom-cal] tagged message.
 *
 * Request body: { "content": "Loom's response text" }
 * Optional auth: Bearer token matching LOOM_WEBHOOK_SECRET env var.
 *
 * Endpoint URL: https://<deployment>.convex.site/loom-reply
 */
http.route({
  path: "/loom-reply",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    // Optional: verify shared secret
    const secret = process.env.LOOM_WEBHOOK_SECRET;
    if (secret) {
      const auth = request.headers.get("Authorization");
      if (auth !== `Bearer ${secret}`) {
        return new Response("Unauthorized", { status: 401 });
      }
    }

    let body: { content?: string };
    try {
      body = await request.json();
    } catch {
      return new Response("Invalid JSON", { status: 400 });
    }

    const content = body.content;
    if (!content || typeof content !== "string" || content.trim().length === 0) {
      return new Response("Missing or empty 'content' field", { status: 400 });
    }

    await ctx.runMutation(internal.chatMessages.writeAssistantReply, {
      content: content.trim(),
    });

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }),
});

/**
 * GET /pending-messages
 *
 * Returns the last 50 messages if the most recent message is from a user
 * (meaning Loom hasn't replied yet). Returns empty array otherwise.
 * Used by the bridge script to detect when Loom needs to respond.
 *
 * Optional auth: Bearer token matching LOOM_WEBHOOK_SECRET env var.
 */
http.route({
  path: "/pending-messages",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const secret = process.env.LOOM_WEBHOOK_SECRET;
    if (secret) {
      const auth = request.headers.get("Authorization");
      if (auth !== `Bearer ${secret}`) {
        return new Response("Unauthorized", { status: 401 });
      }
    }

    const messages = await ctx.runQuery(internal.chatMessages.listForLoom, {});

    // Only return messages if the last one is from a user (needs reply)
    if (messages.length === 0 || messages[messages.length - 1].role !== "user") {
      return new Response(JSON.stringify({ pending: false, messages: [] }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({
      pending: true,
      messages: messages.map((m: { role: string; content: string }) => ({
        role: m.role,
        content: m.content,
      })),
    }), {
      headers: { "Content-Type": "application/json" },
    });
  }),
});

export default http;
