import { cronJobs } from "convex/server";
import { internal } from "./_generated/api";

const crons = cronJobs();

// Sync studio events from Supabase every 15 minutes.
// The 15-minute interval is appropriate for booking data that changes infrequently.
// This runs server-side — even when no client is connected.
crons.interval(
  "sync studio events from Supabase",
  { minutes: 15 },
  internal.studioEvents.syncFromSupabase,
);

export default crons;
