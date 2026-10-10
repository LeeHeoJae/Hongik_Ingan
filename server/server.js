const fs = require('fs/promises');
const http = require('http');
const path = require('path');

const proxyHandler = require('../api/proxy');

const rootDir = path.resolve(__dirname, '..');
const webDir = path.join(rootDir, 'build', 'web');
const indexFile = path.join(webDir, 'index.html');
const port = Number(process.env.PORT || 8080);

const contentTypes = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.wasm': 'application/wasm',
  '.woff2': 'font/woff2'
};

const server = http.createServer((req, res) => {
  if (req.url.startsWith('/api/proxy')) {
    proxyHandler(req, res);
    return;
  }

  serveStatic(req, res);
});

server.listen(port, () => {
  console.log(`Hongik Ingan web server: http://localhost:${port}`);
});

async function serveStatic(req, res) {
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  res.setHeader('Cross-Origin-Embedder-Policy', 'credentialless');

  let filePath;
  try {
    filePath = staticRequestPath(req.url);
  } catch (_) {
    res.statusCode = 400;
    res.end('Invalid request path.');
    return;
  }

  if (filePath === null) {
    res.statusCode = 403;
    res.end('Forbidden');
    return;
  }

  try {
    const stats = await fs.stat(filePath).catch((error) => {
      if (isMissingFile(error)) return null;
      throw error;
    });
    if (!stats) {
      filePath = indexFile;
    } else if (stats.isDirectory()) {
      filePath = path.join(filePath, 'index.html');
    }

    let data;
    try {
      data = await fs.readFile(filePath);
    } catch (error) {
      if (!isMissingFile(error) || filePath === indexFile) throw error;
      filePath = indexFile;
      data = await fs.readFile(filePath);
    }
    const extension = path.extname(filePath).toLowerCase();
    res.setHeader('Content-Type', contentTypes[extension] || 'application/octet-stream');
    if (
      extension === '.html' ||
      extension === '.js' ||
      extension === '.mjs' ||
      extension === '.json'
    ) {
      res.setHeader('Cache-Control', 'no-store');
    }
    res.end(data);
  } catch (_) {
    res.statusCode = 500;
    res.end('Failed to read static file.');
  }
}

function staticRequestPath(url) {
  const requestUrl = new URL(url, `http://localhost:${port}`);
  const decodedPath = decodeURIComponent(requestUrl.pathname);
  if (decodedPath.includes('\0')) throw new Error('Invalid request path.');
  const filePath = path.resolve(webDir, `.${decodedPath}`);
  const relativePath = path.relative(webDir, filePath);
  if (
    relativePath === '..' ||
    relativePath.startsWith(`..${path.sep}`) ||
    path.isAbsolute(relativePath)
  ) {
    return null;
  }
  return filePath;
}

function isMissingFile(error) {
  return error.code === 'ENOENT' || error.code === 'ENOTDIR';
}
