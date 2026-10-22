// Fotos das quests novas (Elf Soldier, F6) no navegador, sem servidor. Toca duas fitas do test1Dk:
// dados/gravacao_qn_lista.txt: conversa, "Accept a quest.", a lista e a oferta da Spider Hunt
//   (MU_GRAVAR=dados/gravacao_qn_lista.txt ... -- --auto test1,test1,test1Dk --falar Elf --resposta 2 --quest_nova 1 --sair 16)
// dados/gravacao_qn_ativa.txt: com a quest aceita, o passo com o que pede e o estado pela janela T
//   (MU_GRAVAR=dados/gravacao_qn_ativa.txt ... --falar Elf --resposta 2 --quest_nova 1,f,e --sair 20)
// As setas, as respostas, a tecla T e a linha da janela T sao cliques e teclas de verdade.
// Uso: node testes/tela_quest_nova.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-quest-nova';
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
  page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/error|erro|TESTE (F6|quest)/i.test(t) && !/UID|durabilidade/.test(t)) console.log(t.slice(0, 200)); });
  page.on('pageerror', e => console.log('[pageerror]', e.message));
  await page.route('https://mu.local/**', async rota => {
    const arq = path.join(web, new URL(rota.request().url()).pathname.replace(/^\//, '') || 'index.html');
    if (!fs.existsSync(arq)) return rota.fulfill({ status: 404, body: '' });
    await rota.fulfill({ status: 200, body: fs.readFileSync(arq), headers: { 'content-type': tipos[path.extname(arq)] || 'application/octet-stream' } });
  });
}
async function esperar(re, seg) {
  for (let i = 0; i < seg * 10; i++) { if (marcas.some(t => re.test(t))) return true; await page.waitForTimeout(100); }
  return false;
}
const esc = Math.min(1280 / 640, (720 - 51 * 1280 / 640) / 429);
const x0 = 1280 - 190 * esc;   // janelas de 190 coladas na direita
const ponto = (x, y) => [x0 + x * esc, y * esc];

await aba();
await page.goto('https://mu.local/index.html?auto=test1,x,test1Dk&gravacao=qn_lista&falar=Elf', { waitUntil: 'commit', timeout: 120000 });
console.log('entrou:', await esperar(/TESTE entrou/, 240));
console.log('lista:', await esperar(/TESTE F6 0A/, 90));
await page.mouse.move(...ponto(95, 210));
await page.waitForTimeout(250);
await page.screenshot({ path: path.join(pasta, '1-lista.png') });
console.log('oferta:', await esperar(/TESTE F6 0B 120000/, 30));
await page.waitForTimeout(800);
await page.screenshot({ path: path.join(pasta, '2-oferta.png') });
for (let k = 0; k < 4; k++) { await page.mouse.click(...ponto(161, 177)); await page.waitForTimeout(300); }
await page.mouse.move(...ponto(95, 258));
await page.waitForTimeout(600);
await page.screenshot({ path: path.join(pasta, '3-respostas.png') });
await page.mouse.click(...ponto(95, 258));
console.log('aceitou:', await esperar(/TESTE quest nova 120000 resposta 1/, 10));

await aba();
await page.goto('https://mu.local/index.html?auto=test1,x,test1Dk&gravacao=qn_ativa&falar=Elf', { waitUntil: 'commit', timeout: 120000 });
console.log('entrou:', await esperar(/TESTE entrou/, 240));
console.log('passo com pedidos:', await esperar(/TESTE F6 0C 120001/, 90));
await page.waitForTimeout(800);
await page.screenshot({ path: path.join(pasta, '4-pedidos.png') });
console.log('estado 1B:', await esperar(/TESTE F6 1B 120001/, 30));
await page.keyboard.press('Escape');
await page.waitForTimeout(400);
await page.keyboard.press('t');
await page.waitForTimeout(600);
await page.mouse.click(...ponto(95, 58 + 7));
await page.waitForTimeout(800);
await page.mouse.move(...ponto(104, 410));
await page.waitForTimeout(400);
await page.screenshot({ path: path.join(pasta, '5-janela-t.png') });
await page.mouse.click(...ponto(80, 38));
await page.waitForTimeout(600);
await page.screenshot({ path: path.join(pasta, '6-troca-de-classe.png') });
await page.mouse.click(...ponto(140, 38));
await page.waitForTimeout(600);
await page.screenshot({ path: path.join(pasta, '7-castelo.png') });
await page.mouse.click(...ponto(30, 38));
await page.waitForTimeout(300);
await page.mouse.click(...ponto(104, 406));
await page.waitForTimeout(600);
await page.screenshot({ path: path.join(pasta, '8-desistir.png') });
await nav.close();
console.log('fotos em', pasta);
