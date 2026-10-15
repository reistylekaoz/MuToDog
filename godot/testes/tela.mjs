// Abre o export web no Chromium sem porta (page.route serve build/web) e fotografa vistas.
// Uso: node testes/tela.mjs <pasta-das-fotos> [vista ...]
// vista = "nome:x,y,giro,inclinacao,dist[,brilho,mundo]" (ex.: praca:138,124,-45,48,12; devias:210,40,-45,48,14,,3)
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-estudo';
const vistas = process.argv.slice(3).length ? process.argv.slice(3) : [
  'praca:138,124,-45,48,14',
  'longe:130,130,-45,60,60',
  'cima:128,128,0,89,190',
];
const web = path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', process.env.WEB || 'web');
fs.mkdirSync(pasta, { recursive: true });
const tipos = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };

const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
for (const v of vistas) {
  const [nome, nums] = v.split(':');
  const [x, y, giro, inclinacao, dist, brilho, mundo] = nums.split(",");
  const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
  let pronto = false;
  page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) pronto = true; if (/error|erro|TESTE/i.test(t)) console.log(`[${nome}]`, t); });
  page.on('pageerror', e => console.log('[pageerror]', e.message));
  await page.route('https://mu.local/**', async rota => {
    const arq = path.join(web, new URL(rota.request().url()).pathname.replace(/^\//, '') || 'index.html');
    if (!fs.existsSync(arq)) return rota.fulfill({ status: 404, body: '' });
    await rota.fulfill({ status: 200, body: fs.readFileSync(arq), headers: { 'content-type': tipos[path.extname(arq)] || 'application/octet-stream' } });
  });
  await page.goto(`https://mu.local/index.html?vista=1&x=${x}&y=${y}&giro=${giro}&inclinacao=${inclinacao}&dist=${dist}${brilho ? `&brilho=${brilho}` : ""}${mundo ? `&mundo=${mundo}` : ""}`);
  for (let i = 0; i < 240 && !pronto; i++) await page.waitForTimeout(500);
  await page.waitForTimeout(6000);
  const foto = path.join(pasta, `${nome}.png`);
  await page.screenshot({ path: foto });
  console.log('foto', foto, pronto ? '' : '(sem TESTE no console)');
  await page.close();
}
await nav.close();
