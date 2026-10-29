const fs = require('node:fs');
const { neon } = require('@neondatabase/serverless');

async function removeLegacy() {
  if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required');
  const sql = neon(process.env.DATABASE_URL);
  const source = fs.readFileSync('migrations/003_remove_legacy_meal_votes.sql', 'utf8')
    .replace(/^BEGIN;\s*/, '').replace(/COMMIT;\s*$/, '');
  await sql.transaction(source.split(';').map((statement) => statement.trim())
    .filter(Boolean).map((statement) => sql.query(statement)));
  console.log('Legacy meal vote schema removed.');
}

removeLegacy().catch(() => {
  console.error('Legacy meal vote removal failed. Check DATABASE_URL and database access.');
  process.exitCode = 1;
});
