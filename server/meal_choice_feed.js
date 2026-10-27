const { createHash } = require('node:crypto');
const { parseStudentLunch } = require('./meal_vote_feed');

// The source's student lunch slots are PRICELEVEL 1 (A) and 2 (B).
function parseLunchPoll(feed, date) {
  // Validate empty/invalid feeds with the same rules as the menu feed.
  parseStudentLunch(feed, date);
  const slots = new Map();
  for (const row of feed?.RESTDATA || []) {
    const menu = parseStudentLunch({ result: 'Y', RESTDATA: [row] }, date)[0];
    if (!menu) continue;
    const option = row.PRICELEVEL === '1' ? 'A' : 'B';
    const existing = slots.get(option);
    if (existing && JSON.stringify(existing.items) !== JSON.stringify(menu.items)) throw new Error('INVALID_FEED');
    slots.set(option, { option, items: menu.items });
  }
  if (slots.size !== 2) return null;
  const options = ['A', 'B'].map((option) => slots.get(option));
  const id = createHash('sha256').update(JSON.stringify(['student-lunch-choice-v1', date, options])).digest('hex');
  return { id, options };
}

async function fetchLunchPoll(date, fetcher = fetch) {
  const [year, month, day] = date.split('-').map(Number);
  const url = new URL('https://www.hongik.ac.kr/sso/APICipher2.jsp');
  url.searchParams.set('data', JSON.stringify({ url: '/homepage/get_food_list.php',
    url2: `&CAMPUS=0&YEAR=${year}&MONTH=${month}&DAY=`, url3: String(day) }));
  const response = await fetcher(url, { signal: AbortSignal.timeout(8000) });
  if (!response.ok) throw new Error('FEED_UNAVAILABLE');
  return parseLunchPoll(await response.json(), date);
}

module.exports = { parseLunchPoll, fetchLunchPoll };
