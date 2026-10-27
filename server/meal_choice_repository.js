const { neon } = require('@neondatabase/serverless');

function createRepository(env = process.env) {
  if (!env.DATABASE_URL) {
    throw new Error('VOTING_NOT_CONFIGURED');
  }
  const sql = neon(env.DATABASE_URL);
  return {
    async lastSync(date) {
      const rows = await sql`SELECT synced_at FROM meal_choice_days WHERE menu_date = ${date}::date`;
      return rows[0]?.synced_at;
    },
    async sync(date, poll) {
      await sql`SELECT sync_lunch_poll(${date}::date, ${JSON.stringify(poll)}::jsonb)`;
    },
    async poll(date) {
      const rows = await sql`SELECT id, options, a_votes AS "aVotes", b_votes AS "bVotes", version
        FROM meal_choice_polls WHERE menu_date = ${date}::date AND active`;
      return rows[0] || null;
    },
    async choice(id, key) {
      const rows = await sql`SELECT choice FROM meal_choices WHERE poll_id = ${id} AND voter_key = ${key}`;
      return rows[0]?.choice || null;
    },
    async vote(id, key, choice) {
      const rows = await sql`SELECT set_lunch_choice(${id}, ${key}, ${choice}::text) AS result`;
      return rows[0].result;
    },
    async purge() { await sql`SELECT purge_meal_choices()`; }
  };
}
module.exports = { createRepository };
