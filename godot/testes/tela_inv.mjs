// Fotos do inventario e das skills no navegador, sem servidor: toca a sessao
// gravada dados/gravacao_skill.txt (testgmDk, feita com
// MU_GRAVAR=... MU_EXTRA="--skill 41" testes/cacar.sh testgm,testgm,testgmDk 3 50 <arquivo>).
// Uso: node testes/tela_inv.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-inv';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const tipos = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };

const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const marcas = [];
page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/error|erro|TESTE/i.test(t) && !/UID|item no chao|durabilidade/.test(t)) console.log(t.slice(0, 200)); });
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
await page.goto('https://mu.local/index.html?auto=testgm,x,testgmDk&gravacao=skill&cacar=3&skill=41');
console.log('entrou:', await esperar(/TESTE entrou/, 240));
console.log('skills:', await esperar(/TESTE skills/, 30));
await page.mouse.move(640, 300);
console.log('skill solta:', await esperar(/TESTE skill 41/, 90));
await page.waitForTimeout(250);
await page.screenshot({ path: path.join(pasta, '1-skill.png') });
// inventario (I) com a dica de um item da mochila
await page.keyboard.press('i');
await page.waitForTimeout(800);
const esc = Math.min(1280 / 640, (720 - 51 * 1280 / 640) / 429);
const x0 = 1280 - 190 * esc;
await page.mouse.move(x0 + (15 + 10) * esc, (200 + 10) * esc);
await page.waitForTimeout(600);
await page.screenshot({ path: path.join(pasta, '2-inventario.png') });
// lista de skills: clique no quadro da skill atual (x 392 da tela de 640, y 437 de 480)
await page.keyboard.press('i');
const e = 1280 / 640;
await page.mouse.click(400 * e, 720 - (480 - 450) * e);
await page.waitForTimeout(600);
await page.mouse.move(385 * e + 16 * e, 720 - (51 + 39) * e + 20 * e);
await page.waitForTimeout(600);
await page.screenshot({ path: path.join(pasta, '3-lista-skills.png') });
await nav.close();
console.log('fotos em', pasta);
