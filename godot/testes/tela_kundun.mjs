// Fotos da Box of Kundun +1 a +5 (bau dourado, MagicBox08) e do "(Tier N)": toca dados/gravacao_kundun.txt
// (test2Dl com as 5 caixas nos slots 12 a 16, larga cada uma e pega o excelente que sai, gravada com MU_GRAVAR e o
// roteiro x:12-12;p ... x:16-16;p), abre o inventario, passa o mouse na caixa +1 e depois no excelente Tier 3.
// Uso: node testes/tela_kundun.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { servir } from './rota_web.mjs';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-kundun';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const marcas = [];
page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
await servir(page, web);
async function esperar(re, seg) {
  for (let i = 0; i < seg * 2; i++) { const t = marcas.find(t => re.test(t)); if (t) return t; await page.waitForTimeout(500); }
  return null;
}
const esc = Math.min(1280 / 640, (720 - 51 * 1280 / 640) / 429);
const x0 = 1280 - 190 * esc;
// casa da mochila no espaco da janela (190 x 429): grade em 15,200, casa de 20
const casa = s => [x0 + (15 + ((s - 12) % 8) * 20 + 10) * esc, (200 + Math.floor((s - 12) / 8) * 20 + 10) * esc];
await page.goto('https://mu.local/index.html?auto=test2,x,test2Dl&gravacao=kundun');
console.log(await esperar(/TESTE entrou/, 300) ? 'entrou' : 'nao entrou');
await page.waitForTimeout(500);
await page.keyboard.press('i');
await page.mouse.move(...casa(12));
await page.waitForTimeout(800);
await page.screenshot({ path: path.join(pasta, 'caixas.png') });
console.log(await esperar(/TESTE pegou Great Dragon Helm/, 400));
await page.waitForTimeout(1500);
await page.mouse.move(...casa(22));
await page.waitForTimeout(800);
await page.screenshot({ path: path.join(pasta, 'tier.png') });
await nav.close();
console.log('fotos em', pasta);
