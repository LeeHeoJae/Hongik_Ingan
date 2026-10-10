const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync('server/server.js', 'utf8');
const webDir = path.resolve('build/web');

function server({ statError, readError, missingIndex = false, vanishedAsset = false } = {}) {
  const files = new Map([
    ['main.dart.js', 'script'],
    ['image.png', 'image'],
    ['folder/index.html', 'folder'],
  ].map(([name, body]) => [path.join(webDir, name), Buffer.from(body)]));
  if (!missingIndex) files.set(path.join(webDir, 'index.html'), Buffer.from('index'));
  const directories = new Set([webDir, path.join(webDir, 'folder'), path.join(webDir, 'empty')]);
  const error = (code) => Object.assign(new Error('File unavailable'), { code });
  let route;
  let proxyCalls = 0;
  const context = {
    URL,
    __dirname: path.resolve('server'),
    process: { env: {} },
    console: { log() {} },
    require(name) {
      if (name === 'path') return path;
      if (name === '../api/proxy') return () => proxyCalls++;
      if (name === 'http') return {
        createServer(handler) {
          route = handler;
          return { listen() {} };
        },
      };
      if (name === 'fs/promises') return {
        async stat(file) {
          if (statError) throw error(statError);
          if (!files.has(file) && !directories.has(file)) throw error('ENOENT');
          return { isDirectory: () => directories.has(file) };
        },
        async readFile(file) {
          if (readError) throw error(readError);
          if (vanishedAsset && file === path.join(webDir, 'main.dart.js')) throw error('ENOENT');
          if (!files.has(file)) throw error('ENOENT');
          return files.get(file);
        },
      };
      throw new Error(`Unexpected dependency: ${name}`);
    },
  };
  vm.runInNewContext(source, context);
  return {
    get proxyCalls() { return proxyCalls; },
    proxy() { route({ url: '/api/proxy?url=target' }, {}); },
    async request(url) {
      const headers = {};
      let body;
      const response = {
        statusCode: 200,
        setHeader: (name, value) => headers[name] = value,
        end: (value) => body = value.toString(),
      };
      await context.serveStatic({ url }, response);
      return { status: response.statusCode, headers, body };
    },
  };
}

test('malformed paths return 400 and later valid requests still succeed', async () => {
  const subject = server();
  for (const url of ['/%', '/%E0%A4%A', '/%00']) {
    assert.equal((await subject.request(url)).status, 400);
  }
  assert.equal((await subject.request('/')).body, 'index');
});

test('encoded traversal cannot reach outside the web directory', async () => {
  assert.equal((await server().request('/..%2f..%2fsecret')).status, 403);
});

test('static content retains its type, cache and isolation headers', async () => {
  const subject = server();
  const script = await subject.request('/main.dart.js?version=1');
  assert.equal(script.status, 200);
  assert.equal(script.body, 'script');
  assert.equal(script.headers['Content-Type'], 'text/javascript; charset=utf-8');
  assert.equal(script.headers['Cache-Control'], 'no-store');
  assert.equal(script.headers['Cross-Origin-Opener-Policy'], 'same-origin');
  assert.equal(script.headers['Cross-Origin-Embedder-Policy'], 'credentialless');
  const image = await subject.request('/image.png');
  assert.equal(image.headers['Content-Type'], 'image/png');
  assert.equal(image.headers['Cache-Control'], undefined);
});

test('directory indexes and SPA fallback remain available', async () => {
  const subject = server();
  assert.equal((await subject.request('/folder/')).body, 'folder');
  assert.equal((await subject.request('/empty/')).body, 'index');
  assert.equal((await subject.request('/attendance/history')).body, 'index');
});

test('a file removed after its metadata check uses the SPA fallback', async () => {
  const response = await server({ vanishedAsset: true }).request('/main.dart.js');
  assert.equal(response.status, 200);
  assert.equal(response.body, 'index');
  assert.equal(response.headers['Content-Type'], 'text/html; charset=utf-8');
});

for (const options of [{ statError: 'EACCES' }, { readError: 'EACCES' }, { missingIndex: true }]) {
  test(`file errors return a response instead of escaping: ${JSON.stringify(options)}`, async () => {
    const response = await server(options).request('/');
    assert.equal(response.status, 500);
    assert.equal(response.body, 'Failed to read static file.');
  });
}

test('proxy routing continues to use the existing handler', () => {
  const subject = server();
  subject.proxy();
  assert.equal(subject.proxyCalls, 1);
});
