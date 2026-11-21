// Trivial static server for the spike. No COOP/COEP headers on purpose. `node serve.mjs [port]`
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const root = import.meta.dirname;
const port = Number(process.argv[2] || 8099);
const map = {
  '/vendor/ffmpeg/': 'node_modules/@ffmpeg/ffmpeg/dist/umd/',
  '/vendor/core/': 'node_modules/@ffmpeg/core/dist/umd/',
};
const types = { '.js': 'text/javascript', '.wasm': 'application/wasm', '.html': 'text/html' };
fs.mkdirSync(path.join(root, 'out/wasm'), { recursive: true });

http.createServer((req, res) => {
  const url = decodeURI(req.url.split('?')[0]);
  if (req.method === 'POST' && url.startsWith('/save/')) {
    const name = path.basename(url);
    const ch = [];
    req.on('data', (c) => ch.push(c));
    req.on('end', () => {
      fs.writeFileSync(path.join(root, 'out/wasm', name), Buffer.concat(ch));
      res.end('ok');
    });
    return;
  }
  let file = url === '/' ? 'index.html' : null;
  for (const [p, d] of Object.entries(map)) if (url.startsWith(p)) file = d + url.slice(p.length);
  if (!file) { res.statusCode = 404; return res.end(); }
  const full = path.join(root, file);
  if (!full.startsWith(root) || !fs.existsSync(full)) { res.statusCode = 404; return res.end(); }
  res.setHeader('Content-Type', types[path.extname(full)] || 'application/octet-stream');
  fs.createReadStream(full).pipe(res);
}).listen(port, () => console.log('http://localhost:' + port));
