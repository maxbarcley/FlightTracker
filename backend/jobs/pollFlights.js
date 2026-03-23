// jobs/pollFlights.js
// Cron job that runs every 60 seconds.
// Fetches live status for all active tracked flights and sends push
// notifications when anything changes (delay, gate, landing, etc.).

import cron from 'node-cron';
import { createClient } from '@supabase/supabase-js';
import { getFlightDetail } from '../services/aeroDataBox.js';
import {
  sendPushNotification,
  buildDelayNotification,
  buildGateChangeNotification,
  buildBoardingNotification,
  buildLandingNotification,
  buildCancellationNotification
} from '../services/notifications.js';

function supabase() {
  return createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
  );
}

// ─── Start the cron job ───────────────────────────────────────────────────────

export function startPollingJob() {
  // Run every 60 seconds
  cron.schedule('* * * * *', async () => {
    try {
      await pollActiveFlights();
    } catch (err) {
      console.error('[PollJob] Unhandled error:', err);
    }
  });
}

// ─── Main polling function ────────────────────────────────────────────────────

async function pollActiveFlights() {
  const db = supabase();
  const now = new Date();

  // Get all flights departing within the next 48 hours or currently active
  // (no point polling flights that landed > 2 hours ago or depart > 48h away)
  const windowStart = new Date(now.getTime() - 2 * 60 * 60 * 1000).toISOString();
  const windowEnd   = new Date(now.getTime() + 48 * 60 * 60 * 1000).toISOString();

  const { data: flights, error } = await db
    .from('flights')
    .select('*, trips(user_id)')
    .gte('scheduled_departure', windowStart)
    .lte('scheduled_departure', windowEnd)
    .not('cached_status->status', 'in', '("landed","cancelled")');

  if (error) {
    console.error('[PollJob] DB error fetching flights:', error.message);
    return;
  }

  if (!flights?.length) return;

  console.log(`[PollJob] Polling ${flights.length} active flight(s)…`);

  // Process flights concurrently but limit to 5 at a time to respect API rate limits
  await processInBatches(flights, 5, async (flight) => {
    await checkAndNotify(flight, db);
  });
}

// ─── Check one flight and send notifications if status changed ────────────────

async function checkAndNotify(flight, db) {
  const dateStr = flight.scheduled_departure.slice(0, 10);
  let fresh;
  try {
    fresh = await getFlightDetail(flight.flight_number, dateStr);
  } catch (err) {
    console.warn(`[PollJob] Failed to fetch ${flight.flight_number}: ${err.message}`);
    return;
  }

  const prev = flight.cached_status || {};

  // Build list of changes to notify about
  const notifications = detectChanges(prev, fresh, flight.flight_number);

  // Always update the cached status in the database
  await db
    .from('flights')
    .update({
      cached_status: fresh,
      last_checked_at: new Date().toISOString()
    })
    .eq('id', flight.id);

  if (notifications.length === 0) return;

  // Get all device tokens for users who have this flight in any trip
  const userId = flight.trips?.user_id;
  if (!userId) return;

  const { data: tokens } = await db
    .from('device_tokens')
    .select('apns_token')
    .eq('user_id', userId);

  if (!tokens?.length) return;
  const deviceTokens = tokens.map(t => t.apns_token);

  // Send each notification
  for (const notif of notifications) {
    await sendPushNotification(deviceTokens, notif.title, notif.body, {
      flightId: flight.id,
      flightNumber: flight.flight_number
    });
  }
}

// ─── Detect what changed between previous and fresh status ───────────────────

function detectChanges(prev, fresh, flightNumber) {
  const changes = [];
  const origin = fresh.origin?.iata || '';
  const dest = fresh.destination?.iata || '';

  // Status changes
  if (prev.status !== fresh.status) {
    if (fresh.status === 'landed') {
      const notif = buildLandingNotification(
        flightNumber, dest, fresh.destination?.baggage_claim
      );
      changes.push(notif);
    } else if (fresh.status === 'cancelled') {
      changes.push(buildCancellationNotification(flightNumber));
    } else if (fresh.status === 'active' && prev.status !== 'active') {
      // Departed — check if there's a gate to mention
      const gate = fresh.origin?.gate;
      if (gate) {
        changes.push(buildBoardingNotification(flightNumber, gate));
      }
    }
  }

  // Delay changes (only notify if delay increased by more than 10 minutes)
  const prevDelay = prev.delay_minutes || 0;
  const freshDelay = fresh.delay_minutes || 0;
  if (freshDelay > prevDelay + 10 && freshDelay > 15) {
    changes.push(buildDelayNotification(flightNumber, freshDelay, origin, dest));
  }

  // Gate change
  if (prev.origin?.gate && fresh.origin?.gate &&
      prev.origin.gate !== fresh.origin.gate) {
    changes.push(buildGateChangeNotification(
      flightNumber, fresh.origin.gate, fresh.origin.terminal
    ));
  }

  return changes;
}

// ─── Batch processing helper ──────────────────────────────────────────────────

async function processInBatches(items, batchSize, fn) {
  for (let i = 0; i < items.length; i += batchSize) {
    const batch = items.slice(i, i + batchSize);
    await Promise.all(batch.map(fn));
    // Small delay between batches to stay within API rate limits
    if (i + batchSize < items.length) {
      await new Promise(r => setTimeout(r, 200));
    }
  }
}
