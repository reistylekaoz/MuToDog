// Gera o atlas dos icones dos itens: abre o export "Icones" (build/icones) no Chromium
// sem porta, com ?icones=1, e salva dados/icones.png e dados/icones.json.
// Uso: GODOT --headless --export-release Icones build/icones/index.html && node testes/icones.mjs
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const raiz = path.join(path.dirname(new URL(import.meta.url).pathname), '..');
const web = path.join(raiz, 'build', 'icones');
const tipos = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await nav.newPage({ viewport: { width: 640, height: 480 } });
let pronto = false;
page.on('console', m => { const t = m.text(); if (/ICONES PRONTO/.test(t)) pronto = true; if (/ICONES|error|erro/i.test(t)) console.log(t.slice(0, 300)); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
await page.route('https://mu.local/**', async rota => {
  const arq = path.join(web, new URL(rota.request().url()).pathname.replace(/^\//, '') || 'index.html');
  if (!fs.existsSync(arq)) return rota.fulfill({ status: 404, body: '' });
  await rota.fulfill({ status: 200, body: fs.readFileSync(arq), headers: { 'content-type': tipos[path.extname(arq)] || 'application/octet-stream' } });
});
await page.goto('https://mu.local/index.html?icones=1');
for (let i = 0; i < 1200 && !pronto; i++) await page.waitForTimeout(500);
if (!pronto) { console.log('nao terminou'); process.exit(1); }
const png = await page.evaluate(() => window.icones_png);
const json = await page.evaluate(() => window.icones_json);
fs.writeFileSync(path.join(raiz, 'dados', 'icones.png'), Buffer.from(png, 'base64'));
fs.writeFileSync(path.join(raiz, 'dados', 'icones.json'), json);
console.log('salvo', path.join(raiz, 'dados', 'icones.png'));
await nav.close();
