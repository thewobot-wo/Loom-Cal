#!/usr/bin/env node

/**
 * Convex MCP Server for Loom — exposes calendar and task tools via MCP.
 *
 * OpenClaw spawns this as a subprocess via mcporter. Loom calls tools
 * directly instead of outputting ACTION JSON blocks in text.
 *
 * Each mutation tool creates a pending action in Convex that the iOS app
 * renders as a confirmation card. No changes happen until the user confirms.
 *
 * Environment variables:
 *   CONVEX_SITE_URL — Convex HTTP endpoint base (default: https://kindhearted-goldfish-658.convex.site)
 *   WEBHOOK_SECRET  — Optional shared secret for Convex endpoints
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const CONVEX_SITE_URL =
  process.env.CONVEX_SITE_URL ||
  "https://kindhearted-goldfish-658.convex.site";
const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET || "";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function convexHeaders() {
  const h = { "Content-Type": "application/json" };
  if (WEBHOOK_SECRET) h["Authorization"] = `Bearer ${WEBHOOK_SECRET}`;
  return h;
}

/**
 * POST a pending action to Convex. Creates a confirmation card in the chat.
 */
async function postPendingAction(displayText, action) {
  const res = await fetch(`${CONVEX_SITE_URL}/loom-pending-action`, {
    method: "POST",
    headers: convexHeaders(),
    body: JSON.stringify({ displayText, action }),
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Convex /loom-pending-action failed (${res.status}): ${body}`);
  }
  return await res.json();
}

/**
 * GET current calendar events and active tasks from Convex.
 */
async function fetchContext() {
  const res = await fetch(`${CONVEX_SITE_URL}/loom-context`, {
    headers: convexHeaders(),
  });
  if (!res.ok) {
    throw new Error(`Convex /loom-context failed (${res.status})`);
  }
  return await res.json();
}

/**
 * Convert an ISO 8601 datetime string to UTC milliseconds (as string for Convex int64).
 * Accepts: "2026-02-26T15:00:00-08:00", "2026-02-26T23:00:00Z", "2026-02-26"
 */
function toUtcMs(isoString) {
  const ms = new Date(isoString).getTime();
  if (isNaN(ms)) throw new Error(`Invalid date: "${isoString}"`);
  return String(ms);
}

/**
 * Format a UTC millisecond timestamp for display.
 */
function formatMs(ms) {
  const num = typeof ms === "string" ? parseInt(ms, 10) : Number(ms);
  if (isNaN(num)) return "unknown";
  return new Date(num).toLocaleString("en-US", {
    weekday: "short",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
    timeZoneName: "short",
  });
}

// ---------------------------------------------------------------------------
// MCP Server
// ---------------------------------------------------------------------------

const server = new McpServer({
  name: "loom-convex",
  version: "1.0.0",
});

// ---- get_calendar_context ----

server.tool(
  "get_calendar_context",
  "Get current calendar events (7-day window) and active tasks. Use this to see what's on the user's calendar and task list before making changes.",
  {},
  async () => {
    const ctx = await fetchContext();

    let text = "## Calendar Events (next 7 days)\n";
    if (ctx.events.length === 0) {
      text += "No events.\n";
    } else {
      for (const e of ctx.events) {
        const dur = e.isAllDay ? "all-day" : `${e.duration} min`;
        const loc = e.location ? ` @ ${e.location}` : "";
        text += `- ${e.title}${loc} on ${formatMs(e.start)} (${dur}) [id: ${e._id}]\n`;
      }
    }

    text += "\n## Active Tasks\n";
    if (ctx.tasks.length === 0) {
      text += "No active tasks.\n";
    } else {
      for (const t of ctx.tasks) {
        const due = t.dueDate ? formatMs(t.dueDate) : "no due date";
        text += `- ${t.title} (priority: ${t.priority}, due: ${due}) [id: ${t._id}]\n`;
      }
    }

    return { content: [{ type: "text", text }] };
  },
);

// ---- create_event ----

server.tool(
  "create_event",
  "Create a calendar event. This proposes the event as a pending action — the user must confirm it in the app before it's actually created.",
  {
    title: z.string().describe("Event title"),
    start: z
      .string()
      .describe(
        'ISO 8601 datetime with timezone offset, e.g. "2026-02-26T15:00:00-08:00". For all-day events use just the date: "2026-02-26"',
      ),
    duration_minutes: z
      .number()
      .default(60)
      .describe("Duration in minutes. Use 0 for all-day events. Default: 60"),
    timezone: z
      .string()
      .describe('IANA timezone, e.g. "America/Los_Angeles"'),
    is_all_day: z
      .boolean()
      .default(false)
      .describe("Whether this is an all-day event"),
    calendar_id: z
      .string()
      .default("personal")
      .describe('Calendar ID. Default: "personal"'),
    location: z.string().optional().describe("Event location"),
    notes: z.string().optional().describe("Event notes"),
  },
  async (args) => {
    const startMs = toUtcMs(args.start);
    const summary = args.is_all_day
      ? `Create: ${args.title} on ${formatMs(startMs)} (all day)`
      : `Create: ${args.title} on ${formatMs(startMs)} (${args.duration_minutes} min)`;

    const action = {
      type: "create_event",
      displaySummary: summary,
      payload: {
        title: args.title,
        start: startMs,
        duration: String(args.duration_minutes),
        timezone: args.timezone,
        isAllDay: args.is_all_day,
        calendarId: args.calendar_id,
        ...(args.location && { location: args.location }),
        ...(args.notes && { notes: args.notes }),
      },
    };

    await postPendingAction(
      `I'll create "${args.title}" for you.`,
      action,
    );

    return {
      content: [
        {
          type: "text",
          text: `Proposed: ${summary}. The user will see a confirmation card in the app.`,
        },
      ],
    };
  },
);

