// Fotos do cliente no navegador sem servidor: a tela de entrada e uma sessao
// gravada do OpenMU (dados/gravacao.txt, feita com MU_GRAVAR) tocada de novo.
// Uso: node testes/tela_jogo.mjs <pasta-das-fotos>
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-jogo';
const web = path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const tipos = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };

const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
async function abrir(busca, nome) {
  const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
  page.marcas = [];
  page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) page.marcas.push(t); if (/error|erro|TESTE/i.test(t) && !/UID/.test(t)) console.log(`[${nome}]`, t.slice(0, 200)); });
  page.on('pageerror', e => console.log('[pageerror]', e.message));
  await page.route('https://mu.local/**', async rota => {
    const arq = path.join(web, new URL(rota.request().url()).pathname.replace(/^\//, '') || 'index.html');
    if (!fs.existsSync(arq)) return rota.fulfill({ status: 404, body: '' });
    await rota.fulfill({ status: 200, body: fs.readFileSync(arq), headers: { 'content-type': tipos[path.extname(arq)] || 'application/octet-stream' } });
  });
  await page.goto(`https://mu.local/index.html${busca}`);
  return page;
}
async function esperar(page, re, seg) {
  for (let i = 0; i < seg * 2; i++) { if (page.marcas.some(t => re.test(t))) return true; await page.waitForTimeout(500); }
  return false;
}

const p1 = await abrir('', 'entrada');
await p1.waitForTimeout(15000);
await p1.screenshot({ path: path.join(pasta, '1-entrada.png') });
await p1.close();

const p2 = await abrir('?auto=test2,x,test2Dk&andar=192,130&gravacao=1', 'jogo');
console.log('entrou:', await esperar(p2, /TESTE entrou/, 240));
await p2.waitForTimeout(3000);
await p2.screenshot({ path: path.join(pasta, '2-cidade.png') });
console.log('andando:', await esperar(p2, /TESTE andando/, 60));
await p2.waitForTimeout(9000);
await p2.screenshot({ path: path.join(pasta, '3-andando.png') });
await p2.waitForTimeout(12000);
await p2.screenshot({ path: path.join(pasta, '4-monstros.png') });
await p2.close();
await nav.close();
console.log('fotos em', pasta);
