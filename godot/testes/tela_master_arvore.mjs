// Fotos da janela A (arvore de skills master) no navegador, sem servidor: toca dados/gravacao_master_arvore.txt
// (test400Dk, Blade Master master 2, com a 300 no 10, a 302 e a 304 no 1), gravada com
// MU_GRAVAR=dados/gravacao_master_arvore.txt ... -- --auto test400,test400,test400Dk --sair 12.
// Fotos: a arvore inteira, a dica de uma skill liberada, a dica de uma bloqueada (pedidos em vermelho),
// a confirmacao do clique e o aviso de skill bloqueada.
// Uso: node testes/tela_master_arvore.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-master-arvore';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const tipos = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const L = 1280, A = 720;

const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const marcas = [];
const page = await nav.newPage({ viewport: { width: L, height: A } });
page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/error|erro|TESTE master/i.test(t) && !/UID|durabilidade/.test(t)) console.log(t.slice(0, 200)); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
await page.route('https://mu.local/**', async rota => {
  const arq = path.join(web, new URL(rota.request().url()).pathname.replace(/^\//, '') || 'index.html');
  if (!fs.existsSync(arq)) return rota.fulfill({ status: 404, body: '' });
  await rota.fulfill({ status: 200, body: fs.readFileSync(arq), headers: { 'content-type': tipos[path.extname(arq)] || 'application/octet-stream' } });
});
async function esperar(re, seg) {
  for (let i = 0; i < seg * 10; i++) { if (marcas.some(t => re.test(t))) return true; await page.waitForTimeout(100); }
  return false;
}
// a janela tem 640 x 428 escalada pra caber acima da barra (JanelaMaster._ajustar)
const esc = Math.min(L / 640, (A - 51 * L / 640) / 428), x0 = (L - 640 * esc) / 2;
const tela = (x, y) => [x0 + x * esc, y * esc];
// centro do icone: coluna (indice - 1) % 4, linha = rank - 1, grupo 0/1/2
const icone = (indice, grupo, rank) => tela([11, 221, 431][grupo] + ((indice - 1) % 4) * 49 + 18, 55 + (rank - 1) * 41 + 19);

await page.goto('https://mu.local/index.html?auto=test400,x,test400Dk&gravacao=master_arvore', { waitUntil: 'commit', timeout: 120000 });
console.log('entrou:', await esperar(/TESTE entrou/, 240));
console.log('lista master:', await esperar(/TESTE master skills/, 30));
await page.waitForTimeout(1500);
await page.locator('canvas').focus();
await page.keyboard.press('KeyA');
await page.waitForTimeout(800);
await page.mouse.move(5, 700);
await page.waitForTimeout(300);
await page.screenshot({ path: path.join(pasta, '1-arvore.png') });
await page.mouse.move(...icone(6, 0, 2));     // 302 Maximum SD increase, nivel 1
await page.waitForTimeout(500);
await page.screenshot({ path: path.join(pasta, '2-dica-302.png') });
await page.mouse.move(...icone(41, 1, 2));    // 326 Cyclone Strengthener, bloqueada
await page.waitForTimeout(500);
await page.screenshot({ path: path.join(pasta, '3-dica-326-bloqueada.png') });
await page.mouse.click(...icone(8, 0, 2));    // 304: pede confirmacao
await page.waitForTimeout(500);
await page.screenshot({ path: path.join(pasta, '4-confirmar-304.png') });
await page.keyboard.press('Escape');
await page.waitForTimeout(300);
await page.mouse.click(...icone(9, 0, 3));    // 305: aviso
await page.waitForTimeout(500);
await page.screenshot({ path: path.join(pasta, '5-aviso-305.png') });
await nav.close();
console.log('fotos em', pasta);
