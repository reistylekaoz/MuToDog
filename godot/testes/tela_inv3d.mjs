// Fotos do item 3D no inventario (Vitrine3D): ?inv_teste=1 enche a mochila de mentira (joias, +7 a +15,
// Box of Kundun +1 e +5, item que gira sozinho), abre o inventario e passa o mouse em algumas casas.
// Cada casa sai em 3 fotos com 150 ms entre elas (o giro aparece na diferenca) e um recorte ampliado.
// Uso: node testes/tela_inv3d.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { servir } from './rota_web.mjs';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-inv3d';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const marcas = [];
page.on('console', m => { const t = m.text(); if (/TESTE|ERROR|SCRIPT/.test(t)) { marcas.push(t); if (!/TESTE/.test(t)) console.log(t); } });
page.on('pageerror', e => console.log('[pageerror]', e.message));
await servir(page, web);
async function esperar(re, seg) {
  for (let i = 0; i < seg * 2; i++) { const t = marcas.find(t => re.test(t)); if (t) return t; await page.waitForTimeout(500); }
  return null;
}
const esc = Math.min(1280 / 640, (720 - 51 * 1280 / 640) / 429);
const x0 = 1280 - 190 * esc;
const casa = s => [x0 + (15 + ((s - 12) % 8) * 20 + 10) * esc, (200 + Math.floor((s - 12) / 8) * 20 + 10) * esc];
const janela = { x: Math.floor(x0), y: 0, width: Math.ceil(190 * esc), height: Math.ceil(429 * esc) };
await page.goto('https://mu.local/index.html?auto=test1,x,test1Dk&gravacao=cidade&inv_teste=1');
console.log(await esperar(/TESTE entrou/, 300) ? 'entrou' : 'nao entrou');
console.log(await esperar(/TESTE inv pronto/, 30) || 'sem inv');
await page.mouse.move(100, 100);
await page.waitForTimeout(6000);   // os modelos baixam
await page.screenshot({ path: path.join(pasta, 'parado.png'), clip: janela });
for (const [nome, s] of [['joia', 12], ['kundun5', 17], ['cetro', 18], ['espada15', 24], ['escudo', 25], ['asa', 46]]) {
  await page.mouse.move(...casa(s));
  await page.waitForTimeout(1500);
  for (let k = 0; k < 4; k++) {
    await page.screenshot({ path: path.join(pasta, `${nome}_${k}.png`), clip: janela });
    await page.waitForTimeout(150);
  }
}
await nav.close();
console.log('fotos em', pasta);
