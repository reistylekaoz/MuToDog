// Fotos do master level no navegador, sem servidor: toca dados/gravacao_master.txt (test400Dk, Blade
// Master 400, faltando 720 de exp master pro nivel 2, caçando Sapi-Unus no Swamp of Calmness);
// gravada com MU_GRAVAR=dados/gravacao_master.txt ... -- --auto test400,test400,test400Dk --helper 100 --sair 110
// (antes: MasterExperience e posicao 205,203 no banco local). Fotos: barra master quase cheia, a subida
// (brilho em volta do personagem) e a dica da barra com o mouse em cima.
// Uso: node testes/tela_master.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-master';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const tipos = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };

const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const marcas = [];
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/error|erro|TESTE (master|experiencia)/i.test(t) && !/UID|durabilidade/.test(t)) console.log(t.slice(0, 200)); });
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
await page.goto('https://mu.local/index.html?auto=test400,x,test400Dk&gravacao=master', { waitUntil: 'commit', timeout: 120000 });
console.log('entrou:', await esperar(/TESTE entrou/, 240));
console.log('master:', await esperar(/TESTE master \{/, 30));
await page.waitForTimeout(1500);
await page.screenshot({ path: path.join(pasta, '1-barra-quase-cheia.png') });
console.log('subiu:', await esperar(/TESTE master subiu/, 120));
await page.waitForTimeout(100);
await page.screenshot({ path: path.join(pasta, '2-subida.png') });
await page.waitForTimeout(300);
await page.screenshot({ path: path.join(pasta, '3-subida.png') });
await page.mouse.move(640, 716);
await page.waitForTimeout(800);
await page.screenshot({ path: path.join(pasta, '4-dica-da-barra.png') });
await nav.close();
console.log('fotos em', pasta);
