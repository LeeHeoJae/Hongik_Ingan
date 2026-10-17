const { load } = require('cheerio');
const { normalizeItems, menuId } = require('./meal_vote_identity');

const noMenu = new Set([
  '등록된 식단이 없습니다.', '운영X', '신정', '설날', '삼일절', '3.1절',
  '어린이날', '부처님오신날', '현충일', '제헌절', '광복절', '추석',
  '개천절', '한글날', '성탄절', '크리스마스', '대체공휴일', '임시공휴일', '휴무', '공휴일'
]);

function parseStudentLunch(feed, date) {
  if (feed === null || (typeof feed === 'object' && !Array.isArray(feed) && Object.keys(feed).length === 0)) {
    return [];
  }
  if (feed?.result !== 'Y' || !Array.isArray(feed.RESTDATA)) throw new Error('INVALID_FEED');
  const result = [];
  for (const row of feed.RESTDATA) {
    if (row.REST_NO !== '3' || !['1', '2'].includes(row.PRICELEVEL) || row.MENU_DATE !== date.replaceAll('-', '')) continue;
    if (typeof row.MENU !== 'string') throw new Error('INVALID_FEED');
    const html = decodeURIComponent(row.MENU).replace(/<br\s*\/?>/gi, '\n');
    const $ = load(html, {}, false);
    const items = normalizeItems($.root().text().split(/\r?\n/)).filter((item) => !noMenu.has(item));
    if (items.length) result.push({ id: menuId(date, items), items });
  }
  return [...new Map(result.map((meal) => [meal.id, meal])).values()];
}

async function fetchStudentLunch(date, fetcher = fetch) {
  const [year, month, day] = date.split('-').map(Number);
  const url = new URL('https://www.hongik.ac.kr/sso/APICipher2.jsp');
  url.searchParams.set('data', JSON.stringify({
    url: '/homepage/get_food_list.php',
    url2: `&CAMPUS=0&YEAR=${year}&MONTH=${month}&DAY=`,
    url3: String(day)
  }));
  const response = await fetcher(url, { signal: AbortSignal.timeout(8000) });
  if (!response.ok) throw new Error('FEED_UNAVAILABLE');
  return parseStudentLunch(await response.json(), date);
}

module.exports = { parseStudentLunch, fetchStudentLunch };
