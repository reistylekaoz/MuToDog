// Fotos dos efeitos de skill no navegador, sem servidor: toca a sessao gravada da
// cidade (test1Dk) com ?efeito_teste=<lista>, que solta cada skill a 2 tiles na
// frente, uma a cada 3 s, em camera lenta (4 vezes). Tira 4 fotos de cada
// (0,12 s, 0,3 s, 0,7 s e 1,3 s depois, no tempo do jogo).
// Uso: node testes/tela_efeitos.mjs <pasta> [export, padrao build/web] [skills, padrao todas] [camera]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-efeitos';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
const lista = (process.argv[4] || '4,3,17,1,2,5,7,8,9,10,12,13,14,38,39,19,41,42,43,47,55,56,24,51,52,26,27,28').split(',');
const camera = process.argv[5] || '10,45,-45';
const monta = process.env.MONTA ? `&monta=${process.env.MONTA}` : ''; // MONTA=red: no Fenrir
const QUADROS = (process.env.QUADROS || '120,300,700,1300').split(',').map(Number); // ms de jogo de cada foto
const LENTO = 4; // o jogo roda 4 vezes mais devagar (?lento=0.25)
fs.mkdirSync(pasta, { recursive: true });
const tipos = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };

const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const marcas = [];
page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/error|erro|efeito sem/i.test(t) && !/UID|durabilidade/.test(t)) console.log(t.slice(0, 240)); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
await page.route('https://mu.local/**', async rota => {
  const arq = path.join(web, new URL(rota.request().url()).pathname.replace(/^\//, '') || 'index.html');
  if (!fs.existsSync(arq)) return rota.fulfill({ status: 404, body: '' });
  await rota.fulfill({ status: 200, body: fs.readFileSync(arq), headers: { 'content-type': tipos[path.extname(arq)] || 'application/octet-stream' } });
});
await page.goto(`https://mu.local/index.html?auto=test1,x,test1Dk&gravacao=cidade&camera=${camera}&efeito_teste=${lista.join(',')}&lento=${1 / LENTO}${monta}`);
for (let i = 0; i < 480 && !marcas.some(t => /TESTE entrou/.test(t)); i++) await page.waitForTimeout(500);
console.log('entrou:', marcas.some(t => /TESTE entrou/.test(t)));
for (const n of lista) {
  const re = new RegExp(`TESTE efeito ${n}$`);
  let achou = false;
  for (let i = 0; i < 1200 && !(achou = marcas.some(t => re.test(t))); i++) await page.waitForTimeout(50);
  if (!achou) { console.log('nao saiu o efeito', n); continue; }
  let antes = 0;
  for (const [k, ms] of QUADROS.entries()) {
    const nome = 'abcdefghij'[k];
    await page.waitForTimeout((ms - antes) * LENTO);
    antes = ms;
    await page.screenshot({ path: path.join(pasta, `${n}-${nome}.png`) });
  }
}
console.log(marcas.slice(-8).join('\n'));
await nav.close();
console.log('fotos em', pasta);
