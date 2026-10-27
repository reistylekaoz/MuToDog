// Fotos da rodada 22: toca a gravacao da batalha do castelo feita com o OpenMU daqui (testes/rodada22_vivo.sh, conta
// test400Dl, mestre de Lobos, dona do castelo): alavanca e portao abrindo, catapulta de defesa (janela, pedra no ar e o
// impacto), minimapa do comandante com relogio, pontos e comando, transparencia, caixas da coroa e o interruptor.
// A foto sai um pouco depois de cada marca do console, na ordem (a marca so vale depois da anterior); a marca solta
// (a pedra que vem pela fita) vale em qualquer ponto, porque a fita entrega no tempo dela e pode passar na frente.
// Uso: node testes/tela_r22.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { servir } from './rota_web.mjs';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-r22';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });

const URSOS = '5572736f73000000';
const QUEST = '717565737431446b000000';
const R = `e:5;d:/move_test400Dl_30_93_121;e:5;d:/csestado_5;e:3;d:/csestado_6;e:4;N:219;e:3;O;e:6;N:219;e:3;O;e:4;d:/csestado_7;e:3;d:/move_test400Dl_30_104_185;e:5;N:222;e:3;C:56x148;e:2;C:95x264;e:6;P:C1,B21701;P:C1,B21E0137;P:C1,B21D03966E00;P:C1,B21D05787801;P:C2,B6030000006AB46EBE64B8;P:C2,BB02005D7201503C;G:g1;G:c0;G:m40x40;e:2;G:a;G:a;P:C1,B7020270B0;e:6;P:C1,B2140203EU02;e:4;P:C1,B2150088130000;e:4;P:C1,B21600;e:4;P:C1,B21801${URSOS};e:4;d:/move_test400Dl_30_170_198;e:5;P:C1,B22002030102${URSOS}${QUEST};e:6;d:/csestado_8;e:4`;
const fotos = [
  [/TESTE guerra portao \d+ abre/, 1500, 'g1_portao_aberto'],
  [/TESTE castelo catapulta area 1/, 600, 'g2_catapulta'],
  [/TESTE catapulta pedra 2 voa ate 112/, 800, 'g3_pedra_no_ar', true],
  [/TESTE catapulta pedra caiu em 112/, 150, 'g4_impacto', true],
  [/TESTE guerra comando escolhido 0/, 300, 'g5_comandante'],
  [/TESTE guerra manda comando/, 900, 'g6_minimapa'],
  [/TESTE guerra transparencia 80/, 500, 'g7_transparencia'],
  [/TESTE caixa \["Character/, 400, 'g8_interruptor_ocupado'],
  [/TESTE caixa \["Official seal registration will start/, 400, 'g9_selo'],
  [/TESTE guerra 18/, 600, 'g10_aviso'],
  [/TESTE guerra interruptor 1 Ursos/, 1000, 'g11_interruptor'],
];
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const marcas = [];
page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/TESTE (roteiro (diz|injeta)|mapa mudou|castelo catapulta|guerra|catapulta)|ERROR/.test(t)) console.log(t.slice(0, 160)); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
page.on('crash', () => console.log('[crash] a aba caiu'));
await servir(page, web);
await page.goto('https://mu.local/index.html?auto=test400,x,test400Dl&gravacao=r22&roteiro=' + encodeURIComponent(R));
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
