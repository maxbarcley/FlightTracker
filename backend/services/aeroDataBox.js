// services/aeroDataBox.js
// Wrapper around the AeroDataBox API (via RapidAPI).
// All flight data requests go through here so you can easily swap providers later.

import fetch from 'node-fetch';

const BASE_URL = 'https://aerodatabox.p.rapidapi.com';
const HEADERS = {
  'x-rapidapi-host': 'aerodatabox.p.rapidapi.com',
  'x-rapidapi-key': process.env.AERODATABOX_API_KEY
};

// ─── Internal fetch helper ────────────────────────────────────────────────────

async function adbRequest(path) {
  const res = await fetch(`${BASE_URL}${path}`, { headers: HEADERS });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`AeroDataBox error ${res.status}: ${text}`);
  }
  return res.json();
}

// ─── Flight Search ────────────────────────────────────────────────────────────

/**
 * Search for flights by flight number and date.
 * Returns an array of matching flights (there may be multiple legs on one number).
 */
export async function searchFlights(flightNumber, dateString) {
  // dateString format: "YYYY-MM-DD"
  const clean = flightNumber.replace(/\s+/g, '').toUpperCase();
  const data = await adbRequest(`/flights/number/${clean}/${dateString}`);

  return (Array.isArray(data) ? data : [data]).map(normalizeFlightSummary);
}

// ─── Flight Detail ────────────────────────────────────────────────────────────

/**
 * Get full flight detail including live status, gate, aircraft, delay info.
 */
export async function getFlightDetail(flightNumber, dateString) {
  const clean = flightNumber.replace(/\s+/g, '').toUpperCase();
  const data = await adbRequest(`/flights/number/${clean}/${dateString}`);
  const flight = Array.isArray(data) ? data[0] : data;
  if (!flight) throw new Error('Flight not found');
  return normalizeFlightDetail(flight);
}

// ─── Inbound Aircraft ("Where's my plane?") ──────────────────────────────────

/**
 * Given a tail number, find the flight it's currently operating.
 * Used for the "Where's my plane?" feature.
 */
export async function getInboundFlight(tailNumber, arrivalAirportICAO) {
  try {
    // Look up all arrivals at the airport in the past 4 hours
    const now = new Date();
    const fourHoursAgo = new Date(now.getTime() - 4 * 60 * 60 * 1000);
    const fromISO = fourHoursAgo.toISOString().slice(0, 16);
    const toISO = now.toISOString().slice(0, 16);

    const data = await adbRequest(
      `/flights/airports/icao/${arrivalAirportICAO}/${fromISO}/${toISO}?withLeg=true&direction=Arrival&withCancelled=false&withCodeshared=false&withPrivate=false`
    );

    // Find the arrival that uses our tail number
    const arrivals = data?.arrivals?.items || [];
    const match = arrivals.find(f => f.aircraft?.reg?.toUpperCase() === tailNumber.toUpperCase());
    if (!match) return null;

    return {
      flight_number: match.number || '',
      origin_iata: match.departure?.airport?.iata || '',
      status: normalizeStatus(match.status),
      estimated_arrival: match.arrival?.scheduledTime?.utc || null,
      delay_minutes: match.arrival?.delay || 0
    };
  } catch {
    return null;  // non-fatal — just don't show the inbound card
  }
}

// ─── Airport Stats ────────────────────────────────────────────────────────────

export async function getAirportInfo(icaoCode) {
  const data = await adbRequest(`/airports/icao/${icaoCode}`);
  return data;
}

// ─── Normalization helpers ────────────────────────────────────────────────────

function normalizeFlightSummary(raw) {
  return {
    id: `${raw.number || ''}-${raw.departure?.scheduledTime?.utc?.slice(0, 10) || ''}`,
    flight_number: raw.number || '',
    origin_iata: raw.departure?.airport?.iata || '',
    destination_iata: raw.arrival?.airport?.iata || '',
    origin_city: raw.departure?.airport?.municipalityName || '',
    destination_city: raw.arrival?.airport?.municipalityName || '',
    scheduled_departure: raw.departure?.scheduledTime?.utc || null,
    scheduled_arrival: raw.arrival?.scheduledTime?.utc || null,
    airline: raw.airline?.name || ''
  };
}

function normalizeFlightDetail(raw) {
  return {
    flight_number: raw.number || '',
    airline: {
      iata: raw.airline?.iata || '',
      name: raw.airline?.name || '',
      logo_url: null
    },
    origin: {
      iata: raw.departure?.airport?.iata || '',
      icao: raw.departure?.airport?.icao || '',
      name: raw.departure?.airport?.name || '',
      city: raw.departure?.airport?.municipalityName || '',
      country: raw.departure?.airport?.countryCode || '',
      latitude: raw.departure?.airport?.location?.lat || 0,
      longitude: raw.departure?.airport?.location?.lon || 0,
      terminal: raw.departure?.terminal || null,
      gate: raw.departure?.gate || null,
      baggage_claim: null
    },
    destination: {
      iata: raw.arrival?.airport?.iata || '',
      icao: raw.arrival?.airport?.icao || '',
      name: raw.arrival?.airport?.name || '',
      city: raw.arrival?.airport?.municipalityName || '',
      country: raw.arrival?.airport?.countryCode || '',
      latitude: raw.arrival?.airport?.location?.lat || 0,
      longitude: raw.arrival?.airport?.location?.lon || 0,
      terminal: raw.arrival?.terminal || null,
      gate: raw.arrival?.gate || null,
      baggage_claim: raw.arrival?.baggageClaim || null
    },
    departure: {
      scheduled: raw.departure?.scheduledTime?.utc || null,
      actual: raw.departure?.actualTime?.utc || null,
      estimated: raw.departure?.estimatedTime?.utc || null
    },
    arrival: {
      scheduled: raw.arrival?.scheduledTime?.utc || null,
      actual: raw.arrival?.actualTime?.utc || null,
      estimated: raw.arrival?.estimatedTime?.utc || null
    },
    status: normalizeStatus(raw.status),
    delay_minutes: raw.departure?.delay || raw.arrival?.delay || 0,
    aircraft: raw.aircraft ? {
      tail_number: raw.aircraft.reg || null,
      model: raw.aircraft.model || null,
      manufacturer: raw.aircraft.modeS ? 'Tracked' : null
    } : null
  };
}

function normalizeStatus(raw) {
  if (!raw) return 'scheduled';
  const s = raw.toLowerCase();
  if (s.includes('airborne') || s.includes('enroute')) return 'active';
  if (s.includes('landed') || s.includes('arrived')) return 'landed';
  if (s.includes('cancel')) return 'cancelled';
  if (s.includes('delay')) return 'delayed';
  if (s.includes('divert')) return 'diverted';
  return 'scheduled';
}
