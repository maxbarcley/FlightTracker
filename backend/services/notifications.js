// services/notifications.js
// Sends Apple Push Notifications (APNs) via the node-apn library.
// Called by the polling job whenever a flight status changes.

import apn from 'node-apn';
import { createClient } from '@supabase/supabase-js';
import { readFileSync, existsSync } from 'fs';

// ─── APNs Provider ────────────────────────────────────────────────────────────

let provider;

function getProvider() {
  if (provider) return provider;

  const keyPath = './apns-key.p8';
  if (!existsSync(keyPath)) {
    console.warn('apns-key.p8 not found — push notifications disabled. See .env.example.');
    return null;
  }

  provider = new apn.Provider({
    token: {
      key: readFileSync(keyPath),
      keyId: process.env.APNS_KEY_ID,
      teamId: process.env.APNS_TEAM_ID
    },
    production: process.env.APNS_ENVIRONMENT === 'production'
  });

  return provider;
}

// ─── Send a single notification ───────────────────────────────────────────────

/**
 * @param {string[]} deviceTokens  APNs tokens to send to
 * @param {string}   title         Notification title (bold)
 * @param {string}   body          Notification body text
 * @param {object}   data          Custom payload (merged into the notification)
 */
export async function sendPushNotification(deviceTokens, title, body, data = {}) {
  const prov = getProvider();
  if (!prov || deviceTokens.length === 0) return;

  const note = new apn.Notification();
  note.expiry = Math.floor(Date.now() / 1000) + 3600;  // expire after 1 hour
  note.badge = 1;
  note.sound = 'default';
  note.alert = { title, body };
  note.topic = process.env.APNS_BUNDLE_ID;
  note.category = 'FLIGHT_UPDATE';
  note.payload = data;

  const result = await prov.send(note, deviceTokens);

  if (result.failed.length > 0) {
    console.error('APNs failures:', result.failed.map(f => f.error?.reason).join(', '));
    // Remove invalid tokens from database
    await cleanupInvalidTokens(result.failed);
  }

  return result;
}

// ─── Notification Templates ───────────────────────────────────────────────────

export function buildDelayNotification(flightNumber, delayMinutes, origin, destination) {
  const hrs = Math.floor(delayMinutes / 60);
  const mins = delayMinutes % 60;
  const delayStr = hrs > 0 ? `${hrs}h ${mins}m` : `${mins} minutes`;
  return {
    title: `${flightNumber} delayed ⏱`,
    body: `Your flight from ${origin} to ${destination} is delayed by ${delayStr}.`
  };
}

export function buildGateChangeNotification(flightNumber, newGate, terminal) {
  const loc = terminal ? `Terminal ${terminal}, Gate ${newGate}` : `Gate ${newGate}`;
  return {
    title: `${flightNumber} gate change 🚪`,
    body: `New departure gate: ${loc}`
  };
}

export function buildBoardingNotification(flightNumber, gate) {
  return {
    title: `${flightNumber} now boarding ✈️`,
    body: gate ? `Head to Gate ${gate}` : 'Head to your gate'
  };
}

export function buildLandingNotification(flightNumber, destination, baggageClaim) {
  const extra = baggageClaim ? ` Baggage: Carousel ${baggageClaim}.` : '';
  return {
    title: `${flightNumber} has landed 🛬`,
    body: `Your flight has arrived at ${destination}.${extra}`
  };
}

export function buildCancellationNotification(flightNumber) {
  return {
    title: `${flightNumber} cancelled ❌`,
    body: 'Your flight has been cancelled. Check with your airline for rebooking options.'
  };
}

// ─── Cleanup invalid tokens ───────────────────────────────────────────────────

async function cleanupInvalidTokens(failures) {
  const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
  );
  const invalidReasons = ['BadDeviceToken', 'Unregistered', 'DeviceTokenNotForTopic'];
  const tokensToRemove = failures
    .filter(f => invalidReasons.includes(f.error?.reason))
    .map(f => f.device);

  if (tokensToRemove.length === 0) return;

  await supabase
    .from('device_tokens')
    .delete()
    .in('apns_token', tokensToRemove);
}
