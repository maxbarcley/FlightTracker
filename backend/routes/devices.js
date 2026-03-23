// routes/devices.js
// POST /devices/register — save an APNs device token for the authenticated user

import { createClient } from '@supabase/supabase-js';

function db() {
  return createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
}

export default async function deviceRoutes(fastify) {

  fastify.post('/register', {
    schema: {
      body: {
        type: 'object',
        required: ['token'],
        properties: {
          token: { type: 'string', minLength: 64, maxLength: 200 }
        }
      }
    }
  }, async (request, reply) => {
    const userId = request.userId;
    const { token } = request.body;

    // Upsert: if this token already exists, update the user_id (device may change user)
    const { error } = await db()
      .from('device_tokens')
      .upsert(
        { user_id: userId, apns_token: token, updated_at: new Date().toISOString() },
        { onConflict: 'apns_token' }
      );

    if (error) {
      return reply.code(500).send({ code: 'DB_ERROR', message: error.message });
    }
    return reply.code(201).send({ registered: true });
  });

  fastify.delete('/unregister', {
    schema: {
      body: {
        type: 'object',
        required: ['token'],
        properties: { token: { type: 'string' } }
      }
    }
  }, async (request, reply) => {
    const userId = request.userId;
    const { token } = request.body;

    await db()
      .from('device_tokens')
      .delete()
      .eq('user_id', userId)
      .eq('apns_token', token);

    return { unregistered: true };
  });
}
