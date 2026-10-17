const fs = require('node:fs');
const { neon } = require('@neondatabase/serverless');

async function migrate() {
  if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required');
  const sql = neon(process.env.DATABASE_URL);
  // A single migration transaction; never print credentials or driver errors.
  const source = fs.readFileSync('migrations/001_meal_votes.sql', 'utf8')
    .replace(/^BEGIN;\s*/, '').replace(/COMMIT;\s*$/, '');
  await sql.transaction(source.split('-- statement-breakpoint')
    .map((statement) => sql.query(statement.trim())));
  console.log('Meal vote schema applied.');
}
migrate().catch(() => {
  console.error('Meal vote migration failed. Check DATABASE_URL and database access.');
  process.exitCode = 1;
});
