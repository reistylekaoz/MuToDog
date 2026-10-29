// Fotos dos avisos do meio da tela (global e guilda), da janela Move no jeito do cliente e da ajuda (F1)
// Uso: node testes/tela_avisos.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { servir } from './rota_web.mjs';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-avisos';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const marcas = [];
page.on('console', m => { const t = m.text(); if (/TESTE|SCRIPT ERROR/.test(t)) marcas.push(t); if (/SCRIPT ERROR/.test(t)) console.log(t); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
await servir(page, web);
async function esperar(re, seg) {
  for (let i = 0; i < seg * 2; i++) { const t = marcas.find(t => re.test(t)); if (t) return t; await page.waitForTimeout(500); }
  return null;
}
await page.goto('https://mu.local/index.html?auto=test1,x,test1Dk&gravacao=cidade&avisos_teste=1');
console.log(await esperar(/TESTE entrou/, 300) ? 'entrou' : 'nao entrou');
for (const n of ["centro", "move", "ajuda"]) {
  console.log(await esperar(new RegExp('TESTE avisos ' + n), 60) || 'sem ' + n);
  await page.waitForTimeout(1200);
  await page.screenshot({ path: path.join(pasta, n + '.png') });
}
await nav.close();
console.log('fotos em', pasta);
