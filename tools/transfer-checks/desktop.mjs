// Check 4's computer half: the transfer page in a desktop browser on this
// Mac, from a save, offering its own address to copy. Prints that address, for
// the simulator's Safari to open in UITests/TransferFromTheWebPage.swift.
//
//   node tools/transfer-checks/desktop.mjs http://localhost:PORT [count]
//
// Headless Chrome, told by its own Blink settings that its pointer is fine,
// the way a computer's mouse or trackpad is: the page decides "computer" by
// matchMedia('(pointer: fine)'), and headless Chrome otherwise reports none.
// Nothing in the page is replaced. Exits non-zero if the page didn't show the
// computer's view, or didn't offer an address.
import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const [base, count = '7'] = process.argv.slice(2);
const chromePath = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const port = 9500 + Math.floor(Math.random() * 400);
const profile = mkdtempSync(join(tmpdir(), 'transfer-desktop-'));
const chrome = spawn(chromePath, [
  '--headless=new', `--remote-debugging-port=${port}`, '--no-first-run',
  `--user-data-dir=${profile}`,
  '--blink-settings=primaryPointerType=4,availablePointerTypes=4,primaryHoverType=2,availableHoverTypes=2',
  'about:blank',
], { stdio: 'ignore' });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const exited = new Promise((r) => chrome.once('exit', r));
// Chrome writes to its profile until it exits, so the profile goes after.
const done = async (code) => {
  chrome.kill();
  await exited;
  rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
  process.exit(code);
};
const fail = async (why) => { console.error(why); await done(1); };

let tabs;
for (let i = 0; i < 50; i++) {
  try { tabs = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json(); if (tabs.length) break; } catch {}
  await sleep(200);
}
if (!tabs) await fail('Chrome did not start');
const ws = new WebSocket(tabs.find((t) => t.type === 'page').webSocketDebuggerUrl);
await new Promise((r) => (ws.onopen = r));
let id = 0;
const waiting = new Map();
ws.onmessage = (m) => { const d = JSON.parse(m.data); if (d.id && waiting.has(d.id)) { waiting.get(d.id)(d); waiting.delete(d.id); } };
const cmd = (method, params = {}) => new Promise((r) => { const i = ++id; waiting.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
const ev = async (expression) =>
  (await cmd('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true })).result?.result?.value;

await cmd('Page.enable');
await cmd('Emulation.setDeviceMetricsOverride', { width: 1280, height: 900, deviceScaleFactor: 1, mobile: false });
await cmd('Page.navigate', { url: `${base}/seed?count=${count}` });
for (let i = 0; i < 50 && !(await ev(`location.pathname === '/transfer' && !!document.getElementById('address')?.textContent`)); i++) await sleep(200);

const page = await ev(`({
  fine: matchMedia('(pointer: fine)').matches,
  computer: !document.getElementById('on-computer').hidden,
  phone: !document.getElementById('on-phone').hidden,
  address: document.getElementById('address').textContent,
})`);
if (!page?.fine) await fail('the browser did not report a fine pointer');
if (!page.computer || page.phone) await fail(`the page did not show the computer's view: ${JSON.stringify(page)}`);
if (!page.address.startsWith(`${base}/transfer#streak?v=1&count=${count}&lastCleared=`))
  await fail(`unexpected address: ${page.address}`);

// The copy itself, as a player would: the button, then the status it sets.
// Headless Chrome may refuse the clipboard; either way the address is the one
// the page offers, which is what the test opens on the phone.
await ev(`document.getElementById('copy').click()`);
for (let i = 0; i < 20 && !(await ev(`document.getElementById('copy-status').textContent`)); i++) await sleep(100);

console.log(page.address);
ws.close();
await done(0);
