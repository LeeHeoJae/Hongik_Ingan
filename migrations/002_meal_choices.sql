BEGIN;
CREATE TABLE IF NOT EXISTS meal_choice_days (
  menu_date date PRIMARY KEY,
  synced_at timestamptz NOT NULL DEFAULT now()
);
-- statement-breakpoint
CREATE TABLE IF NOT EXISTS meal_choice_polls (
  id text PRIMARY KEY CHECK (id ~ '^[a-f0-9]{64}$'),
  menu_date date NOT NULL REFERENCES meal_choice_days(menu_date),
  options jsonb NOT NULL,
  active boolean NOT NULL DEFAULT true,
  a_votes integer NOT NULL DEFAULT 0 CHECK (a_votes >= 0),
  b_votes integer NOT NULL DEFAULT 0 CHECK (b_votes >= 0),
  version integer NOT NULL DEFAULT 0
);
-- statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS meal_choice_active_day ON meal_choice_polls(menu_date) WHERE active;
-- statement-breakpoint
CREATE TABLE IF NOT EXISTS meal_choices (
  poll_id text NOT NULL REFERENCES meal_choice_polls(id),
  voter_key text NOT NULL CHECK (voter_key ~ '^[a-f0-9]{64}$'),
  choice text NOT NULL CHECK (choice IN ('A', 'B')),
  PRIMARY KEY (poll_id, voter_key)
);
-- statement-breakpoint
CREATE OR REPLACE FUNCTION sync_lunch_poll(p_date date, p_poll jsonb)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO meal_choice_days(menu_date) VALUES (p_date) ON CONFLICT DO NOTHING;
  PERFORM 1 FROM meal_choice_days WHERE menu_date = p_date FOR UPDATE;
  UPDATE meal_choice_polls SET active = false WHERE menu_date = p_date;
  IF p_poll IS NOT NULL AND p_poll <> 'null'::jsonb THEN
    INSERT INTO meal_choice_polls(id, menu_date, options)
      VALUES (p_poll->>'id', p_date, p_poll->'options')
      ON CONFLICT (id) DO UPDATE SET active = true;
  END IF;
  UPDATE meal_choice_days SET synced_at = clock_timestamp() WHERE menu_date = p_date;
END $$;
-- statement-breakpoint
CREATE OR REPLACE FUNCTION set_lunch_choice(p_id text, p_key text, p_choice text)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE poll meal_choice_polls%ROWTYPE; previous text;
BEGIN
  IF p_choice IS NOT NULL AND p_choice NOT IN ('A', 'B') THEN RAISE EXCEPTION 'INVALID_CHOICE'; END IF;
  SELECT * INTO poll FROM meal_choice_polls WHERE id = p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'MENU_UNAVAILABLE'; END IF;
  PERFORM 1 FROM meal_choice_days WHERE menu_date = poll.menu_date FOR UPDATE;
  SELECT * INTO poll FROM meal_choice_polls WHERE id = p_id FOR UPDATE;
  IF NOT poll.active THEN RAISE EXCEPTION 'MENU_UNAVAILABLE'; END IF;
  IF poll.menu_date <> (clock_timestamp() AT TIME ZONE 'Asia/Seoul')::date THEN
    RAISE EXCEPTION 'VOTING_CLOSED';
  END IF;
  SELECT choice INTO previous FROM meal_choices WHERE poll_id = p_id AND voter_key = p_key;
  IF previous IS DISTINCT FROM p_choice THEN
    IF p_choice IS NULL THEN
      DELETE FROM meal_choices WHERE poll_id = p_id AND voter_key = p_key;
    ELSE
      INSERT INTO meal_choices(poll_id, voter_key, choice) VALUES (p_id, p_key, p_choice)
        ON CONFLICT (poll_id, voter_key) DO UPDATE SET choice = EXCLUDED.choice;
    END IF;
    UPDATE meal_choice_polls SET
      a_votes = a_votes + COALESCE((p_choice = 'A')::int, 0) - COALESCE((previous = 'A')::int, 0),
      b_votes = b_votes + COALESCE((p_choice = 'B')::int, 0) - COALESCE((previous = 'B')::int, 0),
      version = version + 1 WHERE id = p_id RETURNING * INTO poll;
  END IF;
  RETURN jsonb_build_object('id', p_id, 'choice', p_choice,
    'aVotes', poll.a_votes, 'bVotes', poll.b_votes, 'version', poll.version);
END $$;
-- statement-breakpoint
CREATE OR REPLACE FUNCTION purge_meal_choices() RETURNS integer LANGUAGE plpgsql AS $$
DECLARE removed integer;
BEGIN
  DELETE FROM meal_choices v USING meal_choice_polls p WHERE v.poll_id = p.id
    AND p.menu_date <= (clock_timestamp() AT TIME ZONE 'Asia/Seoul')::date - 7;
  GET DIAGNOSTICS removed = ROW_COUNT;
  RETURN removed;
END $$;
COMMIT;
