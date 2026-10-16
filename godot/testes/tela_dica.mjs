// Fotos da caixa de informacao do item (DicaItem): toca a sessao gravada dados/gravacao_skill.txt (testgmDk),
// abre o inventario e passa o mouse em cada peca equipada e em itens da mochila.
// Uso: node testes/tela_dica.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-dica';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const tipos = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const marcas = [];
page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/error|erro/i.test(t) && !/UID/.test(t)) console.log(t.slice(0, 200)); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
await page.route('https://mu.local/**', async rota => {
  const arq = path.join(web, new URL(rota.request().url()).pathname.replace(/^\//, '') || 'index.html');
  if (!fs.existsSync(arq)) return rota.fulfill({ status: 404, body: '' });
  await rota.fulfill({ status: 200, body: fs.readFileSync(arq), headers: { 'content-type': tipos[path.extname(arq)] || 'application/octet-stream' } });
});
async function esperar(re, seg) {
  for (let i = 0; i < seg * 2; i++) { if (marcas.some(t => re.test(t))) return true; await page.waitForTimeout(500); }
  return false;
}
await page.goto('https://mu.local/index.html?auto=testgm,x,testgmDk&gravacao=skill');
console.log('entrou:', await esperar(/TESTE entrou/, 240));
await page.waitForTimeout(3000);
await page.keyboard.press('i');
await page.waitForTimeout(800);
const esc = Math.min(1280 / 640, (720 - 51 * 1280 / 640) / 429);
const x0 = 1280 - 190 * esc;
// pontos no espaco da janela (190 x 429): equipados e mochila (grade em 15,200, casa de 20)
const pontos = { arma: [38, 120], escudo: [158, 120], elmo: [98, 67], armadura: [98, 120], asa: [150, 67],
  luvas: [38, 173], botas: [158, 173], anel: [128, 164], colar: [68, 101], pet: [38, 67],
  mochila1: [25, 250], mochila2: [105, 290], mochila3: [165, 270] };
for (const [nome, [x, y]] of Object.entries(pontos)) {
  await page.mouse.move(x0 + x * esc, y * esc);
  await page.waitForTimeout(500);
  await page.screenshot({ path: path.join(pasta, `${nome}.png`) });
}
await nav.close();
console.log('fotos em', pasta);
