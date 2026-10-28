// Quadros do Twisting Slash (skill 41) no navegador, sem servidor: toca dados/gravacao_skill.txt (testgmDk) e,
// a partir da marca da skill, tira 10 fotos recortadas em volta do cavaleiro, uma a cada 100 ms.
// Uso: node testes/tela_giro.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { servir } from './rota_web.mjs';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-giro';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const marcas = [];
page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
await servir(page, web);
async function esperar(re, seg) {
  for (let i = 0; i < seg * 4; i++) { if (marcas.some(t => re.test(t))) return true; await page.waitForTimeout(250); }
  return false;
}
await page.goto('https://mu.local/index.html?auto=testgm,x,testgmDk&gravacao=skill&cacar=3&skill=41');
console.log('entrou:', await esperar(/TESTE entrou/, 240));
await page.mouse.move(640, 300);
console.log('skill:', await esperar(/TESTE skill 41/, 90));
for (let i = 0; i < 10; i++) {
  await page.screenshot({ path: path.join(pasta, `giro${i}.png`), clip: { x: 390, y: 130, width: 500, height: 400 } });
  await page.waitForTimeout(100);
}
await nav.close();
console.log('fotos em', pasta);
