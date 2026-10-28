// Pontos em massa na janela C, no navegador e sem servidor: toca dados/gravacao_pontos.txt (socketDl, que manda
// /add str 250 aos 20 s) e, antes disso, abre a janela C, clica no + da forca, digita 250 e tira as fotos:
// pontos1 (caixa com o 1 selecionado), pontos2 (250 digitado), pontos3 (depois do Enter, com a ficha nova).
// Uso: node testes/tela_pontos.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { servir } from './rota_web.mjs';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-pontos';
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
await page.goto('https://mu.local/index.html?auto=socket,x,socketDl&gravacao=pontos');
console.log('entrou:', await esperar(/TESTE entrou/, 240));
await page.waitForTimeout(1500);
await page.keyboard.press('c');
console.log('janela:', await esperar(/TESTE janela C aberta true/, 10));
// janela de 190 x 429 colada na direita, escala 720/429 limitada por 1280/640 (ver JanelaPersonagem._ajustar)
const m = marcas.find(t => /janela C aberta true/.test(t)).match(/em \(([\d.]+), ([\d.]+)\) escala ([\d.]+)/);
const [x0, y0, e] = [+m[1], +m[2], +m[3]];
await page.mouse.click(x0 + 168 * e, y0 + (120 + 9) * e);
console.log('caixa:', await esperar(/TESTE caixa \["STR"/, 10));
await page.waitForTimeout(500);
await page.screenshot({ path: path.join(pasta, 'pontos1.png') });
await page.keyboard.type('250');
await page.waitForTimeout(300);
await page.screenshot({ path: path.join(pasta, 'pontos2.png') });
await page.keyboard.press('Enter');
console.log('mandou:', await esperar(/TESTE pontos 250/, 5));
for (let i = 0; i < 720 && marcas.filter(t => /TESTE entrou/.test(t)).length < 2; i++) await page.waitForTimeout(250);
console.log('ficha nova:', marcas.filter(t => /TESTE entrou/.test(t)).length >= 2);
await page.waitForTimeout(2500);
await page.screenshot({ path: path.join(pasta, 'pontos3.png') });
console.log(marcas.filter(t => /TESTE (entrou|pontos|caixa|janela C)/.test(t)).map(t => t.replace(/"exp".*"pontos"/, '.."pontos"').slice(0, 200)).join('\n'));
await nav.close();
console.log('fotos em', pasta);
