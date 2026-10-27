const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const test = require('node:test');

const bash = process.platform === 'win32'
  ? 'C:/Program Files/Git/bin/bash.exe'
  : '/bin/bash';

function build(environment, migrationStatus = 0) {
  // Mock external commands: exercise the real build script without a DB or SDK.
  return spawnSync(bash, ['-c', `
    npm() { echo "npm $*"; return "$MIGRATION_STATUS"; }
    flutter() { echo "flutter $*"; }
    node() { echo "node $*"; }
    source scripts/vercel-build.sh
  `], {
    encoding: 'utf8',
    env: {
      ...process.env,
      VERCEL_ENV: environment,
      MIGRATION_STATUS: String(migrationStatus),
    },
  });
}

test('Preview migrates before building against the injected database', () => {
  const result = build('preview');
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stderr);
  assert.ok(result.stdout.startsWith('npm run db:migrate:votes\n'));
  assert.match(result.stdout, /flutter build web --debug/);
});

test('failed Preview migration prevents the Flutter build', () => {
  const result = build('preview', 1);
  assert.ifError(result.error);
  assert.equal(result.status, 1, result.stderr);
  assert.doesNotMatch(result.stdout, /flutter /);
});

for (const environment of ['production', 'development']) {
  test(`${environment} build does not run database migrations`, () => {
    const result = build(environment);
    assert.ifError(result.error);
    assert.equal(result.status, 0, result.stderr);
    assert.doesNotMatch(result.stdout, /npm /);
    assert.match(result.stdout, /flutter build web --release/);
  });
}
