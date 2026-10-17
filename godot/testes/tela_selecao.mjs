// Fotos da escolha de personagem (selecao.gd): entra com a conta sem escolher personagem,
// fotografa a tela, escolhe o do meio, abre a janela de criar (DK e depois a Summoner) e o
// Delete ate a senha (cancela; nada e apagado).
// Toca dados/gravacao_selecao.txt (a lista do test1, sem servidor).
// Uso: node testes/tela_selecao.mjs <pasta-das-fotos> [pasta do export]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-selecao';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
const conta = 'test1';
fs.mkdirSync(pasta, { recursive: true });
const tipos = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const marcas = [];
page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) { marcas.push(t); console.log(t.slice(0, 160)); } if (/error/i.test(t) && !/UID/.test(t)) console.log(t.slice(0, 200)); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
await page.route('https://mu.local/**', async rota => {
  const arq = path.join(web, new URL(rota.request().url()).pathname.replace(/^\//, '') || 'index.html');
  if (!fs.existsSync(arq)) return rota.fulfill({ status: 404, body: '' });
  await rota.fulfill({ status: 200, body: fs.readFileSync(arq), headers: { 'content-type': tipos[path.extname(arq)] || 'application/octet-stream' } });
});
const foto = n => page.screenshot({ path: path.join(pasta, `${n}.png`) });
const espera = ms => page.waitForTimeout(ms);
const clica = async (x, y) => { await page.mouse.move(x, y); await espera(200); await page.mouse.down(); await espera(120); await page.mouse.up(); await espera(900); };
await page.goto(`https://mu.local/index.html?auto=${conta},x,&gravacao=selecao`);
for (let i = 0; i < 480 && !marcas.some(t => /TESTE boneco|TESTE selecao 0/.test(t)); i++) await espera(500);
await espera(4000);
await foto('selecao');
// escala do cliente: 1280 x 720 -> 1,2; tela de 1066,7 x 600 em unidades do MU
const e = Math.min(Math.max(Math.min(1280 / 800, 720 / 600), 1), 2), W = 1280 / e, H = 720 / e;
const bonecos = marcas.map(t => t.match(/TESTE boneco (\d) na tela (\d+) (\d+)/)).filter(Boolean).map(m => [+m[2], +m[3]]);
if (bonecos.length) {
  const b = bonecos[Math.floor(bonecos.length / 2)];
  await clica(b[0], b[1]); await espera(1500); await foto('escolhido');
}
const topo = Math.round(567 / 600 * H) - 41;
const bt = { criar: [22 + 27, topo + 15], apagar: [W - 22 - 27, topo + 15] };
await clica(bt.criar[0] * e, bt.criar[1] * e); await espera(2500); await foto('criar');
const jx = Math.round((W - 454) / 2), jy = Math.round((H - 406) / 2);
await clica((jx + 346 + 54) * e, (jy + 209 + 13) * e); await espera(2500); await foto('criar_summoner');
await clica((jx + 400 + 27) * e, (jy + 325 + 15) * e);  // Cancel
if (bonecos.length) {
  await clica(bt.apagar[0] * e, bt.apagar[1] * e); await foto('apagar');
  const mx = Math.round((W - 352) / 2), my = Math.round((H - 113) / 2);
  await clica((mx + 98 + 27) * e, (my + 72 + 15) * e); await foto('apagar_senha');
  await clica((mx + 264 + 27) * e, (my + 72 + 15) * e);  // Cancel
  await espera(500); await foto('depois');
}
await nav.close();
console.log('fotos em', pasta);
