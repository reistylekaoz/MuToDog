// Foto da troca pedida pela janela do D: toca dados/gravacao_troca_d.txt (test300Dl pede a troca ao test400Dl com
// o D aberto, gravada com GRAVAR_A em testes/dois.sh) e fotografa quando a troca abre: o D fecha e o inventario
// aparece no lugar dele, ao lado da janela da troca.
// Uso: node testes/tela_troca_d.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { servir } from './rota_web.mjs';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-troca-d';
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
await page.goto('https://mu.local/index.html?auto=test300,x,test300Dl&gravacao=troca_d&troca=test400Dl');
console.log(await esperar(/TESTE entrou/, 300) ? 'entrou' : 'nao entrou');
console.log(await esperar(/TESTE pedindo troca/, 240));
await page.waitForTimeout(300);
await page.screenshot({ path: path.join(pasta, 'd_aberto.png') });
console.log(await esperar(/TESTE troca aberta/, 240));
await page.waitForTimeout(500);
await page.screenshot({ path: path.join(pasta, 'troca.png') });
await nav.close();
console.log('fotos em', pasta);
