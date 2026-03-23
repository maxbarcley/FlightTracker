-- =============================================================================
-- Migration 001: Initial Schema
-- Run this in your Supabase SQL Editor (supabase.com/dashboard → SQL Editor)
-- =============================================================================

-- Enable UUID generation (already enabled in Supabase by default)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================================
-- TRIPS
-- A trip belongs to one user and contains multiple flights.
-- =============================================================================

CREATE TABLE trips (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name        TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for fast lookup of trips by user
CREATE INDEX idx_trips_user_id ON trips(user_id);

-- Row Level Security: users can only see their own trips
ALTER TABLE trips ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own trips"
  ON trips
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- =============================================================================
-- FLIGHTS
-- Each flight belongs to a trip and stores cached live status.
-- =============================================================================

CREATE TABLE flights (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id             UUID REFERENCES trips(id) ON DELETE CASCADE NOT NULL,
  flight_number       TEXT NOT NULL,
  departure_date      DATE NOT NULL,
  scheduled_departure TIMESTAMPTZ,
  origin_iata         CHAR(3),
  destination_iata    CHAR(3),
  cached_status       JSONB,              -- last full API response, used by cron
  last_checked_at     TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for cron job queries
CREATE INDEX idx_flights_trip_id      ON flights(trip_id);
CREATE INDEX idx_flights_departure    ON flights(scheduled_departure);
CREATE INDEX idx_flights_status       ON flights((cached_status->>'status'));

-- Row Level Security: inherited through trips via JOIN or service role in cron
ALTER TABLE flights ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage flights in their trips"
  ON flights
  FOR ALL
  USING (
    trip_id IN (SELECT id FROM trips WHERE user_id = auth.uid())
  )
  WITH CHECK (
    trip_id IN (SELECT id FROM trips WHERE user_id = auth.uid())
  );

-- =============================================================================
-- DEVICE TOKENS
-- Maps APNs device tokens to user accounts for push notification delivery.
-- =============================================================================

CREATE TABLE device_tokens (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  apns_token  TEXT UNIQUE NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_device_tokens_user_id ON device_tokens(user_id);

-- Only the service role can write device tokens (the iOS app sends them via your server)
-- Users can read their own tokens for display in settings
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read their own device tokens"
  ON device_tokens
  FOR SELECT
  USING (auth.uid() = user_id);

-- =============================================================================
-- AUTO-UPDATE updated_at timestamps
-- =============================================================================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trips_updated_at
  BEFORE UPDATE ON trips
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER device_tokens_updated_at
  BEFORE UPDATE ON device_tokens
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =============================================================================
-- Done!
-- Next steps:
--   1. Run this in Supabase SQL Editor
--   2. Enable "Sign in with Apple" in Supabase Auth > Providers
--   3. Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in your .env
-- =============================================================================
