// Foto da dica de cada buff de selo e scroll (textos do dados_buff.py, rodada 23): ?buff_janela=<ids> poe so esses na
// janela, e o mouse passa em cada icone. Uso: node testes/tela_textos_buffs.mjs <pasta> [export] [ids]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-buffs';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
const ids = process.argv[4] || '29,30,44,45,89,104';
const passos = ['x'];
const LENTO = 2;
fs.mkdirSync(pasta, { recursive: true });
const tipos = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };

const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const marcas = [];
page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/error|erro|efeito sem/i.test(t) && !/UID|durabilidade/.test(t)) console.log(t.slice(0, 240)); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
await page.route('https://mu.local/**', async rota => {
  const arq = path.join(web, new URL(rota.request().url()).pathname.replace(/^\//, '') || 'index.html');
  if (!fs.existsSync(arq)) return rota.fulfill({ status: 404, body: '' });
  await rota.fulfill({ status: 200, body: fs.readFileSync(arq), headers: { 'content-type': tipos[path.extname(arq)] || 'application/octet-stream' } });
});
await page.goto(`https://mu.local/index.html?auto=test1,x,test1Dk&gravacao=cidade&camera=8,45,-45&buff_teste=${passos.join(',')}&buff_janela=${ids}&lento=${1 / LENTO}`);
for (let i = 0; i < 480 && !marcas.some(t => /TESTE buff_teste janela/.test(t)); i++) await page.waitForTimeout(500);
console.log(marcas.find(t => /buff_teste janela/.test(t)));
const esc = 1280 / 640;
const n = ids.split(',').length;
for (let i = 0; i < n; i++) {
  await page.mouse.move((220 + i * 25 + 10) * esc, (15 + 14) * esc);
  await page.waitForTimeout(800);
  await page.screenshot({ path: path.join(pasta, `dica-${i}.png`), clip: { x: 300, y: 0, width: 700, height: 260 } });
}
await nav.close();
console.log('fotos em', pasta);
