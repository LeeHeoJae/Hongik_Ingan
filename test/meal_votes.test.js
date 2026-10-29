const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { PGlite } = require('@electric-sql/pglite');
const { createHandler } = require('../server/meal_vote_handler');
const { parseStudentLunch } = require('../server/meal_vote_feed');

async function request(kind, { method = 'GET', authorization, secret = 's'.repeat(32), repository } = {}) {
  const res = { headers: {}, setHeader(key, value) { this.headers[key] = value; },
    end(value) { this.body = JSON.parse(value); } };
  await createHandler({ repository, env: { CRON_SECRET: secret } })(kind,
    { method, headers: { authorization } }, res);
  return res;
}

test('retired endpoints return an uncached replacement response', async () => {
  for (const kind of ['meals', 'vote-totals', 'my-votes', 'vote']) {
    const response = await request(kind);
    assert.equal(response.statusCode, 410);
    assert.equal(response.body.error, 'VOTING_REPLACED');
    assert.equal(response.headers['Cache-Control'], 'private, no-store');
    assert.equal(response.headers['Vercel-CDN-Cache-Control'], 'no-store');
  }
});

test('cleanup requires authorization and purges only A/B choices', async () => {
  let purges = 0;
  const repository = { purge: async () => { purges++; } };
  assert.equal((await request('vote-cleanup', { repository })).statusCode, 401);
  assert.equal((await request('vote-cleanup', { repository, authorization: 'Bearer wrong' })).statusCode, 401);
  assert.equal((await request('vote-cleanup', { repository, method: 'POST' })).statusCode, 405);
  const result = await request('vote-cleanup', { repository, authorization: `Bearer ${'s'.repeat(32)}` });
  assert.equal(result.statusCode, 200);
  assert.equal(purges, 1);
  const failed = await request('vote-cleanup', { repository: { purge: async () => { throw new Error('secret'); } },
    authorization: `Bearer ${'s'.repeat(32)}` });
  assert.equal(failed.statusCode, 503);
  assert.equal(JSON.stringify(failed).includes('secret'), false);
});

test('shared lunch parser keeps only student lunch menus', () => {
  const date = '2026-10-15';
  const row = (restaurant, level, menu) => ({ REST_NO: restaurant, PRICELEVEL: level,
    MENU_DATE: '20261015', MENU: encodeURIComponent(menu) });
  const meals = parseStudentLunch({ result: 'Y', RESTDATA: [
    row('2', '1', '교직원 메뉴'), row('3', '0', '조식'), row('3', '3', '석식'),
    row('3', '1', '밥<br>국&amp;소스'), row('3', '2', '면\r\n김치')
  ] }, date);
  assert.equal(meals.length, 2);
  assert.deepEqual(meals[0].items, ['밥', '국&소스']);
  assert.deepEqual(parseStudentLunch({ result: 'Y', RESTDATA: [row('3', '1', '한글날<br>운영X')] }, date), []);
  assert.throws(() => parseStudentLunch({ result: 'N' }, date), /INVALID_FEED/);
});

test('legacy removal preserves A/B data and is repeatable on existing and fresh schemas', async () => {
  const db = new PGlite();
  try {
    for (const file of ['001_meal_votes.sql', '002_meal_choices.sql']) {
      await db.exec(fs.readFileSync(`migrations/${file}`, 'utf8'));
    }
    await db.query('SELECT sync_student_lunch($1::date, $2::jsonb)',
      ['2099-10-29', JSON.stringify([{ id: 'b'.repeat(64), items: ['rice'] }])]);
    await db.query('INSERT INTO meal_votes(meal_id, voter_key, choice) VALUES ($1, $2, 1)',
      ['b'.repeat(64), 'c'.repeat(64)]);
    await db.query('SELECT sync_lunch_poll($1::date, $2::jsonb)',
      ['2099-10-29', JSON.stringify({ id: 'a'.repeat(64), options: [] })]);
    await db.query('SELECT set_lunch_choice($1, $2, $3)', ['a'.repeat(64), 'c'.repeat(64), 'A']);
    const migration = fs.readFileSync('migrations/003_remove_legacy_meal_votes.sql', 'utf8');
    await db.exec(migration);
    await db.exec(migration);
    const tables = await db.query("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name");
    assert.deepEqual(tables.rows.map((row) => row.table_name), ['meal_choice_days', 'meal_choice_polls', 'meal_choices']);
    assert.equal((await db.query('SELECT count(*)::int AS n FROM meal_choice_polls')).rows[0].n, 1);
    assert.equal((await db.query('SELECT count(*)::int AS n FROM meal_choices')).rows[0].n, 1);
    assert.equal((await db.query('SELECT a_votes FROM meal_choice_polls')).rows[0].a_votes, 1);
    assert.equal((await db.query("SELECT count(*)::int AS n FROM pg_proc WHERE proname IN ('sync_student_lunch', 'set_meal_vote', 'purge_meal_votes')")).rows[0].n, 0);
    await db.exec(fs.readFileSync('migrations/002_meal_choices.sql', 'utf8'));
    assert.equal((await db.query('SELECT count(*)::int AS n FROM meal_choice_polls')).rows[0].n, 1);
  } finally { await db.close(); }
});
