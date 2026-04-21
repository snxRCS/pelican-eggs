// Tiny static+API reverse proxy that fronts the TS6 Manager backend.
// Serves the built React bundle on SERVER_PORT and proxies /api + /ws
// to the backend on 127.0.0.1:BACKEND_PORT.

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
});

app.use('/api', apiProxy);
app.use('/ws', apiProxy);

app.use(express.static(STATIC_DIR, { index: 'index.html', fallthrough: true }));

// SPA fallback - deliver index.html for anything that doesn't match a file or /api|/ws
app.get('*', (req, res) => {
  res.sendFile(path.join(STATIC_DIR, 'index.html'));
});

const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`[proxy] Frontend+API on 0.0.0.0:${PORT} -> backend ${BACKEND}`);
});

// WebSocket upgrade support (apiProxy wired via app.use handles most;
// ensure raw upgrades for /ws also go through)
server.on('upgrade', (req, socket, head) => {
  if (req.url && (req.url.startsWith('/api') || req.url.startsWith('/ws'))) {
    apiProxy.upgrade(req, socket, head);
  } else {
    socket.destroy();
  }
});

process.on('SIGINT', () => process.exit(0));
process.on('SIGTERM', () => process.exit(0));
