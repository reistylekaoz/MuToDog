// Foto dos itens no chao em 3D: toca a sessao gravada da cidade (test1Dk) com
// ?chao_teste=1, que poe uma fileira de itens de mentira em volta do boneco.
// Uso: node testes/tela_chao.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-chao';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const tipos = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };

const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const marcas = [];
page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/error|erro|modelo /i.test(t) && !/UID|durabilidade/.test(t)) console.log(t.slice(0, 200)); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
await page.route('https://mu.local/**', async rota => {
  const arq = path.join(web, new URL(rota.request().url()).pathname.replace(/^\//, '') || 'index.html');
  if (!fs.existsSync(arq)) return rota.fulfill({ status: 404, body: '' });
  await rota.fulfill({ status: 200, body: fs.readFileSync(arq), headers: { 'content-type': tipos[path.extname(arq)] || 'application/octet-stream' } });
});
await page.goto('https://mu.local/index.html?auto=test1,x,test1Dk&gravacao=cidade&chao_teste=1&camera=' + (process.argv[4] || '9,45,-45') + '');
for (let i = 0; i < 480 && !marcas.some(t => /TESTE entrou/.test(t)); i++) await page.waitForTimeout(500);
await page.waitForTimeout(8000);
await page.screenshot({ path: path.join(pasta, 'chao.png') });
await nav.close();
console.log('fotos em', pasta);
