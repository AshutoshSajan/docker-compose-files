-- Example seed script for pgsql.yml.
-- Files in this directory run once on first DB init (empty data volume).
CREATE TABLE IF NOT EXISTS app_health (
  id SERIAL PRIMARY KEY,
  checked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  status TEXT NOT NULL DEFAULT 'ok'
);
