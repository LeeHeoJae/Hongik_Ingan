const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { PGlite } = require('@electric-sql/pglite');
const { parseLunchPoll } = require('../server/meal_choice_feed');
const { createHandler } = require('../server/meal_choice_handler');
const { campusDay, voterKey } = require('../server/meal_vote_identity');

const date = '2026-10-26';
function feed(items = ['밥<br>국', '면<br>김치']) {
  return { result: 'Y', RESTDATA: items.map((menu, i) => ({ REST_NO: '3',
    PRICELEVEL: String(i + 1), MENU_DATE: date.replaceAll('-', ''), MENU: encodeURIComponent(menu) })) };
}
const poll = parseLunchPoll(feed(), date);

test('stable A/B slots survive feed reordering and identical menus', () => {
  const reversed = feed();
  reversed.RESTDATA.reverse();
  assert.deepEqual(parseLunchPoll(reversed, date), poll);
  const same = parseLunchPoll(feed(['밥', '밥']), date);
  assert.equal(same.options.length, 2);
  assert.deepEqual(same.options.map((o) => o.option), ['A', 'B']);
  assert.equal(parseLunchPoll(feed(['밥']), date), null);
  assert.equal(parseLunchPoll({}, date), null);
  assert.equal(parseLunchPoll(feed(['밥', '운영X']), date), null);
  assert.throws(() => parseLunchPoll({ result: 'N' }, date), /INVALID_FEED/);
  const duplicate = feed();
  duplicate.RESTDATA.push({ ...duplicate.RESTDATA[0], MENU: encodeURIComponent('다른 메뉴') });
  assert.throws(() => parseLunchPoll(duplicate, date), /INVALID_FEED/);
  assert.notEqual(parseLunchPoll(feed(['새 메뉴', '면']), date).id, poll.id);
});

test('SQL enforces one choice per poll with atomic switch, retries, cancel and retention', async () => {
  const db = new PGlite();
  try {
    for (const name of ['001_meal_votes.sql', '002_meal_choices.sql', '002_meal_choices.sql']) {
      await db.exec(fs.readFileSync(`migrations/${name}`, 'utf8'));
    }
    const today = campusDay();
    const sync = (value) => db.query('SELECT sync_lunch_poll($1::date, $2::jsonb)', [today, JSON.stringify(value)]);
    await sync(poll);
    const key = voterKey('A123456', poll.id, 's'.repeat(32));
    const vote = async (choice, voter = key, id = poll.id) => (await db.query(
      'SELECT set_lunch_choice($1, $2, $3::text) AS result', [id, voter, choice])).rows[0].result;
    assert.deepEqual(await vote('A'), { id: poll.id, choice: 'A', aVotes: 1, bVotes: 0, version: 1 });
    assert.equal((await vote('A')).version, 1);
    assert.deepEqual(await vote('B'), { id: poll.id, choice: 'B', aVotes: 0, bVotes: 1, version: 2 });
    await Promise.all(Array.from({ length: 10 }, () => vote('B')));
    assert.equal((await db.query('SELECT count(*)::int AS n FROM meal_choices')).rows[0].n, 1);
    assert.equal((await vote(null)).bVotes, 0);
    assert.equal((await vote(null)).version, 3);
    await assert.rejects(vote('C'), /INVALID_CHOICE/);
    await Promise.all(Array.from({ length: 20 }, (_, i) => vote(i % 2 ? 'A' : 'B',
      voterKey(`A${String(i).padStart(6, '0')}`, poll.id, 's'.repeat(32)))));
    const totals = (await db.query('SELECT a_votes, b_votes FROM meal_choice_polls WHERE active')).rows[0];
    assert.deepEqual(totals, { a_votes: 10, b_votes: 10 });
    const replacement = { ...poll, id: 'b'.repeat(64) };
    await sync(replacement);
    await assert.rejects(vote('A'), /MENU_UNAVAILABLE/);
    assert.equal((await vote('B', key, replacement.id)).aVotes, 0);
    assert.equal((await db.query('SELECT count(*)::int AS n FROM meal_choice_polls WHERE active')).rows[0].n, 1);
    await sync(null);
    await assert.rejects(vote('A', key, replacement.id), /MENU_UNAVAILABLE/);
    await sync(replacement);
    await db.exec('INSERT INTO meal_choice_days(menu_date) VALUES ((clock_timestamp() AT TIME ZONE \'Asia/Seoul\')::date + 1) ON CONFLICT DO NOTHING');
    await db.query("UPDATE meal_choice_polls SET menu_date = (clock_timestamp() AT TIME ZONE 'Asia/Seoul')::date + 1 WHERE id = $1", [replacement.id]);
    assert.equal((await vote('A', key, replacement.id)).choice, 'A');
    assert.equal((await vote(null, key, replacement.id)).choice, null);
    await vote('B', key, replacement.id);
    await db.exec(`INSERT INTO meal_choice_days(menu_date) VALUES (CURRENT_DATE - 20);
      UPDATE meal_choice_polls SET menu_date = CURRENT_DATE - 20;
      UPDATE meal_choice_polls SET active = false WHERE id <> '${replacement.id}';`);
    await assert.rejects(vote('A', key, replacement.id), /VOTING_CLOSED/);
    await db.exec('SELECT purge_meal_choices()');
    assert.equal((await db.query('SELECT count(*)::int AS n FROM meal_choices')).rows[0].n, 0);
    assert.equal((await db.query('SELECT b_votes FROM meal_choice_polls WHERE active')).rows[0].b_votes, 1);
  } finally { await db.close(); }
});

