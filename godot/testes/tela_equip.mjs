// Fotos de perto do boneco vestido (armadura, arma, asa), sem servidor: toca a
// sessao gravada dados/gravacao_skill.txt (testgmDk) com a camera colada no boneco.
// Uso: node testes/tela_equip.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-equip';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
const quem = process.argv[4] || 'testgm,x,testgmDk&gravacao=skill';
fs.mkdirSync(pasta, { recursive: true });
const tipos = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };

const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const marcas = [];
let modelos = 0;
async function foto(nome, camera) {
  const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
  page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/error|erro|TESTE vestido|modelo /i.test(t) && !/UID|item no chao|durabilidade/.test(t)) console.log(t.slice(0, 200)); });
  page.on('pageerror', e => console.log('[pageerror]', e.message));
  await page.route('https://mu.local/**', async rota => {
    const arq = path.join(web, new URL(rota.request().url()).pathname.replace(/^\//, '') || 'index.html');
    if (arq.includes('/modelos/')) modelos++;
    if (!fs.existsSync(arq)) return rota.fulfill({ status: 404, body: '' });
    await rota.fulfill({ status: 200, body: fs.readFileSync(arq), headers: { 'content-type': tipos[path.extname(arq)] || 'application/octet-stream' } });
  });
  marcas.length = 0;
  await page.goto(`https://mu.local/index.html?auto=${quem}&camera=${camera}`);
  for (let i = 0; i < 480 && !marcas.some(t => /TESTE entrou/.test(t)); i++) await page.waitForTimeout(500);
  await page.waitForTimeout(8000);
  await page.screenshot({ path: path.join(pasta, nome + '.png') });
  await page.close();
}
await foto('1-frente', process.argv[5] || '6,20,135');
await foto('2-costas', '6,25,-45');
await foto('3-lado', '6,10,45');
await nav.close();
console.log('modelos baixados:', modelos, '· fotos em', pasta);
