// routes/flights.js
// GET /flights/search    — search by flight number + date (used when adding to a trip)
// GET /flights/:number   — full live detail for a specific flight
// GET /flights/:number/position — live aircraft position (from OpenSky)

import { searchFlights, getFlightDetail } from '../services/aeroDataBox.js';
import { getAircraftPosition } from '../services/opensky.js';

export default async function flightRoutes(fastify) {

  // ── Search ────────────────────────────────────────────────────────────────
  fastify.get('/search', {
    schema: {
      querystring: {
        type: 'object',
        required: ['number', 'date'],
        properties: {
          number: { type: 'string' },
          date:   { type: 'string', pattern: '^\\d{4}-\\d{2}-\\d{2}$' }
        }
      }
    }
  }, async (request, reply) => {
    const { number, date } = request.query;
    const results = await searchFlights(number, date);
    return results;
  });

  // ── Full Detail ───────────────────────────────────────────────────────────
  fastify.get('/:number', {
    schema: {
      params: {
        type: 'object',
        properties: { number: { type: 'string' } }
      },
      querystring: {
        type: 'object',
        required: ['date'],
        properties: {
          date: { type: 'string', pattern: '^\\d{4}-\\d{2}-\\d{2}$' }
        }
      }
    }
  }, async (request, reply) => {
    const { number } = request.params;
    const { date } = request.query;
    const detail = await getFlightDetail(number, date);
    return detail;
  });

  // ── Live Aircraft Position ─────────────────────────────────────────────────
  // Requires the aircraft's ICAO24 transponder code as a query param
  // (obtained from the flight detail response's aircraft object)
  fastify.get('/:number/position', async (request, reply) => {
    const { icao24 } = request.query;
    if (!icao24) {
      return { position: null };
    }
    const position = await getAircraftPosition(icao24);
    return { position };
  });
}
