// Tiny static+API reverse proxy that fronts the TS6 Manager backend.
// Serves the built React bundle on SERVER_PORT and proxies /api + /ws
// to the backend on 127.0.0.1:BACKEND_PORT.
//
// IMPORTANT: The TS6 backend mounts its router at /api (e.g. /api/auth/setup),
// so when this proxy receives /api/* it must forward the FULL path — including
// the /api prefix — to the backend. Express strips the mount prefix before
// middleware sees the URL, so we restore it with pathRewrite.

const path = require('path');
const express = require('/app/runtime_proxy/node_modules/express');
const { createProxyMiddleware } = require('/app/runtime_proxy/node_modules/http-proxy-middleware');

const PORT = parseInt(process.env.SERVER_PORT || '3000', 10);
const BACKEND = `http://127.0.0.1:${process.env.BACKEND_PORT || '3001'}`;
const STATIC_DIR = '/app/packages/frontend/dist';

const app = express();

const apiProxy = createProxyMiddleware({
  target: BACKEND,
  changeOrigin: true,
  ws: true,
  xfwd: true,
  logLevel: 'warn',
  pathRewrite: (reqPath) => '/api' + reqPath,
});

const wsProxy = createProxyMiddleware({
  target: BACKEND,
  changeOrigin: true,
  ws: true,
  xfwd: true,
  logLevel: 'warn',
  pathRewrite: (reqPath) => '/ws' + reqPath,
});

app.use('/api', apiProxy);
app.use('/ws', wsProxy);

app.use(express.static(STATIC_DIR, { index: 'index.html', fallthrough: true }));

// SPA fallback - deliver index.html for anything that doesn't match a file or /api|/ws
app.get('*', (req, res) => {
  res.sendFile(path.join(STATIC_DIR, 'index.html'));
});

const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`[proxy] Frontend+API on 0.0.0.0:${PORT} -> backend ${BACKEND}`);
});

// WebSocket upgrade support: route /api/* and /ws/* upgrades through the correct proxy.
server.on('upgrade', (req, socket, head) => {
  if (!req.url) return socket.destroy();
  if (req.url.startsWith('/api')) {
    return apiProxy.upgrade(req, socket, head);
  }
  if (req.url.startsWith('/ws')) {
    return wsProxy.upgrade(req, socket, head);
  }
  socket.destroy();
});

process.on('SIGINT', () => process.exit(0));
process.on('SIGTERM', () => process.exit(0));
