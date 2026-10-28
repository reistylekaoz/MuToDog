// Fotos da rodada 23: toca a gravacao da loja de cash feita com o OpenMU daqui (testes/rodada23_vivo.sh, conta
// test400Dl em Lorencia com W Coin e Goblin Points): loja aberta com saldo, caixa do pacote, confirmar, compra feita,
// escolha de preco, compra recusada, presente com nome e mensagem, usar do deposito, item usado e a aba de presentes.
// A foto sai um pouco depois de cada marca do console, na ordem (a marca so vale depois da anterior).
// Uso: node testes/tela_r23.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { servir } from './rota_web.mjs';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-r23';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });

const R = `e:5;d:/move_test400Dl_0_135_128;e:5;H:x;e:4;H:s;H:285x11;H:49x77;H:310x260;H:265x335;H:286x278;e:3;H:s;H:320x242;H:49x110;H:188x139;H:265x335;H:286x278;e:3;H:320x242;H:133x11;H:49x44;H:188x139;H:242x280;H:264x363;H:286x278;e:3;H:320x242;H:209x11;H:317x408;H:317x408;H:432x139;H:321x335;H:n,test400Dk,presente_do_estudo;H:276x324;H:286x278;e:3;H:320x242;H:s;H:598x409;H:284x294;H:284x278;e:4;H:s;H:320x242;H:557x218;e:3;H:s;H:x;e:3`;
const fotos = [
  [/TESTE loja 06/, 1200, 'l1_loja_aberta'],
  [/TESTE loja caixa do pacote 461/, 300, 'l2_pacote'],
  [/TESTE roteiro clica na loja 265x335/, 700, 'l3_confirmar'],
  [/TESTE loja caixa Purchase Completed/, 900, 'l4_compra_feita'],
  [/TESTE roteiro clica na loja 242x280/, 300, 'l5_precos'],
  [/TESTE loja caixa Purchase Failed/, 700, 'l6_recusada'],
  [/TESTE roteiro presente para/, 300, 'l7_presente'],
  [/TESTE loja caixa Gift Delivered/, 700, 'l8_presente_entregue'],
  [/TESTE loja caixa info/, 200, 'l9_info'],
  [/TESTE loja caixa usar/, 200, 'l10_usar'],
  [/TESTE loja caixa Item Used/, 1200, 'l11_usado'],
  [/TESTE loja 0E/, 1200, 'l12_aba_presentes'],
];
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const marcas = [];
page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/TESTE (roteiro (diz|tecla)|mapa mudou|loja (0|caixa|compra|presente|usa))|ERROR/.test(t)) console.log(t.slice(0, 160)); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
page.on('crash', () => console.log('[crash] a aba caiu'));
await servir(page, web);
await page.goto('https://mu.local/index.html?auto=test400,x,test400Dl&gravacao=r23&roteiro=' + encodeURIComponent(R));
let desde = 0;
for (const [re, ms, nome, solta] of fotos) {
  let i = 0, achou = -1;
  for (; i < 2400; i++) { achou = marcas.findIndex((t, k) => k >= (solta ? 0 : desde) && re.test(t)); if (achou >= 0) break; await page.waitForTimeout(250); }
  if (achou < 0) { console.log('sem marca para', nome); continue; }
  if (!solta) desde = achou + 1;
  if (!nome) continue;
  await page.waitForTimeout(ms);
  await page.screenshot({ path: path.join(pasta, nome + '.png') });
  console.log('foto', nome);
}
await page.close();
await nav.close();
console.log('fotos em', pasta);
