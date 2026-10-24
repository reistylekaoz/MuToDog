// Fotos da rodada 11: toca dados/gravacao_pet.txt (testgmDl em Devias com o Dark Raven na mao esquerda e o Dark
// Horse; abre a janela do pet nas duas abas, manda o corvo atacar sozinho, depois num alvo, e volta pro normal).
// Fotografa a janela do pet (cavalo e corvo), o corvo voando, o corvo atacando, a lista de skills com a fileira
// das ordens, a marca da ordem no alto da direita e a caixa do corvo na mochila.
// Uso: node testes/tela_pet.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-pet';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const tipos = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });

const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const marcas = [];
page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/TESTE (roteiro|pet (modo|info)|janela pet|corvo)|ERROR/.test(t)) console.log(t.slice(0, 160)); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
await page.route('https://mu.local/**', async rota => {
  const arq = path.join(web, new URL(rota.request().url()).pathname.replace(/^\//, '') || 'index.html');
  if (!fs.existsSync(arq)) return rota.fulfill({ status: 404, body: '' });
  await rota.fulfill({ status: 200, body: fs.readFileSync(arq), headers: { 'content-type': tipos[path.extname(arq)] || 'application/octet-stream' } });
});
const foto = n => page.screenshot({ path: path.join(pasta, `${n}.png`) });
const espera = async re => { for (let i = 0; i < 1600 && !marcas.some(t => re.test(t)); i++) await page.waitForTimeout(250); };
const pausa = ms => page.waitForTimeout(ms);

// o mesmo roteiro da gravacao
const roteiro = 'e:6;P:j;e:3;P:a1;e:4;P:j;P:1;e:16;P:3;e:8;P:0;e:4';
await page.goto('https://mu.local/index.html?auto=testgm,x,testgmDl&gravacao=pet&roteiro=' + encodeURIComponent(roteiro));
await espera(/TESTE corvo de testgmDl/);
await pausa(3000);
await foto('p1_corvo_voando');
await espera(/TESTE janela pet aberta true/);
await pausa(1200);
await foto('p2_janela_cavalo');
await espera(/TESTE roteiro pet aba 1/);
await pausa(800);
await foto('p3_janela_corvo');
await espera(/TESTE roteiro ordem do corvo 1/);
await pausa(2500);
await foto('p4_ordem_aleatoria');
// lista de skills aberta: o quadro da skill atual (x 386..418 da tela de 640) e a fileira das ordens em cima
await page.mouse.click(804, 662);
await pausa(800);
await page.mouse.move(353 * 2 + 32 * 2 + 30, 720 - 102 - 77 * 2 + (352 - 429 + 77) * 2 + 30);
await pausa(800);
await foto('p5_lista_ordens');
await page.mouse.click(804, 662 - 77 * 2);
await pausa(400);
for (let i = 0; i < 6; i++) { await pausa(1500); await foto(`p6_ataque_${i}`); }
await espera(/TESTE roteiro ordem do corvo 3/);
await pausa(1500);
await foto('p7_ordem_alvo');
// a caixa do corvo na mochila (slot 1: 135,87 46x66 na janela de 190 escalada a 1,44 na direita)
await page.keyboard.press('v');
await pausa(800);
await page.mouse.move(1280 - 190 * 1.44 + 158 * 1.44, 120 * 1.44);
await pausa(1200);
await foto('p8_caixa_corvo');
await nav.close();
console.log('fotos em', pasta);
