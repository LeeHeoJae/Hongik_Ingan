const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const projectRoot = path.resolve(__dirname, '..');
const webBuildDir = path.join(projectRoot, 'build', 'web');
const serviceWorkerPath = path.join(webBuildDir, 'app_service_worker.js');
const buildVersionToken = '__HONGIK_INGAN_BUILD_VERSION__';

optimizeWebBuild();

function optimizeWebBuild() {
  assertFile(serviceWorkerPath);
  injectBuildVersion();
}

function injectBuildVersion() {
  const hash = crypto.createHash('sha256');
  for (const relativePath of [
    'main.dart.js',
    'main.dart.mjs',
    'main.dart.wasm',
    path.join('assets', 'assets', 'fonts', 'NotoSansKR-Regular.ttf')
  ]) {
    const filePath = path.join(webBuildDir, relativePath);
    assertFile(filePath);
    hash.update(fs.readFileSync(filePath));
  }
  const buildVersion = hash.digest('hex').slice(0, 16);
  const serviceWorker = fs.readFileSync(serviceWorkerPath, 'utf8');
  const currentVersion = serviceWorker.match(
    /const BUILD_VERSION = '([a-f0-9]{16})';/
  )?.[1];
  if (!serviceWorker.includes(buildVersionToken)) {
    if (currentVersion === buildVersion) {
      console.log(`[web-build] Service worker cache version: ${buildVersion}`);
      return;
    }
    throw new Error('Service worker build-version token was not found.');
  }

  fs.writeFileSync(
    serviceWorkerPath,
    serviceWorker.replaceAll(buildVersionToken, buildVersion),
    'utf8'
  );
  console.log(`[web-build] Service worker cache version: ${buildVersion}`);
}

function assertFile(filePath) {
  if (!fs.statSync(filePath, { throwIfNoEntry: false })?.isFile()) {
    throw new Error(`Required build file is missing: ${filePath}`);
  }
}
