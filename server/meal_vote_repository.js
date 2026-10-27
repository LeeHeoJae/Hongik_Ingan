const { neon } = require('@neondatabase/serverless');
const { voterKey } = require('./meal_vote_identity');

function createRepository(env = process.env) {
  if (!env.DATABASE_URL || !env.VOTE_HMAC_SECRET || Buffer.byteLength(env.VOTE_HMAC_SECRET) < 32) {
    throw new Error('VOTING_NOT_CONFIGURED');
  }
  const sql = neon(env.DATABASE_URL);
  return {
    async lastSync(date) {
      const rows = await sql`SELECT synced_at FROM meal_vote_days WHERE menu_date = ${date}::date`;
      return rows[0]?.synced_at;
    },
    async sync(date, meals) {
      await sql`SELECT sync_student_lunch(${date}::date, ${JSON.stringify(meals)}::jsonb)`;
    },
    async meals(date) {
      return sql`SELECT id, items, likes, dislikes, version FROM meal_menus
        WHERE menu_date = ${date}::date AND active ORDER BY id`;
    },
    async choices(meals, account) {
      if (!meals.length) return [];
      const keys = meals.map((meal) => voterKey(account, meal.id, env.VOTE_HMAC_SECRET));
      const ids = meals.map((meal) => meal.id);
      return sql`SELECT meal_id AS id, choice FROM meal_votes
        WHERE (meal_id, voter_key) IN
          (SELECT * FROM unnest(${ids}::text[], ${keys}::text[]))`;
    },
    async vote(id, account, choice) {
      const key = voterKey(account, id, env.VOTE_HMAC_SECRET);
      const rows = await sql`SELECT set_meal_vote(${id}, ${key}, ${choice}::smallint) AS result`;
      return rows[0].result;
    },
    async purge() {
      await sql`SELECT purge_meal_votes()`;
      await sql`SELECT purge_meal_choices()`;
    }
  };
}

module.exports = { createRepository };
