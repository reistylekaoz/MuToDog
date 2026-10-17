// Fotos da troca, da loja pessoal (a minha e a de outro) e do MU Helper: toca a sessao da
// cidade (test1Dk) com ?fotos_janelas=1, que abre cada janela e escreve "TESTE foto X".
// Uso: node testes/tela_trocas.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-trocas';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const tipos = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const fotos = ['troca', 'minha_loja', 'loja_outro', 'helper', 'helper_itens'];
let feitas = 0;
const pendentes = [];
page.on('console', m => {
  const t = m.text();
  const f = t.match(/TESTE foto (\w+)/);
  if (f) pendentes.push(page.screenshot({ path: path.join(pasta, `${f[1]}.png`) }).then(() => { feitas++; console.log('foto', f[1]); }));
  if (/SCRIPT ERROR|pageerror/i.test(t)) console.log(t.slice(0, 300));
});
page.on('pageerror', e => console.log('[pageerror]', e.message));
await page.route('https://mu.local/**', async rota => {
  const arq = path.join(web, new URL(rota.request().url()).pathname.replace(/^\//, '') || 'index.html');
  if (!fs.existsSync(arq)) return rota.fulfill({ status: 404, body: '' });
  await rota.fulfill({ status: 200, body: fs.readFileSync(arq), headers: { 'content-type': tipos[path.extname(arq)] || 'application/octet-stream' } });
});
await page.goto('https://mu.local/index.html?auto=test1,x,test1Dk&gravacao=cidade&fotos_janelas=1');
await page.mouse.move(400, 300);
for (let i = 0; i < 600 && feitas < fotos.length; i++) await page.waitForTimeout(500);
await Promise.all(pendentes);
await nav.close();
console.log('fotos em', pasta, feitas, 'de', fotos.length);
