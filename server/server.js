const fs = require('fs');
const http = require('http');
const path = require('path');

const proxyHandler = require('../api/proxy');

const rootDir = path.resolve(__dirname, '..');
const webDir = path.join(rootDir, 'build', 'web');
const port = Number(process.env.PORT || 8080);

const contentTypes = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
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

function serveStatic(req, res) {
  const requestUrl = new URL(req.url, `http://localhost:${port}`);
  const decodedPath = decodeURIComponent(requestUrl.pathname);
  const normalizedPath = path.normalize(decodedPath).replace(/^(\.\.[/\\])+/, '');
  let filePath = path.join(webDir, normalizedPath);

  if (!filePath.startsWith(webDir)) {
    res.statusCode = 403;
    res.end('Forbidden');
    return;
  }

  if (fs.existsSync(filePath) && fs.statSync(filePath).isDirectory()) {
    filePath = path.join(filePath, 'index.html');
  }

  if (!fs.existsSync(filePath)) {
    filePath = path.join(webDir, 'index.html');
  }

  fs.readFile(filePath, (error, data) => {
    if (error) {
      res.statusCode = 500;
      res.end('Failed to read static file.');
      return;
    }

    const extension = path.extname(filePath).toLowerCase();
    res.setHeader('Content-Type', contentTypes[extension] || 'application/octet-stream');
    if (extension === '.html' || extension === '.js' || extension === '.json') {
      res.setHeader('Cache-Control', 'no-store');
    }
    res.end(data);
  });
}
