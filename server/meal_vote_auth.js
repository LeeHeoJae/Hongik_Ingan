function normalizeStudentId(value) {
  const id = typeof value === 'string' ? value.trim().toUpperCase() : '';
  if (!/^[A-Z0-9]{6,12}$/.test(id) || !/[0-9]/.test(id)) throw new Error('AUTHENTICATION_REQUIRED');
  return id;
}

function readVoteAccount(req) {
  // Trust the app-supplied account; this does not verify school identity.
  return normalizeStudentId(req.headers['x-vote-account']);
}

module.exports = { normalizeStudentId, readVoteAccount };
