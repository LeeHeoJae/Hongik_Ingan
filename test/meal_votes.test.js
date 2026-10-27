const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { PGlite } = require('@electric-sql/pglite');
const { menuId, voterKey, campusDay, validDate } = require('../server/meal_vote_identity');
const { parseStudentLunch } = require('../server/meal_vote_feed');
const { createHandler } = require('../server/meal_vote_handler');
const { readVoteAccount } = require('../server/meal_vote_auth');

const token = 'A123456', secret = 's'.repeat(32);
const date = '2026-10-15', id = menuId(date, ['밥', '국']);

test('identity separates menus and days without storing the student ID', () => {
  assert.equal(menuId(date, [' 밥 ', '국\u00a0']), id);
  assert.notEqual(menuId('2026-10-16', ['밥', '국']), id);
  assert.notEqual(menuId(date, ['밥', '찌개']), id);
  assert.notEqual(voterKey(token, id, secret), token);
  assert.notEqual(voterKey(token, id, secret), voterKey(token, 'b'.repeat(64), secret));
  assert.equal(voterKey(' a123456 ', id, secret), voterKey(token, id, secret));
  assert.throws(() => voterKey('invalid', id, secret), /AUTHENTICATION_REQUIRED/);
  assert.throws(() => voterKey(token, id, 'short'), /NOT_CONFIGURED/);
  assert.equal(campusDay(new Date('2026-10-15T15:00:00Z')), '2026-10-16');
  assert.equal(validDate('2026-02-30'), false);
});

test('school feed registers only student lunch and keeps choices separate', () => {
  const row = (restaurant, level, menu) => ({ REST_NO: restaurant,
    PRICELEVEL: level, MENU_DATE: '20261015', MENU: encodeURIComponent(menu) });
  const meals = parseStudentLunch({ result: 'Y', RESTDATA: [
    row('2', '0', '교직원 메뉴'), row('3', '0', '조식'), row('3', '3', '석식'),
    row('3', '1', '밥<br>국&amp;소스'), row('3', '2', '면\r\n김치')
  ] }, date);
  assert.equal(meals.length, 2);
  assert.deepEqual(meals[0].items, ['밥', '국&소스']);
  assert.notEqual(meals[0].id, meals[1].id);
  assert.deepEqual(parseStudentLunch({ result: 'Y', RESTDATA: [row('3', '1', '한글날<br>운영X')] }, date), []);
  assert.throws(() => parseStudentLunch({ result: 'N' }, date), /INVALID_FEED/);
});

test('Postgres transaction handles retry, change, cancel, concurrent clients and retention', async () => {
  const db = new PGlite();
  try {
    await db.exec(fs.readFileSync('migrations/001_meal_votes.sql', 'utf8'));
    const today = campusDay();
    const mealId = menuId(today, ['밥']);
    await db.query('SELECT sync_student_lunch($1::date, $2::jsonb)',
      [today, JSON.stringify([{ id: mealId, items: ['밥'] }])]);
    const vote = async (key, choice) => (await db.query(
      'SELECT set_meal_vote($1, $2, $3::smallint) AS result', [mealId, key, choice])).rows[0].result;
    const key = voterKey(token, mealId, secret);
    assert.equal((await vote(key, 1)).likes, 1);
    assert.equal((await vote(key, 1)).version, 1);
    assert.deepEqual(await vote(key, -1), { id: mealId, choice: -1, likes: 0, dislikes: 1, version: 2 });
    assert.equal((await vote(key, 0)).dislikes, 0);
    assert.equal((await vote(key, 0)).version, 3);
    await Promise.all(Array.from({ length: 10 }, () => vote(key, 1)));
    assert.equal((await db.query('SELECT likes FROM meal_menus')).rows[0].likes, 1);
    assert.equal((await db.query('SELECT count(*)::int AS count FROM meal_votes')).rows[0].count, 1);
    await vote(key, 0);
    await Promise.all(Array.from({ length: 20 }, (_, index) =>
      vote(voterKey(`A${String(index).padStart(6, '0')}`, mealId, secret), 1)));
    assert.equal((await db.query('SELECT likes FROM meal_menus')).rows[0].likes, 20);
    await db.query('SELECT sync_student_lunch($1::date, $2::jsonb)', [today, '[]']);
    await assert.rejects(vote(key, 1), /MENU_UNAVAILABLE/);
    await db.query('SELECT sync_student_lunch($1::date, $2::jsonb)',
      [today, JSON.stringify([{ id: mealId, items: ['밥'] }])]);
    assert.equal((await db.query('SELECT likes FROM meal_menus')).rows[0].likes, 20);
    await db.exec(`INSERT INTO meal_vote_days(menu_date) VALUES (CURRENT_DATE - 20);
      UPDATE meal_menus SET menu_date = CURRENT_DATE - 20;`);
    await assert.rejects(vote(key, 1), /VOTING_CLOSED/);
    await db.exec('SELECT purge_meal_votes()');
    assert.equal((await db.query('SELECT count(*)::int AS count FROM meal_votes')).rows[0].count, 0);
    assert.equal((await db.query('SELECT likes FROM meal_menus')).rows[0].likes, 20);
  } finally { await db.close(); }
});

