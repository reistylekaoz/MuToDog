// Fotos da loja do NPC, dos amigos (F) e do menu (U) no navegador, sem servidor:
// toca dados/gravacao_loja.txt (test1Dk anda ate a Lumen e abre a loja; gravada com
// MU_GRAVAR=... -- --auto test1,test1,test1Dk --andar 127,134 --loja Lumen --so_abrir 1 --sair 16).
// Uso: node testes/tela_loja.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { servir } from './rota_web.mjs';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-loja';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const tipos = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };

const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const marcas = [];
page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/MEDIDA|error|erro|TESTE (loja|janela|falando)/i.test(t) && !/UID|durabilidade/.test(t)) console.log(t.slice(0, 200)); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
await servir(page, web);
// travadas: tarefa do navegador acima de 200 ms (a mesma que o jogador sente como tela parada)
await page.addInitScript(() => { window.__marcas = []; const log = console.log.bind(console); console.log = (...a) => { const t = String(a[0]); if (/TESTE/.test(t) && !/versao/.test(t)) window.__marcas.push([Math.round(performance.now()), t.slice(0, 90)]); log(...a); }; });
await page.addInitScript(() => { window.__trav = []; new PerformanceObserver(l => { for (const e of l.getEntries()) if (e.duration > 200) window.__trav.push([Math.round(e.startTime), Math.round(e.duration)]); }).observe({ entryTypes: ['longtask'] }); });
const travadas = async rot => { const t = await page.evaluate(() => window.__trav.splice(0));
  if (process.env.LINHA) { const m = await page.evaluate(() => window.__marcas.splice(0)); const tudo = [...m.map(x => [x[0], x[1]]), ...t.filter(x => x[1] > 1000).map(x => [x[0], `TRAVOU ${x[1]} ms`])].sort((a, b) => a[0] - b[0]); for (const [ms, txt] of tudo) console.log('  ' + ms, txt); } console.log(`travadas ${rot}: ${t.length}, maior ${Math.max(0, ...t.map(x => x[1]))} ms, soma ${t.reduce((a, x) => a + x[1], 0)} ms`); };
async function esperar(re, seg) {
  for (let i = 0; i < seg * 2; i++) { if (marcas.some(t => re.test(t))) return true; await page.waitForTimeout(500); }
  return false;
}
// MU_FITA=loja_Lumen MU_HEROI=test0Dl: outra fita (gravada ao vivo com --loja <npc> --so_abrir 1, sem --andar)
const fita = process.env.MU_FITA;
await page.goto(fita ? `https://mu.local/index.html?auto=x,x,${process.env.MU_HEROI || 'test0Dl'}&gravacao=${fita}&loja=${fita.split('_')[1]}&so_abrir=1`
  : 'https://mu.local/index.html?auto=test1,x,test1Dk&gravacao=loja&andar=127,134&loja=Lumen&so_abrir=1');
console.log('entrou:', await esperar(/TESTE entrou/, 240));
const quadros = () => Promise.race([page.evaluate(() => new Promise(r => { let n = 0; const t = performance.now(); function f() { n++; if (performance.now() - t > 3000) r((n / 3).toFixed(1)); else requestAnimationFrame(f); } requestAnimationFrame(f); })), new Promise(r => setTimeout(() => r('TRAVOU (20 s sem resposta)'), 20000))]);
console.log('quadros/s antes da loja:', await quadros());
console.log('loja:', await esperar(/TESTE loja \d+ itens/, 60));
console.log('quadros/s com a loja aberta:', await quadros());
// mouse no segundo item da loja (janela de 190 colada a esquerda do inventario)
const esc = Math.min(1280 / 640, (720 - 51 * 1280 / 640) / 429);
const x0 = 1280 - 2 * 190 * esc;
await page.mouse.move(x0 + (15 + 30) * esc, (50 + 10) * esc);
await page.waitForTimeout(600);
await page.screenshot({ path: path.join(pasta, '1-loja.png') });
await travadas('mouse no primeiro item');
for (let i = 0; i < 16; i++) { await page.mouse.move(x0 + (15 + 10 + (i % 8) * 20) * esc, (50 + 10 + Math.floor(i / 8) * 40) * esc); await page.waitForTimeout(500); }
await travadas('mouse passando em 16 itens');
await page.mouse.move(400, 300);
console.log('quadros/s com a loja aberta, mouse fora:', await quadros());
await page.keyboard.press('Escape');
await page.waitForTimeout(1500);
console.log('quadros/s depois de fechar a loja:', await quadros());
await page.keyboard.press('i');
await page.waitForTimeout(1500);
console.log('quadros/s so com o inventario:', await quadros());
await page.keyboard.press('i');
await page.waitForTimeout(1500);
await travadas('fechando');
await page.mouse.move(400, 300);
await page.keyboard.press('Escape');
await page.keyboard.press('f');
await page.waitForTimeout(800);
await page.screenshot({ path: path.join(pasta, '2-amigos.png') });
await page.keyboard.press('f');
await page.keyboard.press('u');
await page.waitForTimeout(800);
await page.screenshot({ path: path.join(pasta, '3-menu.png') });
await nav.close();
console.log('fotos em', pasta);
