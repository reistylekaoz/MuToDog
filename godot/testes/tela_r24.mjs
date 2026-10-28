// Fotos da rodada 24: a tela de login do S6 no navegador (World74 com a camera passeando, logo acendendo,
// janela da conta). Tira fotos em 3 s, 12 s e 30 s (a camera anda pelo caminho), uma com a conta digitada.
// Uso: node testes/tela_r24.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { servir } from './rota_web.mjs';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-r24';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const marcas = [];
page.on('console', m => { const t = m.text(); marcas.push(t); if (/ERROR|SCRIPT|pacote/i.test(t)) console.log(t.slice(0, 160)); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
await servir(page, web);
await page.goto('https://mu.local/index.html');
// espera o canvas e o pacote do mapa 74
for (let i = 0; i < 480 && !marcas.some(t => /TESTE pacote mapa 74/.test(t)); i++) await page.waitForTimeout(250);
const t0 = Date.now();
for (const [s, nome] of [[3, 'a_3s'], [12, 'b_12s'], [30, 'c_30s']]) {
  const falta = s * 1000 - (Date.now() - t0);
  if (falta > 0) await page.waitForTimeout(falta);
  await page.screenshot({ path: path.join(pasta, nome + '.png') });
  console.log('foto', nome);
}
await page.mouse.click(640, 400);
await page.keyboard.type('test0');
await page.screenshot({ path: path.join(pasta, 'd_conta.png') });
console.log('foto d_conta');
await page.close();
await nav.close();
console.log('fotos em', pasta);
