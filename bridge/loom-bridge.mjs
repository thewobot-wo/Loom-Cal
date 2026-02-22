#!/usr/bin/env node

/**
 * Loom Bridge — runs on the same machine as OpenClaw.
 *
 * Polls Convex for pending user messages, fetches calendar/task context,
 * forwards messages to the local OpenClaw gateway with a system prompt,
 * and posts Loom's text reply back to Convex.
 *
 * Mutations (create/edit/delete events and tasks) are handled separately
 * by the Convex MCP server (convex-mcp-server.mjs) which OpenClaw calls
 * as tools. This bridge only handles chat message relay.
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

// ---------------------------------------------------------------------------
// Context fetching
// ---------------------------------------------------------------------------

/**
 * Fetch current calendar events and active tasks from Convex.
 * Used to inject context into Loom's system prompt before each OpenClaw call.
 * Degrades gracefully — returns empty arrays on network failure.
 */
async function fetchContext() {
  try {
    const headers = { "Content-Type": "application/json" };
    if (WEBHOOK_SECRET) headers["Authorization"] = `Bearer ${WEBHOOK_SECRET}`;

    const res = await fetch(`${CONVEX_SITE_URL}/loom-context`, { headers });
    if (!res.ok) {
      console.error(`[bridge] Context fetch failed: ${res.status}`);
      return { events: [], tasks: [] };
    }
    return await res.json();
  } catch (err) {
    console.error(`[bridge] Context fetch error: ${err.message}`);
    return { events: [], tasks: [] };
  }
}

// ---------------------------------------------------------------------------
// System prompt
// ---------------------------------------------------------------------------

/**
 * Format a UTC millisecond timestamp (bigint or number) as a human-readable date/time string.
 */
function formatTimestamp(ms) {
  if (ms === null || ms === undefined) return "no date";
  // Convex int64 fields arrive as strings in JSON (base-10)
  const msNum = typeof ms === "string" ? parseInt(ms, 10) : Number(ms);
  if (isNaN(msNum)) return "unknown date";
  return new Date(msNum).toLocaleString("en-US", {
    weekday: "short",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
    timeZoneName: "short",
  });
}

/**
 * Build the system prompt for Loom, injecting current calendar and task context.
 * Tool usage instructions are minimal — OpenClaw provides tool schemas automatically.
 */
function buildSystemPrompt(context) {
  const { events = [], tasks = [] } = context;

  // Format events
  let eventsSection;
  if (events.length === 0) {
    eventsSection = "No events in the next 7 days.";
  } else {
    eventsSection = events
      .map((e) => {
        const startStr = formatTimestamp(e.start);
        const durationStr = e.isAllDay ? "all-day" : `${e.duration} min`;
        const loc = e.location ? ` @ ${e.location}` : "";
        return `- ${e.title}${loc} on ${startStr} (${durationStr}) [id: ${e._id}]`;
      })
      .join("\n");
  }

  // Format tasks
  let tasksSection;
  if (tasks.length === 0) {
    tasksSection = "No active tasks.";
  } else {
    tasksSection = tasks
      .map((t) => {
        const due = t.dueDate ? formatTimestamp(t.dueDate) : "no due date";
        return `- ${t.title} (priority: ${t.priority}, due: ${due}) [id: ${t._id}]`;
      })
      .join("\n");
  }

  return `You are Loom, a calendar and task assistant for the Loom Cal app.

## Current Date/Time
${new Date().toLocaleString("en-US", { weekday: "long", year: "numeric", month: "long", day: "numeric", hour: "numeric", minute: "2-digit", timeZoneName: "long" })}

## Current Calendar (next 7 days)
${eventsSection}

## Active Tasks
${tasksSection}

## How You Work
You have tools to create, edit, and delete calendar events and tasks. When the user asks you to make a change:
1. Use the appropriate tool — it will create a confirmation card in the app
2. The user confirms or cancels in the app before any change takes effect
3. Reference existing items by their [id: ...] when editing or deleting
4. If multiple items match, list them and ask which one

## Rules
- Default to calendar "personal" when none specified
- Default to 60-minute events unless told otherwise
- When no time is given, create an all-day event
- Use ISO 8601 with timezone offset for dates (e.g. "2026-02-26T15:00:00-08:00")
- Be concise and friendly in your replies
- IMPORTANT: After calling a tool, respond with ONLY a brief one-sentence acknowledgment (e.g. "Done!" or "I've set that up for you."). Do NOT repeat the action details — the user already sees them in a confirmation card. Never say "Proposed:" or describe what the tool did.`;
}

// ---------------------------------------------------------------------------
// Convex posting
// ---------------------------------------------------------------------------

/**
 * Post Loom's text reply to Convex.
 */
async function postLoomReply(content) {
  const headers = { "Content-Type": "application/json" };
  if (WEBHOOK_SECRET) headers["Authorization"] = `Bearer ${WEBHOOK_SECRET}`;

  const postRes = await fetch(`${CONVEX_SITE_URL}/loom-reply`, {
    method: "POST",
    headers,
    body: JSON.stringify({ content }),
  });

  if (!postRes.ok) {
    console.error(`[bridge] Convex reply post failed: ${postRes.status}`);
  } else {
    console.log("[bridge] Reply delivered successfully");
  }
}

// ---------------------------------------------------------------------------
// Main poll loop
// ---------------------------------------------------------------------------

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
    console.log(`[bridge] New user message detected, fetching context...`);

    // Fetch current calendar and task context
    const context = await fetchContext();
    console.log(`[bridge] Context: ${context.events.length} events, ${context.tasks.length} tasks`);

    // Build system prompt with injected context
    const systemPrompt = buildSystemPrompt(context);

    console.log(`[bridge] Forwarding to Loom...`);

    // Forward to local OpenClaw gateway with system message prepended
    const loomRes = await fetch(`${OPENCLAW_URL}/v1/chat/completions`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${OPENCLAW_TOKEN}`,
      },
      body: JSON.stringify({
        model: "openclaw",
        messages: [
          { role: "system", content: systemPrompt },
          ...messages.map((m) => ({ role: m.role, content: m.content })),
        ],
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
    await postLoomReply(replyText);
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
console.log(`[bridge] Actions handled by Convex MCP server (separate process)`);
console.log("");

setInterval(poll, POLL_INTERVAL);
poll(); // Run immediately
