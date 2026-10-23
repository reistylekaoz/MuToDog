// Fotos da rodada 5 no navegador, sem servidor: sessao gravada da cidade (test1Dk) com ?buff_teste=<passos>
// (jogo.gd _buff_teste): a janela de buffs com 6 icones e a dica do Jack O'Lantern, e uma foto por passo
// (aura, cor do corpo, fogos, redemoinho, escudo, fruta), em camera lenta.
// Uso: node testes/tela_buffs.mjs <pasta> [export, padrao build/web] [passos]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-buffs';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
const passos = (process.argv[4] || 'a4,a1,a8,a61,a57,a55,a56,fogos,natal,redemoinho,escudo,quebrou,fruta').split(',');
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
await page.goto(`https://mu.local/index.html?auto=test1,x,test1Dk&gravacao=cidade&camera=8,45,-45&buff_teste=${passos.join(',')}&lento=${1 / LENTO}`);
for (let i = 0; i < 480 && !marcas.some(t => /TESTE buff_teste janela/.test(t)); i++) await page.waitForTimeout(500);
console.log(marcas.find(t => /buff_teste janela/.test(t)));
// mouse no 5o icone (35 Jack O'Lantern: ordem 78, 35, 28, 4, 1, 55): x = 220 + 1*25 + 10 na tela de 640
const esc = 1280 / 640;
await page.mouse.move((220 + 1 * 25 + 10) * esc, (15 + 14) * esc);
for (const p of passos) {
  const re = new RegExp(`TESTE buff_teste ${p}$`);
  let achou = false;
  for (let i = 0; i < 1200 && !(achou = marcas.some(t => re.test(t))); i++) await page.waitForTimeout(50);
  if (!achou) { console.log('nao saiu', p); continue; }
  if (['fogos', 'natal'].includes(p)) {
    // os foguetes sobem por 0,8 s e estouram; 4 fotos
    for (const k of [1, 2, 3, 4]) { await page.waitForTimeout(500 * LENTO); await page.screenshot({ path: path.join(pasta, `${p}-${k}.png`) }); }
    continue;
  }
  await page.waitForTimeout(700 * LENTO);
  await page.screenshot({ path: path.join(pasta, `${p}.png`) });
}
console.log(marcas.slice(-4).join('\n'));
await nav.close();
console.log('fotos em', pasta);
