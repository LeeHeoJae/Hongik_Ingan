const { timingSafeEqual } = require('node:crypto');

function createHandler({ repository, env = process.env } = {}) {
  return async function handle(kind, req, res) {
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.setHeader('Cache-Control', 'private, no-store');
    res.setHeader('Vercel-CDN-Cache-Control', 'no-store');
    const send = (status, data) => {
      res.statusCode = status;
      res.end(JSON.stringify(data));
    };

    if (kind !== 'vote-cleanup') return send(410, { error: 'VOTING_REPLACED' });
    if (req.method !== 'GET') return send(405, { error: 'METHOD_NOT_ALLOWED' });
    const actual = Buffer.from(req.headers.authorization || '');
    const expected = Buffer.from(env.CRON_SECRET ? `Bearer ${env.CRON_SECRET}` : '');
    if (!actual.length || !expected.length || actual.length !== expected.length || !timingSafeEqual(actual, expected)) {
      return send(401, { error: 'UNAUTHORIZED' });
    }
    try {
      const repo = repository || require('./meal_choice_repository').createRepository(env);
      await repo.purge();
      return send(200, { ok: true });
    } catch (_) {
      return send(503, { error: 'VOTING_UNAVAILABLE' });
    }
  };
}

module.exports = { createHandler };
