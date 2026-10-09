-- migrate.sql - Boss Monster initial schema (PostgreSQL)
-- Idempotent: safe to run on every server boot.

CREATE TABLE IF NOT EXISTS matches (
  id            TEXT PRIMARY KEY,
  game_name     TEXT NOT NULL DEFAULT 'boss-monster',
  num_players   INTEGER NOT NULL,
  state         JSONB NOT NULL,             -- snapshot of G
  ctx           JSONB NOT NULL,              -- snapshot of ctx (turn, phase, currentPlayer, activePlayer)
  status        TEXT NOT NULL DEFAULT 'open',-- open | running | finished | abandoned
  winner        INTEGER,
  setup_data    JSONB,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_matches_status  ON matches(status);
CREATE INDEX IF NOT EXISTS idx_matches_updated ON matches(updated_at);
CREATE INDEX IF NOT EXISTS idx_matches_game    ON matches(game_name);

CREATE TABLE IF NOT EXISTS match_players (
  match_id     TEXT NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  player_id    INTEGER NOT NULL,
  player_name  TEXT,
  credentials  TEXT,
  is_bot       BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (match_id, player_id)
);
CREATE INDEX IF NOT EXISTS idx_match_players_match ON match_players(match_id);

-- Bump updated_at on row update
CREATE OR REPLACE FUNCTION bump_updated_at() RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_matches_bump ON matches;
CREATE TRIGGER trg_matches_bump BEFORE UPDATE ON matches
FOR EACH ROW EXECUTE FUNCTION bump_updated_at();