// Fotos da guilda (rodada 7): toca dados/gravacao_guilda.txt (test400Dl cria a guilda Lobos no Guild Master
// de Devias, test1Dk pede pra entrar e o mestre abre a lista). Fotografa a criacao (pergunta, marca, resumo),
// o pedido de entrada, a janela G (Members e Guild) e os dois com o nome da guilda.
// Uso: node testes/tela_guilda.mjs <pasta-das-fotos> [pasta do export, padrao build/web] [camera=dist,incl,giro]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-guilda';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
const camera = process.argv[4] || '';
fs.mkdirSync(pasta, { recursive: true });
const tipos = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const marcas = [];
page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/TESTE guilda|SCRIPT ERROR/.test(t)) console.log(t.slice(0, 200)); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
await page.route('https://mu.local/**', async rota => {
  const arq = path.join(web, new URL(rota.request().url()).pathname.replace(/^\//, '') || 'index.html');
  if (!fs.existsSync(arq)) return rota.fulfill({ status: 404, body: '' });
  await rota.fulfill({ status: 200, body: fs.readFileSync(arq), headers: { 'content-type': tipos[path.extname(arq)] || 'application/octet-stream' } });
});
const foto = n => page.screenshot({ path: path.join(pasta, `${n}.png`) });
const espera = async re => { for (let i = 0; i < 400 && !marcas.some(t => re.test(t)); i++) await page.waitForTimeout(250); };
await page.goto('https://mu.local/index.html?auto=test400,x,test400Dl&gravacao=guilda&roteiro=' + encodeURIComponent('e:6;G:pintar,Lobos') + (camera ? '&camera=' + camera : ''));
// janelas da direita: escala do JanelaGuilda._ajustar; a caixa de mensagem usa largura / 640
const esc = Math.min(1280 / 640, (720 - 51 * 1280 / 640) / 429), x0 = 1280 - 190 * esc;
const em = (x, y) => [x0 + x * esc, y * esc];
const clica = async (x, y, botao = 'left') => { const [a, b] = em(x, y); await page.mouse.click(a, b, { button: botao }); await page.waitForTimeout(60); };
await espera(/TESTE guilda: janela de criar/);
await page.waitForTimeout(800);
await foto('1_criar_pergunta');
// o roteiro G:pintar (no jogo) aperta Create guild, escreve o nome e pinta a marca: pelo mouse do
// swiftshader os 64 quadrados levam mais de um minuto e a gravacao cria a guilda antes
await espera(/TESTE roteiro guilda \["pintar"/);
await page.mouse.move(...em(150, 300));
await page.waitForTimeout(400);
await foto('2_criar_marca');
await clica(142, 393);  // Next
await page.waitForTimeout(500);
await foto('3_criar_resumo');
await clica(142, 393);  // Next: cria (a resposta vem da gravacao)
await espera(/TESTE guilda: test1Dk pediu pra entrar/);
await page.waitForTimeout(600);
await foto('4_pedido_entrar');
await page.mouse.click(410 + (230 / 4) * 2, 200 + (117 - 50 + 15) * 2);   // OK da caixa
await espera(/TESTE guilda lista/);
await page.waitForTimeout(800);
await page.keyboard.press('g');
await page.waitForTimeout(900);
await foto('5_janela_g_membros');
await clica(40, 79);    // aba Guild
await page.waitForTimeout(600);
await foto('6_janela_g_guilda');
await clica(181, 71 + 200);   // tira o mouse de cima
await page.keyboard.press('g');
await page.waitForTimeout(1500);
await foto('7_nomes');
// outro lado: gira a camera uns 180 graus (setas, 60 graus por segundo) e aproxima com a roda
await page.keyboard.down('ArrowLeft'); await page.waitForTimeout(3000); await page.keyboard.up('ArrowLeft');
await page.mouse.move(640, 300);
for (let i = 0; i < 6; i++) { await page.mouse.wheel(0, -120); await page.waitForTimeout(150); }
await page.waitForTimeout(1200);
await foto('8_girada');
console.log(marcas.filter(t => /guilda/.test(t)).join('\n'));
await nav.close();
console.log('fotos em', pasta);
