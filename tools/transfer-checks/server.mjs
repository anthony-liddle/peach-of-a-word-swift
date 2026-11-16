// Serve the web's built transfer page on this Mac, for the UI tests in
// UITests/TransferFromTheWebPage.swift. The simulator shares this Mac's
// network, so its Safari reaches the page at http://localhost:PORT with no
// Vercel sign-in.
//
//   node tools/transfer-checks/server.mjs <web dist dir> <port>
//
// Two things the real site doesn't have, both for the tests:
// - /transfer is served from transfer.html, as vercel.json rewrites it;
// - /seed writes a save into the browser's storage, then opens /transfer, so a
//   test starts from a streak without playing a board. Its query: count, and
//   ended, how many days before today the streak was last extended (default 0).
//   Today is counted the way the game counts it, from 1 January 2026 in the
//   browser's own zone.
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';

const [dist, port] = process.argv.slice(2);
if (!dist || !port) {
  console.error('usage: server.mjs <web dist dir> <port>');
  process.exit(2);
}

const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.json': 'application/json',
  '.woff2': 'font/woff2',
  '.txt': 'text/plain; charset=utf-8',
};

const seed = (count, ended) => `<!doctype html>
<meta charset="utf-8">
<title>Seed</title>
<script>
  // The game's day count: whole days from 1 January 2026 to today's local date.
  const now = new Date();
  const today = Math.floor(
    (Date.UTC(now.getFullYear(), now.getMonth(), now.getDate()) - Date.UTC(2026, 0, 1)) / 86400000,
  );
  localStorage.setItem('eight-letters/v1', JSON.stringify({
    version: 1,
    days: {},
    streak: { count: ${count}, lastClearedDayIndex: today - ${ended} },
    endless: null,
  }));
  location.replace('/transfer');
</script>
`;

createServer(async (req, res) => {
  const url = new URL(req.url ?? '/', 'http://localhost');
  if (url.pathname === '/seed') {
    const count = Number.parseInt(url.searchParams.get('count') ?? '5', 10);
    const ended = Number.parseInt(url.searchParams.get('ended') ?? '0', 10);
    res.writeHead(200, { 'content-type': types['.html'], 'cache-control': 'no-store' });
    res.end(seed(count, ended));
    return;
  }
  const path = url.pathname === '/transfer' ? '/transfer.html' : url.pathname;
  const file = normalize(join(dist, path === '/' ? '/index.html' : path));
  if (!file.startsWith(normalize(dist))) {
    res.writeHead(403).end();
    return;
  }
  try {
    const body = await readFile(file);
    res.writeHead(200, {
      'content-type': types[extname(file)] ?? 'application/octet-stream',
      'cache-control': 'no-store',
    });
    res.end(body);
  } catch {
    res.writeHead(404).end('not found');
  }
}).listen(Number(port), () => console.log(`serving ${dist} on http://localhost:${port}`));
