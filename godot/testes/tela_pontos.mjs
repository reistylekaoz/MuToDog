// Clique de verdade no + da janela C (sessao gravada da cidade): mostra se o clique chega.
// Uso: node testes/tela_pontos.mjs <pasta> [export, padrao build/web_novo]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');
const pasta = process.argv[2] || '/tmp/mu-pontos';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web_novo');
fs.mkdirSync(pasta, { recursive: true });
const tipos = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const marcas = [];
page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/TESTE (janela|ponto|entrou)|SCRIPT|pageerror/.test(t)) console.log(t.slice(0, 300)); });
await page.route('https://mu.local/**', async rota => {
  const arq = path.join(web, new URL(rota.request().url()).pathname.replace(/^\//, '') || 'index.html');
  if (!fs.existsSync(arq)) return rota.fulfill({ status: 404, body: '' });
  await rota.fulfill({ status: 200, body: fs.readFileSync(arq), headers: { 'content-type': tipos[path.extname(arq)] || 'application/octet-stream' } });
});
await page.goto('https://mu.local/index.html?auto=test1,x,test1Dk&gravacao=cidade');
for (let i = 0; i < 480 && !marcas.some(t => /TESTE entrou/.test(t)); i++) await page.waitForTimeout(500);
await page.waitForTimeout(3000);
await page.mouse.click(640, 300);
if (process.env.INV) { await page.keyboard.press('v'); await page.waitForTimeout(800); }
await page.keyboard.press('c');
await page.waitForTimeout(1500);
const ab = marcas.filter(t => /janela C aberta true/.test(t)).pop() || '';
const m = ab.match(/em \(([\d.]+), ([\d.]+)\) escala ([\d.]+)/);
const [x0, y0, e] = m ? [+m[1], +m[2], +m[3]] : [900, 0, 2];
for (const [i, alt] of [120, 175].entries()) {   // ALTURAS de forca e agilidade
  const x = x0 + 168 * e, y = y0 + (alt + 9) * e;
  console.log('clicando em', x, y);
  await page.mouse.move(x, y);
  await page.waitForTimeout(300);
  await page.mouse.click(x, y);
  await page.waitForTimeout(1500);
  await page.screenshot({ path: path.join(pasta, `pontos-${i}.png`) });
}
await nav.close();
