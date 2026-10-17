// Fotos dos textos do mundo (TextosMU), do cursor e da marca do clique: toca a sessao da cidade
// (test1Dk) com ?chao_teste=1 (itens de mentira em volta e numeros de dano de cada tipo).
// Fotos: dano (nomes e numeros), item (mouse no item excelente), npc (mouse no NPC), alt (Alt
// esconde os nomes do chao), alt_item (com Alt, so o do mouse), clique (marca no chao logo depois do clique).
// Uso: node testes/tela_textos.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-textos';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const tipos = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const marcas = [];
page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/error/i.test(t) && !/UID/.test(t)) console.log(t.slice(0, 200)); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
await page.route('https://mu.local/**', async rota => {
  const arq = path.join(web, new URL(rota.request().url()).pathname.replace(/^\//, '') || 'index.html');
  if (!fs.existsSync(arq)) return rota.fulfill({ status: 404, body: '' });
  await rota.fulfill({ status: 200, body: fs.readFileSync(arq), headers: { 'content-type': tipos[path.extname(arq)] || 'application/octet-stream' } });
});
const cursores = {};
// a foto nao pega o cursor: guarda o cursor do canvas (url da imagem) de cada foto pra comparar
const foto = async n => {
  cursores[n] = await page.evaluate(() => { const c = getComputedStyle(document.querySelector('canvas')).cursor; return c.length + ' ' + c.slice(-60); });
  await page.screenshot({ path: path.join(pasta, `${n}.png`) });
};
const ponto = re => { const t = marcas.find(x => re.test(x)); return t ? t.match(/(\d+),(\d+)/).slice(1).map(Number) : null; };
await page.goto('https://mu.local/index.html?auto=test1,x,test1Dk&gravacao=cidade&chao_teste=1');
for (let i = 0; i < 480 && !marcas.some(t => /TESTE entrou/.test(t)); i++) await page.waitForTimeout(500);
for (let i = 0; i < 60 && !ponto(/tela item/); i++) await page.waitForTimeout(500);
await page.waitForTimeout(1500);
await foto('dano');
const it = ponto(/tela item/), npc = ponto(/tela npc/);
console.log('item', it, 'npc', npc);
if (it) { await page.mouse.move(it[0], it[1]); await page.waitForTimeout(700); await foto('item'); }
if (npc) { await page.mouse.move(npc[0], npc[1]); await page.waitForTimeout(700); await foto('npc'); }
await page.keyboard.press('Alt'); await page.waitForTimeout(700); await foto('alt');
if (it) { await page.mouse.move(it[0], it[1]); await page.waitForTimeout(700); await foto('alt_item'); }
await page.keyboard.press('Alt');
await page.mouse.click(460, 430); await page.waitForTimeout(100); await foto('clique');
await page.waitForTimeout(300); await foto('clique2');
await page.waitForTimeout(300); await foto('clique3');
await nav.close();
for (const [n, c] of Object.entries(cursores)) console.log('cursor', n, c);
console.log('fotos em', pasta);
