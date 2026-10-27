const { neon } = require('@neondatabase/serverless');

function createRepository(env = process.env) {
  if (!env.DATABASE_URL) {
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
    async purge() {
      await sql`SELECT purge_meal_votes()`;
      await sql`SELECT purge_meal_choices()`;
    }
  };
}

module.exports = { createRepository };
