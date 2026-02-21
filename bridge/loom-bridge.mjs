#!/usr/bin/env node

/**
 * Loom Bridge — runs on the same machine as OpenClaw.
 *
 * Polls Convex for pending user messages, forwards them to the local
 * OpenClaw gateway, and posts Loom's reply back to Convex.
 *
 * Usage:
 *   OPENCLAW_TOKEN=<gateway-token> node loom-bridge.mjs
 *
 * Environment variables:
 *   OPENCLAW_TOKEN  — OpenClaw gateway auth token (required)
 *   OPENCLAW_URL    — Gateway URL (default: http://127.0.0.1:18789)
 *   CONVEX_SITE_URL — Convex HTTP endpoint base (default: https://kindhearted-goldfish-658.convex.site)
 *   POLL_INTERVAL   — Polling interval in ms (default: 2000)
 *   WEBHOOK_SECRET  — Optional shared secret for Convex endpoints
 */

const OPENCLAW_URL = process.env.OPENCLAW_URL || "http://127.0.0.1:18789";
const OPENCLAW_TOKEN = process.env.OPENCLAW_TOKEN;
const CONVEX_SITE_URL = process.env.CONVEX_SITE_URL || "https://kindhearted-goldfish-658.convex.site";
const POLL_INTERVAL = parseInt(process.env.POLL_INTERVAL || "2000", 10);
const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET || "";

if (!OPENCLAW_TOKEN) {
  console.error("Error: OPENCLAW_TOKEN environment variable is required");
  process.exit(1);
}

let processing = false;

async function poll() {
  if (processing) return;

  try {
    // Check for pending messages
    const headers = { "Content-Type": "application/json" };
    if (WEBHOOK_SECRET) headers["Authorization"] = `Bearer ${WEBHOOK_SECRET}`;

    const pendingRes = await fetch(`${CONVEX_SITE_URL}/pending-messages`, { headers });
    if (!pendingRes.ok) {
      console.error(`[bridge] Pending check failed: ${pendingRes.status}`);
      return;
    }

    const { pending, messages } = await pendingRes.json();
    if (!pending || messages.length === 0) return;

    processing = true;
    console.log(`[bridge] New user message detected, forwarding to Loom...`);

    // Forward to local OpenClaw gateway
    const loomRes = await fetch(`${OPENCLAW_URL}/v1/chat/completions`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${OPENCLAW_TOKEN}`,
      },
      body: JSON.stringify({
        model: "openclaw",
        messages: messages.map((m) => ({ role: m.role, content: m.content })),
      }),
    });

    if (!loomRes.ok) {
      const error = await loomRes.text();
      console.error(`[bridge] OpenClaw error: ${loomRes.status} ${error}`);
      processing = false;
      return;
    }

    const data = await loomRes.json();
    const replyText = data.choices?.[0]?.message?.content ?? "";

    if (!replyText) {
      console.error("[bridge] Empty reply from Loom");
      processing = false;
      return;
    }

    console.log(`[bridge] Loom replied (${replyText.length} chars), posting to Convex...`);

    // Post reply to Convex
    const replyHeaders = { "Content-Type": "application/json" };
    if (WEBHOOK_SECRET) replyHeaders["Authorization"] = `Bearer ${WEBHOOK_SECRET}`;

    const postRes = await fetch(`${CONVEX_SITE_URL}/loom-reply`, {
      method: "POST",
      headers: replyHeaders,
      body: JSON.stringify({ content: replyText }),
    });

    if (!postRes.ok) {
      console.error(`[bridge] Convex post failed: ${postRes.status}`);
    } else {
      console.log("[bridge] Reply delivered successfully");
    }
  } catch (err) {
    console.error(`[bridge] Error: ${err.message}`);
  } finally {
    processing = false;
  }
}

console.log(`[bridge] Loom Bridge started`);
console.log(`[bridge] OpenClaw: ${OPENCLAW_URL}`);
console.log(`[bridge] Convex:   ${CONVEX_SITE_URL}`);
console.log(`[bridge] Polling every ${POLL_INTERVAL}ms`);
console.log("");

setInterval(poll, POLL_INTERVAL);
poll(); // Run immediately
