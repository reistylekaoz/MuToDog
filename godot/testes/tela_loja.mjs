// Fotos da loja do NPC, dos amigos (F) e do menu (U) no navegador, sem servidor:
// toca dados/gravacao_loja.txt (test1Dk anda ate a Lumen e abre a loja; gravada com
// MU_GRAVAR=... -- --auto test1,test1,test1Dk --andar 127,134 --loja Lumen --so_abrir 1 --sair 16).
// Uso: node testes/tela_loja.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-loja';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const tipos = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };

const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const marcas = [];
page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/error|erro|TESTE (loja|janela|falando)/i.test(t) && !/UID|durabilidade/.test(t)) console.log(t.slice(0, 200)); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
await page.route('https://mu.local/**', async rota => {
  const arq = path.join(web, new URL(rota.request().url()).pathname.replace(/^\//, '') || 'index.html');
  if (!fs.existsSync(arq)) return rota.fulfill({ status: 404, body: '' });
  await rota.fulfill({ status: 200, body: fs.readFileSync(arq), headers: { 'content-type': tipos[path.extname(arq)] || 'application/octet-stream' } });
});
async function esperar(re, seg) {
  for (let i = 0; i < seg * 2; i++) { if (marcas.some(t => re.test(t))) return true; await page.waitForTimeout(500); }
  return false;
}
await page.goto('https://mu.local/index.html?auto=test1,x,test1Dk&gravacao=loja&andar=127,134&loja=Lumen&so_abrir=1');
console.log('entrou:', await esperar(/TESTE entrou/, 240));
console.log('loja:', await esperar(/TESTE loja/, 60));
await page.waitForTimeout(3000);
// mouse no segundo item da loja (janela de 190 colada a esquerda do inventario)
const esc = Math.min(1280 / 640, (720 - 51 * 1280 / 640) / 429);
const x0 = 1280 - 2 * 190 * esc;
await page.mouse.move(x0 + (15 + 30) * esc, (50 + 10) * esc);
await page.waitForTimeout(600);
await page.screenshot({ path: path.join(pasta, '1-loja.png') });
await page.mouse.move(400, 300);
await page.keyboard.press('Escape');
await page.keyboard.press('f');
await page.waitForTimeout(800);
await page.screenshot({ path: path.join(pasta, '2-amigos.png') });
await page.keyboard.press('f');
await page.keyboard.press('u');
await page.waitForTimeout(800);
await page.screenshot({ path: path.join(pasta, '3-menu.png') });
await nav.close();
console.log('fotos em', pasta);
