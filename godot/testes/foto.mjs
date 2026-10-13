// Foto de uma tela do export web, sem porta (page.route serve build/web).
// Uso: node testes/foto.mjs <foto.png> "<query>" [segundos depois do TESTE] [fotos a mais, de 1 em 1 s]
// ex.: node testes/foto.mjs /tmp/v.png "vitrine=parado" 4
// FOTO_ACOES="c;m:180,690": antes das fotos a mais, aperta a tecla c e passa o mouse em (180, 690)
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const [foto, query = '', espera = '5', mais = '0'] = process.argv.slice(2);
const web = path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
const tipos = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
let pronto = false;
page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) pronto = true; if (/error|erro|TESTE|warn/i.test(t)) console.log(t.slice(0, 300)); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
await page.route('https://mu.local/**', async rota => {
  const arq = path.join(web, new URL(rota.request().url()).pathname.replace(/^\//, '') || 'index.html');
  if (!fs.existsSync(arq)) return rota.fulfill({ status: 404, body: '' });
  await rota.fulfill({ status: 200, body: fs.readFileSync(arq), headers: { 'content-type': tipos[path.extname(arq)] || 'application/octet-stream' } });
});
await page.goto(`https://mu.local/index.html?${query}`);
for (let i = 0; i < 240 && !pronto; i++) await page.waitForTimeout(500);
await page.waitForTimeout(Number(espera) * 1000);
fs.mkdirSync(path.dirname(foto), { recursive: true });
await page.screenshot({ path: foto });
console.log('foto', foto, pronto ? '' : '(sem TESTE no console)');
for (const a of (process.env.FOTO_ACOES || '').split(';').filter(Boolean)) {
  if (a.startsWith('m:')) { const [x, y] = a.slice(2).split(',').map(Number); await page.mouse.move(x, y); }
  else await page.keyboard.press(a);
  await page.waitForTimeout(300);
}
for (let i = 1; i <= Number(mais); i++) {
  await page.waitForTimeout(1000);
  const f = foto.replace(/\.png$/, `-${i}.png`);
  await page.screenshot({ path: f });
  console.log('foto', f);
}
await nav.close();
