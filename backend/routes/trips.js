// routes/trips.js
// POST /trips              — create a trip for the authenticated user
// POST /trips/:id/flights  — add a flight to a trip (also starts polling it)

import { createClient } from '@supabase/supabase-js';
import { getFlightDetail } from '../services/aeroDataBox.js';

function db() {
  return createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
}

export default async function tripRoutes(fastify) {

  // ── Create Trip ────────────────────────────────────────────────────────────
  fastify.post('/', {
    schema: {
      body: {
        type: 'object',
        required: ['name'],
        properties: { name: { type: 'string', minLength: 1, maxLength: 100 } }
      }
    }
  }, async (request, reply) => {
    const userId = request.userId;
    const { name } = request.body;

    const { data, error } = await db()
      .from('trips')
      .insert({ user_id: userId, name })
      .select()
      .single();

    if (error) {
      return reply.code(500).send({ code: 'DB_ERROR', message: error.message });
    }
    return reply.code(201).send(data);
  });

  // ── Add Flight to Trip ────────────────────────────────────────────────────
  fastify.post('/:tripId/flights', {
    schema: {
      params: {
        type: 'object',
        properties: { tripId: { type: 'string', format: 'uuid' } }
      },
      body: {
        type: 'object',
        required: ['flight_number', 'date'],
        properties: {
          flight_number: { type: 'string' },
          date: { type: 'string', pattern: '^\\d{4}-\\d{2}-\\d{2}$' }
        }
      }
    }
  }, async (request, reply) => {
    const userId = request.userId;
    const { tripId } = request.params;
    const { flight_number, date } = request.body;

    // Verify the trip belongs to this user
    const { data: trip, error: tripErr } = await db()
      .from('trips')
      .select('id')
      .eq('id', tripId)
      .eq('user_id', userId)
      .single();

    if (tripErr || !trip) {
      return reply.code(404).send({ code: 'NOT_FOUND', message: 'Trip not found' });
    }

    // Fetch initial flight status from AeroDataBox
    let initialStatus = null;
    let scheduledDeparture = null;
    let originIata = '';
    let destIata = '';

    try {
      const detail = await getFlightDetail(flight_number, date);
      initialStatus = detail;
      scheduledDeparture = detail.departure?.scheduled || `${date}T00:00:00Z`;
      originIata = detail.origin?.iata || '';
      destIata = detail.destination?.iata || '';
    } catch {
      // Non-fatal: use provided date as departure time
      scheduledDeparture = `${date}T00:00:00Z`;
    }

    const { data, error } = await db()
      .from('flights')
      .insert({
        trip_id: tripId,
        flight_number: flight_number.toUpperCase(),
        departure_date: date,
        scheduled_departure: scheduledDeparture,
        origin_iata: originIata,
        destination_iata: destIata,
        cached_status: initialStatus,
        last_checked_at: new Date().toISOString()
      })
      .select()
      .single();

    if (error) {
      return reply.code(500).send({ code: 'DB_ERROR', message: error.message });
    }
    return reply.code(201).send(data);
  });

  // ── Delete Flight from Trip ───────────────────────────────────────────────
  fastify.delete('/:tripId/flights/:flightId', async (request, reply) => {
    const userId = request.userId;
    const { tripId, flightId } = request.params;

    // Verify ownership via trip join
    const { error } = await db()
      .from('flights')
      .delete()
      .eq('id', flightId)
      .eq('trip_id', tripId)
      // Sub-select to confirm trip belongs to user
      .in('trip_id',
        db().from('trips').select('id').eq('user_id', userId)
      );

    if (error) {
      return reply.code(500).send({ code: 'DB_ERROR', message: error.message });
    }
    return reply.code(204).send();
  });
}
