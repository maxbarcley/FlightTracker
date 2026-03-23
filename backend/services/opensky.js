// services/opensky.js
// Fetches live aircraft positions from the OpenSky Network (free, no API key required).
// Returns position data for a specific aircraft ICAO24 transponder code.

import fetch from 'node-fetch';

const BASE_URL = 'https://opensky-network.org/api';

// Optional: set OPENSKY_USERNAME and OPENSKY_PASSWORD in .env for higher rate limits
function authHeader() {
  const user = process.env.OPENSKY_USERNAME;
  const pass = process.env.OPENSKY_PASSWORD;
  if (!user || !pass) return {};
  const encoded = Buffer.from(`${user}:${pass}`).toString('base64');
  return { Authorization: `Basic ${encoded}` };
}

/**
 * Get the current position of an aircraft by its ICAO24 transponder code.
 * The ICAO24 is a 6-character hex string derived from the tail number.
 *
 * Note: OpenSky data is typically 10–15 seconds delayed on the free tier.
 */
export async function getAircraftPosition(icao24) {
  if (!icao24) return null;

  try {
    const url = `${BASE_URL}/states/all?icao24=${icao24.toLowerCase()}`;
    const res = await fetch(url, { headers: authHeader() });
    if (!res.ok) return null;

    const data = await res.json();
    if (!data?.states?.length) return null;

    // OpenSky state vector format:
    // [icao24, callsign, origin_country, time_position, last_contact,
    //  longitude, latitude, baro_altitude, on_ground, velocity,
    //  true_track, vertical_rate, sensors, geo_altitude, squawk, spi, position_source]
    const state = data.states[0];
    const [, , , , , lon, lat, baroAlt, onGround, velocity, heading, vRate] = state;

    if (onGround) return null;  // Don't show ground position
    if (!lat || !lon) return null;

    return {
      latitude: lat,
      longitude: lon,
      altitude: baroAlt ? Math.round(baroAlt * 3.28084) : 0,  // meters to feet
      speed: velocity ? Math.round(velocity * 1.944)           : 0,  // m/s to knots
      heading: heading || 0,
      vertical_rate: vRate ? Math.round(vRate * 196.85) : 0,  // m/s to ft/min
      timestamp: new Date().toISOString()
    };
  } catch (err) {
    console.error('OpenSky error:', err.message);
    return null;
  }
}

/**
 * Get all aircraft currently within a bounding box.
 * Useful for showing regional traffic on the map.
 * @param {number} latMin @param {number} latMax @param {number} lonMin @param {number} lonMax
 */
export async function getAircraftInRegion(latMin, latMax, lonMin, lonMax) {
  try {
    const url = `${BASE_URL}/states/all?lamin=${latMin}&lamax=${latMax}&lomin=${lonMin}&lomax=${lonMax}`;
    const res = await fetch(url, { headers: authHeader() });
    if (!res.ok) return [];
    const data = await res.json();
    if (!data?.states) return [];

    return data.states
      .filter(s => !s[8])  // exclude aircraft on ground
      .map(s => ({
        icao24: s[0],
        callsign: (s[1] || '').trim(),
        latitude: s[6],
        longitude: s[5],
        altitude: s[7] ? Math.round(s[7] * 3.28084) : 0,
        speed: s[9] ? Math.round(s[9] * 1.944) : 0,
        heading: s[10] || 0
      }))
      .filter(a => a.latitude && a.longitude);
  } catch {
    return [];
  }
}
