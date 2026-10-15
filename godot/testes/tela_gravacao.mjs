// Fotos de uma sessao gravada (dados/gravacao_<nome>.txt, feita com MU_GRAVAR) tocada no navegador.
// Uso: node testes/tela_gravacao.mjs <pasta> <nome> <seg>[,<seg>...]  (fotos <nome>-<seg>.png, contando de "entrou")
// WEB=web_novo usa outro export. ANDAR=x,y anda como na gravacao. M=1 abre a janela Mover na primeira foto.
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const [pasta, nome, segs] = process.argv.slice(2);
const web = path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', process.env.WEB || 'web');
fs.mkdirSync(pasta, { recursive: true });
const tipos = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const marcas = [];
page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) { marcas.push(t); console.log(t.slice(0, 160)); } else if (/error/i.test(t) && !/UID/.test(t)) console.log(t.slice(0, 200)); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
await page.route('https://mu.local/**', async rota => {
  const arq = path.join(web, new URL(rota.request().url()).pathname.replace(/^\//, '') || 'index.html');
  if (!fs.existsSync(arq)) return rota.fulfill({ status: 404, body: '' });
  await rota.fulfill({ status: 200, body: fs.readFileSync(arq), headers: { 'content-type': tipos[path.extname(arq)] || 'application/octet-stream' } });
});
await page.goto(`https://mu.local/index.html?auto=test300,x,test300Dk&gravacao=${nome}${process.env.ANDAR ? `&andar=${process.env.ANDAR}` : ""}`);
for (let i = 0; i < 480 && !marcas.some(t => /TESTE entrou/.test(t)); i++) await page.waitForTimeout(500);
const t0 = Date.now();
for (const s of segs.split(',').map(Number)) {
  await page.waitForTimeout(Math.max(0, s * 1000 - (Date.now() - t0)));
  if (process.env.M && s === Number(segs.split(',')[0])) { await page.mouse.click(640, 200); await page.keyboard.press('m'); await page.waitForTimeout(1000); }
  await page.screenshot({ path: path.join(pasta, `${nome}-${s}.png`) });
}
await nav.close();
console.log('fotos em', pasta);