function mockRepository() {
  return {
    lastSync: async () => '2026-10-15T02:00:00Z',
    sync: async () => {}, purge: async () => {},
    meals: async () => [{ id, items: ['밥', '국'], likes: 5, dislikes: 2, version: 7 }],
    choices: async () => [{ id, choice: 1 }],
    vote: async () => ({ id, choice: 1, likes: 6, dislikes: 2, version: 8 })
  };
}
async function request(kind, { method = 'GET', body, headers = {}, repository = mockRepository(), env = {} } = {}) {
  const handle = createHandler({ repository, clock: () => new Date('2026-10-15T02:01:00Z'), env });
  const res = { headers: {}, setHeader(key, value) { this.headers[key] = value; },
    end(value) { this.body = JSON.parse(value); } };
  await handle(kind, { method, url: `/api/${kind}?date=${date}`, body, headers }, res);
  return res;
}

test('public totals share a short cache and exclude identities and selections', async () => {
  const response = await request('vote-totals', { headers: {
    'x-vote-account': token
  } });
  assert.equal(response.statusCode, 200);
  assert.equal(response.headers['Vercel-CDN-Cache-Control'], 'public, s-maxage=30, stale-while-revalidate=30');
  assert.deepEqual(Object.keys(response.body.meals[0]), ['id', 'likes', 'dislikes', 'version']);
  assert.equal(JSON.stringify(response).includes(token), false);
});

test('private responses, errors and cleanup never enter the CDN', async () => {
  const own = await request('my-votes', { headers: { 'x-vote-account': token } });
  assert.equal(own.headers['Cache-Control'], 'private, no-store');
  const saved = await request('vote', { method: 'PUT', body: { date, id, choice: 1 },
    headers: { 'content-type': 'application/json', 'x-vote-account': token } });
  assert.equal(saved.statusCode, 409);
  assert.equal(saved.body.error, 'VOTING_REPLACED');
  assert.equal(saved.headers['Vercel-CDN-Cache-Control'], 'no-store');
  const invalid = await request('vote', { method: 'PUT', body: { date, id, choice: 2 },
    headers: { 'content-type': 'application/json', 'x-vote-account': token } });
  assert.equal(invalid.statusCode, 409);
  assert.equal((await request('vote-cleanup')).statusCode, 401);
  assert.equal((await request('vote-cleanup', { env: { CRON_SECRET: secret },
    headers: { authorization: `Bearer ${secret}` } })).statusCode, 200);
  const failed = await request('vote-totals', { repository: {
    lastSync: async () => '2026-10-15T02:00:00Z',
    meals: async () => { throw new Error(`database failure ${token}`); }
  } });
  assert.equal(failed.statusCode, 503);
  assert.equal(failed.headers['Vercel-CDN-Cache-Control'], 'no-store');
  assert.equal(JSON.stringify(failed).includes(token), false);
});

test('app-supplied account is used without school session verification', async () => {
  assert.equal(readVoteAccount({ headers: { 'x-vote-account': ' a123456 ' } }), token);
  for (const account of [undefined, '', 'invalid', ['A123456'], 'A123456\\r\\nCookie: forged']) {
    assert.throws(() => readVoteAccount({ headers: { 'x-vote-account': account } }), /AUTHENTICATION_REQUIRED/);
  }
  let queriedAccount, votedAccount;
  const repository = { ...mockRepository(),
    choices: async (meals, account) => { queriedAccount = account; return []; },
    vote: async (meal, account, choice) => { votedAccount = account; return { id: meal, choice, likes: 1, dislikes: 0, version: 1 }; }
  };
  const own = await request('my-votes', { repository, headers: { 'x-vote-account': ' b123456 ' } });
  assert.equal(own.statusCode, 200);
  assert.equal(queriedAccount, 'B123456');
  const saved = await request('vote', { repository, method: 'PUT', body: { date, id, choice: 1 },
    headers: { 'content-type': 'application/json', 'x-vote-account': ' b123456 ' } });
  assert.equal(saved.statusCode, 409);
  assert.equal(votedAccount, undefined);
  assert.equal(JSON.stringify(saved).includes('B123456'), false);
});

test('legacy anonymous tokens and requests without an account cannot submit or read selections', async () => {
  const privateRead = await request('my-votes', { headers: { 'x-vote-token': 'a'.repeat(64) } });
  assert.equal(privateRead.statusCode, 401);
  assert.equal(privateRead.headers['Vercel-CDN-Cache-Control'], 'no-store');
  const write = await request('vote', { method: 'PUT', body: { date, id, choice: 1 },
    headers: { 'content-type': 'application/json', 'x-vote-token': 'a'.repeat(64) } });
  assert.equal(write.statusCode, 401);
});
