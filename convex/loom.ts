"use node";

import { internalAction } from "./_generated/server";
import { internal } from "./_generated/api";

/**
 * Internal action: call Loom via OpenClaw gateway's OpenAI-compatible API.
 * Runs in Node.js runtime for full TLS certificate support.
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

    let response: Response;
    try {
      response = await fetch(
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
    } catch (err: unknown) {
      const errMsg = err instanceof Error ? `${err.message} | cause: ${JSON.stringify((err as any).cause)}` : String(err);
      throw new Error(`Loom fetch failed: ${errMsg}`);
    }

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
