// Fotos da rodada 25: toca a gravacao feita com o OpenMU daqui (testes/rodada25_vivo.sh, test400Dl, mestre de Lobos,
// dona do castelo): janela J dos comandos de chat, Golden Archer com a Rena, invasao do dragao (sombra e meteoros),
// relogio do Battle Soccer, a bandeira de Lobos no Valley of Loren, Gatekeeper do mestre (antes e depois do preco),
// Chain Lightning e a chegada na Land of Trials.
// A foto sai um pouco depois de cada marca do console. A fita corre na frente do roteiro no navegador, entao as
// marcas que vem dela (solta) valem em qualquer ponto; as do roteiro (janela J) vao na ordem.
// Uso: node testes/tela_r25.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { servir } from './rota_web.mjs';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-r25';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });

// o mesmo roteiro do rodada25_vivo.sh: os passos Z: abrem as janelas; o que veio do servidor sai da fita
const R = [
  'e:6;e:2;Z:j;e:3;Z:j,/help;e:2;Z:jx;e:3',
  'd:/move_test400Dl_0_175_123;e:5;d:/item_14_21;e:3;p;e:4;N:236;e:8;Z:arqueiro,90x295;e:4;Z:arqueiro,x;e:2',
  'P:C1,0B0101;e:8;P:C1,0B0003;e:3;P:C1,F3225802;e:3',
  'd:/move_test400Dl_30_139_104;e:6;N:220;e:10;Z:gate,60x115;e:3;Z:gate,120x185;e:1;Z:gate,95x230;e:3',
  'P:C1,B901010000;e:2;P:C1,B901010005;e:2;P:C1,690025001000MEU;e:2;P:C1,BF0A00D7MEU0100MEU;e:2;P:C1,BAMEU2805;e:2;P:C1,F6030500010000000000;e:2',
  'Z:teclas;e:2;Z:gate,95x330;e:8',
].join(';');
const fotos = [
  [/TESTE roteiro j$/, 1200, 'a1_comandos_chat'],
  [/TESTE roteiro j,\/help/, 900, 'a2_parametros'],
  [/TESTE arqueiro registradas 0 na_mochila/, 600, 'a3_golden_archer', true],
  [/TESTE invasao true evento 1/, 3000, 'a4_invasao', true],
  [/TESTE futebol tempo 600/, 900, 'a5_futebol', true],
  [/TESTE marca castelo/, 2500, 'a6_bandeira', true],
  [/TESTE gatekeeper tipo 3/, 900, 'a7_gatekeeper', true],
  [/TESTE corrente skill 215/, 500, 'a8_chain_lightning', true],
  [/TESTE mapa mudou 31/, 6000, 'a9_land_of_trials', true],
];
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const marcas = [];
page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/TESTE (roteiro|mapa mudou|gatekeeper|arqueiro|fichas|comando|invasao|futebol|corrente|marca)|ERROR/.test(t)) console.log(t.slice(0, 160)); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
page.on('crash', () => console.log('[crash] a aba caiu'));
await servir(page, web);
await page.goto('https://mu.local/index.html?auto=test400,x,test400Dl&gravacao=r25&roteiro=' + encodeURIComponent(R));
let desde = 0;
for (const [re, ms, nome, solta] of fotos) {
  let achou = -1;
  for (let i = 0; i < 2400; i++) { achou = marcas.findIndex((t, k) => k >= (solta ? 0 : desde) && re.test(t)); if (achou >= 0) break; await page.waitForTimeout(250); }
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