// ---- update_event ----

server.tool(
  "update_event",
  "Update an existing calendar event. Pass the event ID (from get_calendar_context) and only the fields to change. Creates a pending action the user must confirm.",
  {
    event_id: z.string().describe("Convex event ID (from [id: ...] in context)"),
    title: z.string().optional().describe("New title"),
    start: z.string().optional().describe("New start time as ISO 8601 with offset"),
    duration_minutes: z.number().optional().describe("New duration in minutes"),
    timezone: z.string().optional().describe("New IANA timezone"),
    is_all_day: z.boolean().optional().describe("Change all-day status"),
    location: z.string().optional().describe("New location"),
    notes: z.string().optional().describe("New notes"),
    previous_title: z.string().optional().describe("Previous title (for diff display)"),
    previous_start: z.string().optional().describe("Previous start ISO string (for diff display)"),
  },
  async (args) => {
    const payload = { id: args.event_id };
    const previousValues = {};
    const changes = [];

    if (args.title !== undefined) {
      payload.title = args.title;
      if (args.previous_title) previousValues.title = args.previous_title;
      changes.push(`title → "${args.title}"`);
    }
    if (args.start !== undefined) {
      payload.start = toUtcMs(args.start);
      if (args.previous_start) previousValues.start = toUtcMs(args.previous_start);
      changes.push(`time → ${formatMs(payload.start)}`);
    }
    if (args.duration_minutes !== undefined) {
      payload.duration = String(args.duration_minutes);
      changes.push(`duration → ${args.duration_minutes} min`);
    }
    if (args.timezone !== undefined) payload.timezone = args.timezone;
    if (args.is_all_day !== undefined) payload.isAllDay = args.is_all_day;
    if (args.location !== undefined) {
      payload.location = args.location;
      changes.push(`location → "${args.location}"`);
    }
    if (args.notes !== undefined) payload.notes = args.notes;

    if (Object.keys(previousValues).length > 0) {
      payload.previousValues = previousValues;
    }

    const summary = `Update event: ${changes.join(", ") || "fields changed"}`;

    const action = {
      type: "update_event",
      displaySummary: summary,
      payload,
    };

    await postPendingAction(
      `I'll update that event for you.`,
      action,
    );

    return {
      content: [{ type: "text", text: `Proposed: ${summary}. Awaiting confirmation.` }],
    };
  },
);

// ---- delete_event ----

server.tool(
  "delete_event",
  "Delete a calendar event. Pass the event ID from get_calendar_context. Creates a pending action the user must confirm.",
  {
    event_id: z.string().describe("Convex event ID to delete"),
    event_title: z.string().optional().describe("Event title (for display summary)"),
  },
  async (args) => {
    const summary = `Delete: ${args.event_title || "event"}`;

    const action = {
      type: "delete_event",
      displaySummary: summary,
      payload: { id: args.event_id },
    };

    await postPendingAction(
      `I'll delete "${args.event_title || "that event"}" for you.`,
      action,
    );

    return {
      content: [{ type: "text", text: `Proposed: ${summary}. Awaiting confirmation.` }],
    };
  },
);

