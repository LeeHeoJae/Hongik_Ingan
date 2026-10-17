BEGIN;

CREATE TABLE IF NOT EXISTS meal_vote_days (
  menu_date date PRIMARY KEY,
  synced_at timestamptz NOT NULL DEFAULT now()
);
-- statement-breakpoint
CREATE TABLE IF NOT EXISTS meal_menus (
  id text PRIMARY KEY CHECK (id ~ '^[a-f0-9]{64}$'),
  menu_date date NOT NULL REFERENCES meal_vote_days(menu_date),
  items jsonb NOT NULL,
  active boolean NOT NULL DEFAULT true,
  likes integer NOT NULL DEFAULT 0 CHECK (likes >= 0),
  dislikes integer NOT NULL DEFAULT 0 CHECK (dislikes >= 0),
  version integer NOT NULL DEFAULT 0
);
-- statement-breakpoint
CREATE INDEX IF NOT EXISTS meal_menus_date_idx ON meal_menus(menu_date);
-- statement-breakpoint
CREATE TABLE IF NOT EXISTS meal_votes (
  meal_id text NOT NULL REFERENCES meal_menus(id),
  voter_key text NOT NULL CHECK (voter_key ~ '^[a-f0-9]{64}$'),
  choice smallint NOT NULL CHECK (choice IN (-1, 0, 1)),
  PRIMARY KEY (meal_id, voter_key)
);
-- statement-breakpoint

-- Both sync and voting lock the day first, then the menu: consistent lock order.
CREATE OR REPLACE FUNCTION sync_student_lunch(p_date date, p_meals jsonb)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE entry jsonb;
BEGIN
  INSERT INTO meal_vote_days(menu_date) VALUES (p_date) ON CONFLICT DO NOTHING;
  PERFORM 1 FROM meal_vote_days WHERE menu_date = p_date FOR UPDATE;
  UPDATE meal_menus SET active = false WHERE menu_date = p_date;
  FOR entry IN SELECT value FROM jsonb_array_elements(p_meals) LOOP
    INSERT INTO meal_menus(id, menu_date, items)
      VALUES (entry->>'id', p_date, entry->'items')
      ON CONFLICT (id) DO UPDATE SET active = true;
  END LOOP;
  UPDATE meal_vote_days SET synced_at = clock_timestamp() WHERE menu_date = p_date;
END $$;
-- statement-breakpoint

CREATE OR REPLACE FUNCTION set_meal_vote(p_id text, p_key text, p_choice smallint)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE meal meal_menus%ROWTYPE; previous smallint := 0;
BEGIN
  IF p_choice IS NULL OR p_choice NOT IN (-1, 0, 1) THEN RAISE EXCEPTION 'INVALID_CHOICE'; END IF;
  SELECT * INTO meal FROM meal_menus WHERE id = p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'MENU_UNAVAILABLE'; END IF;
  PERFORM 1 FROM meal_vote_days WHERE menu_date = meal.menu_date FOR UPDATE;
  SELECT * INTO meal FROM meal_menus WHERE id = p_id FOR UPDATE;
  IF NOT meal.active THEN RAISE EXCEPTION 'MENU_UNAVAILABLE'; END IF;
  IF meal.menu_date <> (clock_timestamp() AT TIME ZONE 'Asia/Seoul')::date THEN
    RAISE EXCEPTION 'VOTING_CLOSED';
  END IF;
  SELECT choice INTO previous FROM meal_votes WHERE meal_id = p_id AND voter_key = p_key;
  previous := COALESCE(previous, 0);
  IF previous <> p_choice THEN
    INSERT INTO meal_votes(meal_id, voter_key, choice) VALUES (p_id, p_key, p_choice)
      ON CONFLICT (meal_id, voter_key) DO UPDATE SET choice = EXCLUDED.choice;
    UPDATE meal_menus SET
      likes = likes + (p_choice = 1)::int - (previous = 1)::int,
      dislikes = dislikes + (p_choice = -1)::int - (previous = -1)::int,
      version = version + 1
      WHERE id = p_id RETURNING * INTO meal;
  END IF;
  RETURN jsonb_build_object('id', p_id, 'choice', p_choice,
    'likes', meal.likes, 'dislikes', meal.dislikes, 'version', meal.version);
END $$;
-- statement-breakpoint

-- The daily job removes individual identifiers; aggregate counts remain intact.
CREATE OR REPLACE FUNCTION purge_meal_votes() RETURNS integer LANGUAGE plpgsql AS $$
DECLARE removed integer;
BEGIN
  DELETE FROM meal_votes v USING meal_menus m WHERE v.meal_id = m.id
    AND m.menu_date <= (clock_timestamp() AT TIME ZONE 'Asia/Seoul')::date - 7;
  GET DIAGNOSTICS removed = ROW_COUNT;
  RETURN removed;
END $$;
COMMIT;
