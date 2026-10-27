const { createHash } = require('node:crypto');

function normalizeItems(items) {
  return items.map((item) => item.normalize('NFC').replace(/\s+/gu, ' ').trim())
    .filter(Boolean);
}

function menuId(date, items) {
  return createHash('sha256').update(JSON.stringify([date, normalizeItems(items)])).digest('hex');
}

function campusDay(now = new Date()) {
  return new Date(now.getTime() + 9 * 3600000).toISOString().slice(0, 10);
}

function validDate(date, now = new Date()) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date || '')) return false;
  const parsed = new Date(`${date}T00:00:00Z`);
  return Number.isFinite(parsed.getTime()) && parsed.toISOString().slice(0, 10) === date &&
    Math.abs(parsed - new Date(`${campusDay(now)}T00:00:00Z`)) <= 7 * 86400000;
}

module.exports = { normalizeItems, menuId, campusDay, validDate };
