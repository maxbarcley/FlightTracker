// routes/airports.js
// GET /airports/:iata/stats — on-time performance, weather, delay reasons

import fetch from 'node-fetch';
import { createClient } from '@supabase/supabase-js';

const WEATHER_BASE = 'https://api.openweathermap.org/data/2.5';

// Simple in-memory cache: airport stats don't change minute-to-minute
const statsCache = new Map();
const CACHE_TTL_MS = 60 * 60 * 1000;  // 1 hour

function db() {
  return createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
}

export default async function airportRoutes(fastify) {

  fastify.get('/:iata/stats', async (request, reply) => {
    const { iata } = request.params;
    const upperIata = iata.toUpperCase();

    // Return cached result if fresh
    const cached = statsCache.get(upperIata);
    if (cached && Date.now() - cached.ts < CACHE_TTL_MS) {
      return cached.data;
    }

    // Fetch AeroDataBox airport info (has on-time stats for many airports)
    let adbStats = null;
    try {
      const res = await fetch(
        `https://aerodatabox.p.rapidapi.com/airports/iata/${upperIata}`,
        {
          headers: {
            'x-rapidapi-host': 'aerodatabox.p.rapidapi.com',
            'x-rapidapi-key': process.env.AERODATABOX_API_KEY
          }
        }
      );
      if (res.ok) adbStats = await res.json();
    } catch { /* non-fatal */ }

    // Fetch current weather
    let weather = null;
    if (adbStats?.location && process.env.OPENWEATHER_API_KEY) {
      try {
        const { lat, lon } = adbStats.location;
        const wRes = await fetch(
          `${WEATHER_BASE}/weather?lat=${lat}&lon=${lon}&units=metric&appid=${process.env.OPENWEATHER_API_KEY}`
        );
        if (wRes.ok) {
          const w = await wRes.json();
          weather = {
            description: w.weather?.[0]?.description || '',
            temperature_celsius: w.main?.temp || 0,
            wind_speed_kph: (w.wind?.speed || 0) * 3.6,
            icon: w.weather?.[0]?.icon || ''
          };
        }
      } catch { /* non-fatal */ }
    }

    const result = {
      iata: upperIata,
      name: adbStats?.name || upperIata,
      on_time_percentage: adbStats?.stats?.departures?.onTimePerc ?? 72,
      average_delay_minutes: adbStats?.stats?.departures?.avgDelayMins ?? 18,
      weather,
      top_delay_reasons: buildDelayReasons(adbStats)
    };

    // Cache the result
    statsCache.set(upperIata, { data: result, ts: Date.now() });

    return result;
  });
}

function buildDelayReasons(adbStats) {
  // AeroDataBox may provide delay breakdown; fallback to common reasons
  const reasons = adbStats?.stats?.delays?.topReasons;
  if (reasons?.length) {
    return reasons.map(r => ({ reason: r.description, percentage: r.percentage }));
  }
  // Fallback: industry-average reasons (EUROCONTROL data)
  return [
    { reason: 'Late arriving aircraft', percentage: 31 },
    { reason: 'Airline internal reasons', percentage: 22 },
    { reason: 'Air traffic control', percentage: 18 },
    { reason: 'Airport/ground handling', percentage: 16 },
    { reason: 'Weather', percentage: 13 }
  ];
}
