// server.js
// Main entry point — creates the Fastify server, registers routes, starts cron jobs.

import 'dotenv/config';
import Fastify from 'fastify';
import cors from '@fastify/cors';
import { startPollingJob } from './jobs/pollFlights.js';

// ─── Create Server ───────────────────────────────────────────────────────────

const fastify = Fastify({
  logger: true,
  // Pretty logs in development
  ...(process.env.NODE_ENV !== 'production' && {
    logger: { transport: { target: 'pino-pretty' } }
  })
});

// ─── CORS (allow requests from your iOS app and Postman) ─────────────────────

await fastify.register(cors, {
  origin: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS']
});

// ─── Auth Hook (verify Supabase JWT on protected routes) ─────────────────────
// All routes except /health require a valid Bearer token

fastify.addHook('preHandler', async (request, reply) => {
  // Skip auth for health check
  if (request.url === '/health') return;

  const authHeader = request.headers['authorization'];
  if (!authHeader?.startsWith('Bearer ')) {
    return reply.code(401).send({ code: 'UNAUTHORIZED', message: 'Missing auth token' });
  }

  const token = authHeader.slice(7);
  // Verify the token with Supabase — this also extracts the user's ID
  const { createClient } = await import('@supabase/supabase-js');
  const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
  );
  const { data: { user }, error } = await supabase.auth.getUser(token);
  if (error || !user) {
    return reply.code(401).send({ code: 'UNAUTHORIZED', message: 'Invalid token' });
  }
  request.userId = user.id;  // attach userId to request for use in routes
});

// ─── Routes ──────────────────────────────────────────────────────────────────

const { default: flightRoutes }  = await import('./routes/flights.js');
const { default: tripRoutes }    = await import('./routes/trips.js');
const { default: deviceRoutes }  = await import('./routes/devices.js');
const { default: airportRoutes } = await import('./routes/airports.js');

await fastify.register(flightRoutes,  { prefix: '/flights' });
await fastify.register(tripRoutes,    { prefix: '/trips' });
await fastify.register(deviceRoutes,  { prefix: '/devices' });
await fastify.register(airportRoutes, { prefix: '/airports' });

// Health check (no auth)
fastify.get('/health', async () => ({ status: 'ok', timestamp: new Date().toISOString() }));

// ─── Start Server ─────────────────────────────────────────────────────────────

const port = parseInt(process.env.PORT ?? '3000');

try {
  await fastify.listen({ port, host: '0.0.0.0' });
  fastify.log.info(`Server running on port ${port}`);

  // Start background cron job to poll flight statuses every 60 seconds
  startPollingJob();
  fastify.log.info('Flight polling cron job started');
} catch (err) {
  fastify.log.error(err);
  process.exit(1);
}