// ---- create_task ----

server.tool(
  "create_task",
  "Create a task. Proposes as a pending action the user must confirm.",
  {
    title: z.string().describe("Task title"),
    priority: z.enum(["high", "medium", "low"]).describe("Task priority"),
    due_date: z
      .string()
      .optional()
      .describe('Due date as ISO 8601, e.g. "2026-02-27" or "2026-02-27T17:00:00-08:00"'),
    has_due_time: z
      .boolean()
      .default(false)
      .describe("Whether the due date includes a specific time"),
    notes: z.string().optional().describe("Task notes"),
  },
  async (args) => {
    const payload = {
      title: args.title,
      priority: args.priority,
      hasDueTime: args.has_due_time,
      completed: false,
    };

    if (args.due_date) {
      payload.dueDate = toUtcMs(args.due_date);
    }
    if (args.notes) {
      payload.notes = args.notes;
    }

    const duePart = args.due_date ? `, due ${formatMs(payload.dueDate)}` : "";
    const summary = `Create task: ${args.title} (${args.priority}${duePart})`;

    const action = {
      type: "create_task",
      displaySummary: summary,
      payload,
    };

    await postPendingAction(
      `I'll create that task for you.`,
      action,
    );

    return {
      content: [{ type: "text", text: `Proposed: ${summary}. Awaiting confirmation.` }],
    };
  },
);

// ---- update_task ----

server.tool(
  "update_task",
  "Update an existing task. Pass the task ID and only the fields to change. Creates a pending action the user must confirm.",
  {
    task_id: z.string().describe("Convex task ID (from [id: ...] in context)"),
    title: z.string().optional().describe("New title"),
    priority: z.enum(["high", "medium", "low"]).optional().describe("New priority"),
    due_date: z.string().optional().describe("New due date as ISO 8601"),
    has_due_time: z.boolean().optional().describe("Whether due date includes specific time"),
    completed: z.boolean().optional().describe("Mark as completed or incomplete"),
    notes: z.string().optional().describe("New notes"),
    previous_title: z.string().optional().describe("Previous title (for diff)"),
  },
  async (args) => {
    const payload = { id: args.task_id };
    const previousValues = {};
    const changes = [];

    if (args.title !== undefined) {
      payload.title = args.title;
      if (args.previous_title) previousValues.title = args.previous_title;
      changes.push(`title → "${args.title}"`);
    }
    if (args.priority !== undefined) {
      payload.priority = args.priority;
      changes.push(`priority → ${args.priority}`);
    }
    if (args.due_date !== undefined) {
      payload.dueDate = toUtcMs(args.due_date);
      payload.hasDueTime = args.has_due_time ?? false;
      changes.push(`due → ${formatMs(payload.dueDate)}`);
    }
    if (args.completed !== undefined) {
      payload.completed = args.completed;
      changes.push(args.completed ? "marked complete" : "marked incomplete");
    }
    if (args.notes !== undefined) payload.notes = args.notes;

    if (Object.keys(previousValues).length > 0) {
      payload.previousValues = previousValues;
    }

    const summary = `Update task: ${changes.join(", ") || "fields changed"}`;

    const action = {
      type: "update_task",
      displaySummary: summary,
      payload,
    };

    await postPendingAction(
      `I'll update that task for you.`,
      action,
    );

    return {
      content: [{ type: "text", text: `Proposed: ${summary}. Awaiting confirmation.` }],
    };
  },
);

// ---- delete_task ----

server.tool(
  "delete_task",
  "Delete a task. Pass the task ID from get_calendar_context. Creates a pending action the user must confirm.",
  {
    task_id: z.string().describe("Convex task ID to delete"),
    task_title: z.string().optional().describe("Task title (for display summary)"),
  },
  async (args) => {
    const summary = `Delete task: ${args.task_title || "task"}`;

    const action = {
      type: "delete_task",
      displaySummary: summary,
      payload: { id: args.task_id },
    };

    await postPendingAction(
      `I'll delete "${args.task_title || "that task"}" for you.`,
      action,
    );

    return {
      content: [{ type: "text", text: `Proposed: ${summary}. Awaiting confirmation.` }],
    };
  },
);

// ---------------------------------------------------------------------------
// Start
// ---------------------------------------------------------------------------

const transport = new StdioServerTransport();
await server.connect(transport);
