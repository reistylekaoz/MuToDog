// Fotos das janelas C (personagem) e D (comandos): toca a sessao da cidade (test1Dk),
// abre C, depois C com o inventario (V) do lado, depois D com o botao Party apertado.
// Uso: node testes/tela_janelas.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-janelas';
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
const foto = n => page.screenshot({ path: path.join(pasta, `${n}.png`) });
const tecla = async k => { await page.keyboard.press(k); await page.waitForTimeout(900); };
await page.goto('https://mu.local/index.html?auto=test1,x,test1Dk&gravacao=cidade');
for (let i = 0; i < 480 && !marcas.some(t => /TESTE entrou/.test(t)); i++) await page.waitForTimeout(500);
await page.waitForTimeout(3000);
await page.mouse.move(640, 300);
await tecla('c'); await foto('personagem');
await tecla('v'); await foto('personagem_inventario');
await tecla('v'); await tecla('c');
await tecla('d'); await foto('comandos');
// janela D colada na direita, escala como no JanelaComandos._ajustar
const esc = Math.min(1280 / 640, (720 - 51 * 1280 / 640) / 429), x0 = 1280 - 190 * esc;
await page.mouse.click(x0 + 95 * esc, (33 + 2 * 30 + 14) * esc); await page.waitForTimeout(700);
await foto('comandos_grupo');
await nav.close();
console.log('fotos em', pasta);
