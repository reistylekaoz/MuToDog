// Fotos da janela da quest (Sevina, quest 0) no navegador, sem servidor: toca
// dados/gravacao_quest_nova.txt (quest1Dw, quest 0 nao comecada) e gravacao_quest_ativa.txt (quest1Elf, ja aceita);
// gravadas com MU_GRAVAR=dados/gravacao_quest_<x>.txt ... -- --auto quest1,quest1,<personagem> --falar Sevina --sair 14.
// As respostas e o botao de concluir sao cliques do mouse.
// Uso: node testes/tela_quest.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-quest';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const tipos = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };

const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const marcas = [];
let page;
async function aba() {
  if (page) await page.close();
  marcas.length = 0;
  page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
  page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/error|erro|TESTE quest/i.test(t) && !/UID|durabilidade/.test(t)) console.log(t.slice(0, 200)); });
  page.on('pageerror', e => console.log('[pageerror]', e.message));
  await page.route('https://mu.local/**', async rota => {
    const arq = path.join(web, new URL(rota.request().url()).pathname.replace(/^\//, '') || 'index.html');
    if (!fs.existsSync(arq)) return rota.fulfill({ status: 404, body: '' });
    await rota.fulfill({ status: 200, body: fs.readFileSync(arq), headers: { 'content-type': tipos[path.extname(arq)] || 'application/octet-stream' } });
  });
}
async function esperar(re, seg) {
  for (let i = 0; i < seg * 2; i++) { if (marcas.some(t => re.test(t))) return true; await page.waitForTimeout(500); }
  return false;
}
const esc = Math.min(1280 / 640, (720 - 51 * 1280 / 640) / 429);
const x0 = 1280 - 190 * esc;   // janela de 190 colada na direita
// sem quest ativa as respostas comecam em y 250, 15 cada
const resposta = i => [x0 + 95 * esc, (250 + 15 * i + 7) * esc];

await aba();
await page.goto('https://mu.local/index.html?auto=quest1,x,quest1Dw&gravacao=quest_nova&falar=Sevina', { waitUntil: 'commit', timeout: 120000 });
console.log('entrou:', await esperar(/TESTE entrou/, 240));
console.log('janela:', await esperar(/TESTE quest npc 0/, 90));
await page.waitForTimeout(1000);
for (let k = 0; k < 2; k++) { await page.mouse.click(...resposta(0)); await page.waitForTimeout(500); }
await page.mouse.move(...resposta(1));
await page.waitForTimeout(600);
await page.screenshot({ path: path.join(pasta, '1-oferta.png') });
await page.mouse.click(...resposta(1));
console.log('pediu pra aceitar:', await esperar(/TESTE quest pedido 0 estado 1/, 10));

await aba();
await page.goto('https://mu.local/index.html?auto=quest1,x,quest1Elf&gravacao=quest_ativa&falar=Sevina', { waitUntil: 'commit', timeout: 120000 });
console.log('entrou:', await esperar(/TESTE entrou/, 240));
console.log('janela ativa:', await esperar(/TESTE quest npc 0 .*estado 1/, 90));
await page.waitForTimeout(1000);
await page.mouse.move(x0 + 95 * esc, (355 + 14) * esc);
await page.waitForTimeout(800);
await page.screenshot({ path: path.join(pasta, '2-ativa.png') });
await page.mouse.click(x0 + 95 * esc, (355 + 14) * esc);
console.log('pediu pra entregar:', await esperar(/TESTE quest pedido 0 estado 1/, 10));
await nav.close();
console.log('fotos em', pasta);
