import { internalAction, internalMutation, query } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";

/**
 * List all studio events ordered by start time (ascending).
 * Studio events are read-only in Convex — source of truth is Supabase.
 */
export const list = query({
  handler: async (ctx) => {
    return await ctx.db.query("studio_events").withIndex("by_start").collect();
  },
});

/**
 * Internal action: fetches studio events from Supabase and upserts them into Convex.
 * Triggered by the cron job in crons.ts every 15 minutes.
 *
 * Requires environment variables:
 *   SUPABASE_EVENTS_URL  — e.g. https://xxx.supabase.co/rest/v1/studio_events
 *   SUPABASE_ANON_KEY    — Supabase anon/public API key
 *
 * Error handling: if the fetch fails, logs the error and returns without crashing the cron.
 */
export const syncFromSupabase = internalAction({
  handler: async (ctx) => {
    const url = process.env.SUPABASE_EVENTS_URL;
    const key = process.env.SUPABASE_ANON_KEY;

    if (!url || !key) {
      console.error(
        "[studioEvents.syncFromSupabase] Missing env vars: SUPABASE_EVENTS_URL and/or SUPABASE_ANON_KEY. " +
        "Set them in Convex Dashboard > Settings > Environment Variables."
      );
      return;
    }

    let rows: unknown[];
    try {
      const response = await fetch(url, {
        headers: {
          apikey: key,
          Authorization: `Bearer ${key}`,
        },
      });

      if (!response.ok) {
        console.error(
          `[studioEvents.syncFromSupabase] Supabase fetch failed: ${response.status} ${response.statusText}`
        );
        return;
      }

      rows = await response.json() as unknown[];
    } catch (error) {
      console.error("[studioEvents.syncFromSupabase] Fetch error:", error);
      return;
    }

    await ctx.runMutation(internal.studioEvents.upsertAll, { rows });
    console.log(`[studioEvents.syncFromSupabase] Synced ${rows.length} studio events from Supabase.`);
  },
});

/**
 * Internal mutation: upserts studio events received from Supabase.
 * Deduplication is done by title (update with real Supabase PK when known).
 * All v.int64() fields use BigInt() explicitly to avoid ArgumentValidationError.
 */
export const upsertAll = internalMutation({
  args: {
    rows: v.array(v.any()),
  },
  handler: async (ctx, { rows }) => {
    for (const row of rows as Record<string, unknown>[]) {
      // Locate existing record by title for deduplication.
      // TODO: Replace title match with Supabase primary key once the
      // actual Supabase schema is confirmed (e.g., row.id or row.supabase_id).
      const existing = await ctx.db
        .query("studio_events")
        .filter((q) => q.eq(q.field("title"), row.title as string))
        .first();

      const now = BigInt(Date.now());

      if (existing) {
        // Update existing record — always refresh lastSyncedAt and mutable fields.
        await ctx.db.patch(existing._id, {
          title: String(row.title ?? ""),
          start: BigInt(Number(row.start ?? 0)),
          duration: BigInt(Number(row.duration ?? 0)),
          timezone: String(row.timezone ?? "UTC"),
          isAllDay: Boolean(row.is_all_day ?? row.isAllDay ?? false),
          lastSyncedAt: now,
        });
      } else {
        // Insert new record.
        await ctx.db.insert("studio_events", {
          calendarId: "studio",
          title: String(row.title ?? ""),
          start: BigInt(Number(row.start ?? 0)),
          duration: BigInt(Number(row.duration ?? 0)),
          timezone: String(row.timezone ?? "UTC"),
          isAllDay: Boolean(row.is_all_day ?? row.isAllDay ?? false),
          lastSyncedAt: now,
        });
      }
    }
  },
});