function repository() {
  return { lastSync: async () => `${date}T01:00:00Z`, sync: async () => {}, purge: async () => {},
    poll: async () => ({ ...poll, aVotes: 12, bVotes: 8, version: 20 }),
    choice: async () => 'A',
    vote: async (id, account, choice) => ({ id, choice, aVotes: 11, bVotes: 9, version: 21 }) };
}
async function request({ method = 'GET', mine = false, body, account, repo = repository(),
  now = `${date}T01:01:00Z`, contentType = 'application/json', fetchPoll = async () => poll } = {}) {
  const res = { headers: {}, setHeader(k, v) { this.headers[k] = v; }, end(v) { this.body = JSON.parse(v); } };
  await createHandler({ repository: repo, fetchPoll, clock: () => new Date(now) })({
    method, url: `/api/meal-choice?date=${date}${mine ? '&mine=1' : ''}`,
    body, headers: { 'x-vote-account': account, 'content-type': contentType }
  }, res);
  return res;
}

test('public poll excludes identity; personal choice and writes are never cached', async () => {
  const publicResponse = await request({ account: 'A123456' });
  assert.equal(publicResponse.statusCode, 200);
  assert.match(publicResponse.headers['Vercel-CDN-Cache-Control'], /s-maxage=30/);
  assert.equal(JSON.stringify(publicResponse.body).includes('choice'), false);
  const privateResponse = await request({ mine: true, account: 'A123456' });
  assert.deepEqual(privateResponse.body, { id: poll.id, choice: 'A' });
  assert.equal(privateResponse.headers['Cache-Control'], 'private, no-store');
  const saved = await request({ method: 'PUT', account: 'A123456', body: { date, id: poll.id, choice: 'B' } });
  assert.equal(saved.statusCode, 200);
  assert.equal(saved.headers['Vercel-CDN-Cache-Control'], 'no-store');
  assert.equal(JSON.stringify(saved).includes('A123456'), false);
  assert.equal((await request({ method: 'PUT', account: 'A123456', body: { date, id: poll.id, choice: null } })).statusCode, 200);
  const future = await request({ method: 'PUT', account: 'A123456', now: '2026-10-25T01:01:00Z', body: { date, id: poll.id, choice: 'A' } });
  assert.equal(future.statusCode, 200);
});

test('reject unauthenticated, malformed, stale menu and closed-day writes', async () => {
  assert.equal((await request({ mine: true })).statusCode, 401);
  assert.equal((await request({ method: 'PUT', body: { date, id: poll.id, choice: 'A' } })).statusCode, 401);
  for (const choice of [undefined, -1, 1, 'C']) {
    const res = await request({ method: 'PUT', account: 'A123456', body: { date, id: poll.id, choice } });
    assert.equal(res.statusCode, 400);
  }
  const mismatch = await request({ method: 'PUT', account: 'A123456', body: { date, id: 'c'.repeat(64), choice: 'A' } });
  assert.equal(mismatch.body.error, 'MENU_UNAVAILABLE');
  const closed = await request({ method: 'PUT', account: 'A123456', now: '2026-10-26T15:00:00Z', body: { date, id: poll.id, choice: 'A' } });
  assert.equal(closed.body.error, 'VOTING_CLOSED');
  assert.equal((await request({ method: 'POST' })).statusCode, 405);
  assert.equal((await request({ method: 'PUT', account: 'A123456', body: '{' })).statusCode, 400);
  assert.equal((await request({ method: 'PUT', account: 'A123456', body: 'a'.repeat(2049) })).statusCode, 400);
});

test('missing pair syncs to no poll; failed feed does not erase existing menus', async () => {
  let synced;
  const repo = { ...repository(), lastSync: async () => null,
    sync: async (date, value) => { synced = value; }, poll: async () => synced };
  const response = await request({ repo, fetchPoll: async () => null });
  assert.equal(response.statusCode, 200);
  assert.equal(response.body.poll, null);
  synced = 'unchanged';
  const failed = await request({ repo, fetchPoll: async () => { throw new Error('secret database failure'); } });
  assert.equal(failed.statusCode, 503);
  assert.equal(synced, 'unchanged');
  assert.equal(failed.headers['Vercel-CDN-Cache-Control'], 'no-store');
  assert.equal(JSON.stringify(failed).includes('secret'), false);
});
