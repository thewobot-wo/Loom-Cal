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
 *   OPENCLAW_PASSWORD=<password> node loom-bridge.mjs
 *
 * Environment variables:
 *   OPENCLAW_PASSWORD — OpenClaw gateway password (required; set gateway to password auth mode)
 *   OPENCLAW_TOKEN    — Deprecated alias for OPENCLAW_PASSWORD (still works)
 *   OPENCLAW_URL      — Gateway URL (default: http://127.0.0.1:18789)
 *   CONVEX_SITE_URL   — Convex HTTP endpoint base (default: https://kindhearted-goldfish-658.convex.site)
 *   POLL_INTERVAL     — Polling interval in ms (default: 2000)
 *   WEBHOOK_SECRET    — Optional shared secret for Convex endpoints
 */

const OPENCLAW_URL = process.env.OPENCLAW_URL || "http://127.0.0.1:18789";
const OPENCLAW_PASSWORD = process.env.OPENCLAW_PASSWORD || process.env.OPENCLAW_TOKEN;
const CONVEX_SITE_URL = process.env.CONVEX_SITE_URL || "https://kindhearted-goldfish-658.convex.site";
const BASE_POLL_INTERVAL = parseInt(process.env.POLL_INTERVAL || "2000", 10);
const BACKOFF_POLL_INTERVAL = 30_000; // 30s when auth is broken
const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET || "";
const USER_TIMEZONE = process.env.USER_TIMEZONE || "America/Phoenix";

if (!OPENCLAW_PASSWORD) {
  console.error("Error: OPENCLAW_PASSWORD (or OPENCLAW_TOKEN) environment variable is required");
  process.exit(1);
}

let processing = false;
let authFailCount = 0;
let authErrorPosted = false; // only post one friendly error per failure streak
let pollTimer = null;

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
    timeZone: USER_TIMEZONE,
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

## User's Timezone
${USER_TIMEZONE}
IMPORTANT: Always use this timezone for all dates and times. The user is in ${USER_TIMEZONE}. Do NOT use America/Los_Angeles or any other timezone.

## Current Date/Time
${new Date().toLocaleString("en-US", { weekday: "long", year: "numeric", month: "long", day: "numeric", hour: "numeric", minute: "2-digit", timeZone: USER_TIMEZONE, timeZoneName: "long" })}

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
- ALWAYS use timezone "${USER_TIMEZONE}" for all events and dates
- Be concise and friendly in your replies
- IMPORTANT: After calling a tool, respond with ONLY a brief one-sentence acknowledgment (e.g. "Done!" or "I've set that up for you."). Do NOT repeat the action details — the user already sees them in a confirmation card. Never say "Proposed:" or describe what the tool did.`;
}

// ---------------------------------------------------------------------------
// ACTION text fallback parsing
// ---------------------------------------------------------------------------

/**
 * Detect and extract an action JSON block from Loom's reply text.
 * Safety net for when Loom outputs action JSON instead of calling MCP tools.
 *
 * Supported formats:
 *   1. ACTION: { "type": "create_event", ... }     (prefixed)
 *   2. { "type": "create_event", "payload": {...} } (bare JSON)
 *
 * Returns { action, cleanText } if found, or null if no action block present.
 */
function detectActionBlock(text) {
  // Strategy 1: Look for "ACTION:" prefix
  let jsonSource = null;
  let blockStart = -1;

  const actionIdx = text.indexOf("ACTION:");
  if (actionIdx !== -1) {
    jsonSource = text.substring(actionIdx + "ACTION:".length).trim();
    blockStart = actionIdx;
  }

  // Strategy 2: Look for bare JSON with action signature (type + payload)
  if (!jsonSource) {
    const bareIdx = text.indexOf("{");
    if (bareIdx !== -1) {
      jsonSource = text.substring(bareIdx);
      blockStart = bareIdx;
    }
  }

  if (!jsonSource) return null;

  // Find the JSON object — look for balanced braces
  const jsonStart = jsonSource.indexOf("{");
  if (jsonStart === -1) return null;

  let depth = 0;
  let jsonEnd = -1;
  for (let i = jsonStart; i < jsonSource.length; i++) {
    if (jsonSource[i] === "{") depth++;
    else if (jsonSource[i] === "}") {
      depth--;
      if (depth === 0) {
        jsonEnd = i;
        break;
      }
    }
  }
  if (jsonEnd === -1) return null;

  const jsonStr = jsonSource.substring(jsonStart, jsonEnd + 1);
  let action;
  try {
    action = JSON.parse(jsonStr);
  } catch {
    console.error("[bridge] Failed to parse ACTION JSON:", jsonStr.substring(0, 200));
    return null;
  }

  // Validate: must have type + payload, and type must be a known action
  const validTypes = [
    "create_event", "update_event", "delete_event",
    "create_task", "update_task", "delete_task",
  ];
  if (!action.type || !action.payload || !validTypes.includes(action.type)) {
    return null;
  }

  // Strip the entire action block from the text
  const prefixLen = actionIdx !== -1 ? "ACTION:".length : 0;
  const fullBlockEnd = blockStart + prefixLen + jsonEnd + 1;
  const cleanText = (text.substring(0, blockStart) + text.substring(fullBlockEnd)).trim();

  return { action, cleanText };
}

/**
 * Normalize action payload values to match what the iOS app expects:
 * - "start" and "dueDate" → UTC millisecond strings (converts ISO 8601 if needed)
 * - "duration" → string of minutes (converts number to string if needed)
 *
 * Loom may output ISO dates or raw numbers; the MCP server converts these,
 * but when Loom outputs bare JSON, we must do it here.
 */
function normalizeActionPayload(action) {
  const p = action.payload;
  if (!p) return action;

  // Convert ISO date strings to UTC ms strings
  for (const key of ["start", "dueDate"]) {
    if (p[key] === undefined) continue;
    const val = String(p[key]);
    // Already a numeric ms string? Skip.
    if (/^\d{10,}$/.test(val)) continue;
    // Try parsing as a date (ISO 8601)
    const ms = new Date(val).getTime();
    if (!isNaN(ms)) {
      p[key] = String(ms);
    }
  }

  // Convert previousValues dates too
  if (action.previousValues) {
    for (const key of ["start", "dueDate"]) {
      const val = action.previousValues[key];
      if (val === undefined) continue;
      const valStr = String(val);
      if (/^\d{10,}$/.test(valStr)) continue;
      const ms = new Date(valStr).getTime();
      if (!isNaN(ms)) {
        action.previousValues[key] = String(ms);
      }
    }
  }

  // Ensure duration is a string
  if (p.duration !== undefined) {
    p.duration = String(p.duration);
  }

  return action;
}

/**
 * Post a pending action to Convex (for the iOS confirmation card).
 * Called when an ACTION block is detected in Loom's reply text.
 */
async function postPendingAction(action, displayText) {
  const headers = { "Content-Type": "application/json" };
  if (WEBHOOK_SECRET) headers["Authorization"] = `Bearer ${WEBHOOK_SECRET}`;

  const res = await fetch(`${CONVEX_SITE_URL}/loom-pending-action`, {
    method: "POST",
    headers,
    body: JSON.stringify({
      displayText: displayText || action.displaySummary || "Action proposed",
      action,
    }),
  });

  if (!res.ok) {
    console.error(`[bridge] Pending action post failed: ${res.status}`);
  } else {
    console.log("[bridge] Pending action delivered successfully");
  }
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

    // Re-read password from env to support hot-reload (e.g. pm2 restart with new env)
    const currentPassword = process.env.OPENCLAW_PASSWORD || process.env.OPENCLAW_TOKEN || OPENCLAW_PASSWORD;

    // Forward to local OpenClaw gateway with system message prepended
    const loomRes = await fetch(`${OPENCLAW_URL}/v1/chat/completions`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${currentPassword}`,
      },
      body: JSON.stringify({
        model: "openclaw",
        messages: [
          { role: "system", content: systemPrompt },
          ...messages.map((m) => ({ role: m.role, content: m.content })),
        ],
      }),
    });

    // --- Auth error detection and backoff ---
    if (loomRes.status === 401 || loomRes.status === 403) {
      const error = await loomRes.text();
      authFailCount++;
      console.error(`[bridge] Auth error (${loomRes.status}, streak: ${authFailCount}): ${error.substring(0, 200)}`);

      if (!authErrorPosted) {
        await postLoomReply("I'm having trouble connecting right now — please try again in a moment.");
        authErrorPosted = true;
      }

      if (authFailCount > 3) {
        setPollInterval(BACKOFF_POLL_INTERVAL);
      }

      processing = false;
      return;
    }

    if (!loomRes.ok) {
      const error = await loomRes.text();
      console.error(`[bridge] OpenClaw error: ${loomRes.status} ${error}`);
      processing = false;
      return;
    }

    // Auth succeeded — reset failure tracking
    if (authFailCount > 0) {
      console.log(`[bridge] Auth recovered after ${authFailCount} failures`);
      authFailCount = 0;
      authErrorPosted = false;
      setPollInterval(BASE_POLL_INTERVAL);
    }

    const data = await loomRes.json();
    const replyText = data.choices?.[0]?.message?.content ?? "";

    if (!replyText) {
      console.error("[bridge] Empty reply from Loom");
      processing = false;
      return;
    }

    // Guard: don't forward API errors as Loom replies
    const isApiError = /authentication_error|invalid.bearer.token/i.test(replyText)
      || /^HTTP \d{3} \w+_error[:;]/.test(replyText);
    if (isApiError) {
      console.error(`[bridge] Loom returned an API error (not forwarding): ${replyText.substring(0, 200)}`);
      if (!authErrorPosted) {
        await postLoomReply("I'm having trouble connecting right now — please try again in a moment.");
        authErrorPosted = true;
      }
      processing = false;
      return;
    }

    console.log(`[bridge] Loom replied (${replyText.length} chars), posting to Convex...`);

    // Check for ACTION block (when Loom outputs JSON instead of calling MCP tools)
    const actionResult = detectActionBlock(replyText);
    if (actionResult) {
      const normalizedAction = normalizeActionPayload(actionResult.action);
      console.log(`[bridge] ACTION block detected (type: ${normalizedAction.type}), creating confirmation card...`);
      // Use cleanText as display text, fall back to the action's displaySummary
      const displayText = actionResult.cleanText || normalizedAction.displaySummary || "Action proposed";
      await postPendingAction(normalizedAction, displayText);
      // Don't post a separate assistant reply — the confirmation card is enough
    } else {
      await postLoomReply(replyText);
    }
  } catch (err) {
    console.error(`[bridge] Error: ${err.message}`);
  } finally {
    processing = false;
  }
}

// ---------------------------------------------------------------------------
// Dynamic poll interval
// ---------------------------------------------------------------------------

function setPollInterval(ms) {
  if (pollTimer) clearInterval(pollTimer);
  pollTimer = setInterval(poll, ms);
  if (ms !== BASE_POLL_INTERVAL) {
    console.log(`[bridge] Poll interval changed to ${ms}ms`);
  }
}

console.log(`[bridge] Loom Bridge started`);
console.log(`[bridge] OpenClaw: ${OPENCLAW_URL}`);
console.log(`[bridge] Convex:   ${CONVEX_SITE_URL}`);
console.log(`[bridge] Polling every ${BASE_POLL_INTERVAL}ms`);
console.log(`[bridge] Auth: password mode (static credential)`);
console.log(`[bridge] Actions handled by Convex MCP server (separate process)`);
console.log("");

setPollInterval(BASE_POLL_INTERVAL);
poll(); // Run immediately
