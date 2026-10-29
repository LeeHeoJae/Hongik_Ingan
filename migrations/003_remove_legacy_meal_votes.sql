BEGIN;

-- Apply manually only after deploying the server that no longer uses these tables.
-- This permanently deletes the old rating data and does not touch A/B choices.
-- With the intended database configured: node scripts/remove-legacy-meal-votes.js
DROP FUNCTION IF EXISTS public.sync_student_lunch(date, jsonb);
DROP FUNCTION IF EXISTS public.set_meal_vote(text, text, smallint);
DROP FUNCTION IF EXISTS public.purge_meal_votes();
DROP TABLE IF EXISTS public.meal_votes;
DROP TABLE IF EXISTS public.meal_menus;
DROP TABLE IF EXISTS public.meal_vote_days;

COMMIT;
