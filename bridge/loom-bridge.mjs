#!/usr/bin/env node

/**
 * Loom Bridge — runs on the same machine as OpenClaw.
 *
 * Polls Convex for pending user messages, fetches calendar/task context,
 * forwards messages to the local OpenClaw gateway with a system prompt,
 * extracts action JSON from Loom's reply, and posts either a pending action
 * card or a plain reply back to Convex.
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
// Action extraction
// ---------------------------------------------------------------------------

/**
 * Parse Loom's reply for an embedded ACTION JSON block.
 *
 * Expected format at end of reply:
 *
 *   ACTION:
 *   ```json
 *   { "type": "create_event", "displaySummary": "...", "payload": { ... } }
 *   ```
 *
 * Returns { action, displayText } where:
 *   - action is the parsed JSON object (or null if not found/invalid)
 *   - displayText is the reply with the ACTION block stripped
 */
function extractAction(replyText) {
  const match = replyText.match(/ACTION:\s*```json\s*([\s\S]*?)```/);
  if (!match) return { action: null, displayText: replyText.trim() };

  try {
    const action = JSON.parse(match[1].trim());
    const displayText = replyText.replace(/ACTION:\s*```json[\s\S]*?```/g, "").trim();
    return { action, displayText };
  } catch (e) {
    console.error("[bridge] Failed to parse action JSON:", e.message);
    return { action: null, displayText: replyText.trim() };
  }
}

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
 * Instructs Loom on how to propose actions using the ACTION JSON envelope pattern.
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

  return `You are Loom, a calendar and task assistant.

## Current Calendar (next 7 days)
${eventsSection}

## Active Tasks
${tasksSection}

## Your Capabilities
You can create, edit, and delete events and tasks on behalf of the user. When asked to take action:
1. Always propose the action first — never act without showing a preview
2. Include the user-visible summary in "displaySummary" for the confirmation card
3. Reference existing items by their [id: ...] when editing or deleting

## Action Format
When you want to perform a calendar or task action, include this block at the END of your reply:

ACTION:
\`\`\`json
{
  "type": "create_event" | "update_event" | "delete_event" | "create_task" | "update_task" | "delete_task",
  "displaySummary": "Human-readable summary for the confirmation card (e.g. 'Add Dentist on Tue Mar 5 at 3pm')",
  "payload": {
    // For create_event:
    //   title (string, required), start (string ms, required), duration (string minutes, required),
    //   timezone (string, required), isAllDay (boolean, required), calendarId (string, default "personal"),
    //   location (string, optional), notes (string, optional), url (string, optional)
    //
    // For update_event:
    //   id (string, required — from [id: ...] above), plus any fields to change,
    //   previousValues (object with old values for diff display)
    //
    // For delete_event:
    //   id (string, required)
    //
    // For create_task:
    //   title (string, required), priority ("high"|"medium"|"low", required),
    //   hasDueTime (boolean, required), completed (false, required),
    //   dueDate (string ms, optional), notes (string, optional)
    //
    // For update_task:
    //   id (string, required), plus any fields to change,
    //   previousValues (object with old values for diff display)
    //
    // For delete_task:
    //   id (string, required)
  }
}
\`\`\`

## Rules
- Timestamps in payloads MUST be string-encoded milliseconds (e.g. "1708988400000"), not numbers
- Duration MUST be string-encoded minutes (e.g. "60")
- Default calendarId to "personal" if not specified by the user
- Default to all-day event (isAllDay: true, duration: "0") when no time is given
- If multiple events/tasks match the user's request, list them as numbered options and ask which one
- For creates with missing optional fields: create with what you have and mention what's missing
- Do NOT include the ACTION block if you are just answering a question or asking for clarification`;
}

// ---------------------------------------------------------------------------
// Convex posting functions
// ---------------------------------------------------------------------------

/**
 * Post Loom's plain text reply to Convex (no action detected).
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

/**
 * Post a pending action card to Convex.
 * Falls back to posting a plain text reply if the pending-action endpoint fails.
 */
async function postPendingAction(displayText, action) {
  const headers = { "Content-Type": "application/json" };
  if (WEBHOOK_SECRET) headers["Authorization"] = `Bearer ${WEBHOOK_SECRET}`;

  try {
    const res = await fetch(`${CONVEX_SITE_URL}/loom-pending-action`, {
      method: "POST",
      headers,
      body: JSON.stringify({ displayText, action }),
    });

    if (!res.ok) {
      console.error(`[bridge] Pending action post failed: ${res.status} — falling back to plain reply`);
      await postLoomReply(displayText);
    } else {
      console.log(`[bridge] Pending action delivered: ${action.type}`);
    }
  } catch (err) {
    console.error(`[bridge] Pending action error: ${err.message} — falling back to plain reply`);
    await postLoomReply(displayText);
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

    console.log(`[bridge] Loom replied (${replyText.length} chars), parsing for action...`);

    // Extract action JSON from reply (if present)
    const { action, displayText } = extractAction(replyText);

    if (action) {
      console.log(`[bridge] Action detected: ${action.type}`);
      await postPendingAction(displayText, action);
    } else {
      console.log(`[bridge] No action detected, posting plain reply...`);
      await postLoomReply(displayText);
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
