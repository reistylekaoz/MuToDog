// Fotos da rodada 26: toca as fitas da tomada da coroa feita com 4 clientes no OpenMU daqui (testes/rodada26_vivo.sh).
// r26b quest1Dk (mestre de Ursos na coroa): placa de ataque com coroa, selo contando, selo tomado e a placa de defesa.
// r26c quest3Dk (battle master no interruptor 1): moldura da skill pronta, Stun, placa de defesa e Cancel Stun.
// r26a test400Dl (mestre de Lobos): placa de defesa com coroa, depois de ataque, catapulta de ataque, pedra e impacto.
// A foto sai um pouco depois de cada marca do console, na ordem; a marca solta (a pedra) vale em qualquer ponto.
// Uso: node testes/tela_r26.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { servir } from './rota_web.mjs';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-r26';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });

// os roteiros sao os do testes/rodada26_vivo.sh (o P: nao roda tocando: a fita ja entrega)
const fitas = [
  ['r26b', 'quest1,x,quest1Dk', 'e:50;P:C1,B21701;e:4;b;e:50;b;e:16;P:C1,B21700;e:4', [
    [/TESTE guerra placa quest1Dk 3/, 1500, 'i1_placa_ataque_mestre'],
    [/Accumulated hour : 2[0-9]seconds/, 300, 'i2_selo_contando'],
    [/seal registration is successful/, 400, 'i3_selo_tomado'],
    [/TESTE guerra placa quest1Dk 7/, 3500, 'i4_placa_defesa_mestre'],
  ]],
  ['r26c', 'quest3,x,quest3Dk', 'e:50;P:C1,B21701;e:4;b;P:C1,B80104;Z:cs;e:6;P:C1,B80102;Z:cs,1;e:30;b;e:12;P:C1,B21700;e:4', [
    [/TESTE guerra placa quest3Dk 0/, 3500, 'h1_placa_ataque'],
    [/TESTE guerra skill da vez 67/, 0, null],
    [/TESTE guerra skill 67 de/, 250, 'h2_stun'],
    [/TESTE guerra placa quest3Dk 6/, 3500, 'h3_placa_defesa'],
    [/TESTE guerra skill 68 de/, 300, 'h4_cancel_stun'],
  ]],
  ['r26a', 'test400,x,test400Dl', 'e:18;d:/csestado_5;e:3;d:/csestado_6;e:5;d:/csestado_7;P:C1,B21701;e:55;b;d:/move_test400Dl_30_63_22;e:6;N:221;e:3;C:56x148;e:2;C:95x264;e:8;b;d:/csestado_8;P:C1,B21700;e:4', [
    [/TESTE guerra placa test400Dl 7/, 3500, 'j1_placa_defesa_mestre'],
    [/TESTE guerra placa test400Dl 3/, 3500, 'j2_placa_ataque_mestre'],
    [/TESTE castelo catapulta area 1/, 600, 'j3_catapulta_ataque'],
    [/TESTE catapulta pedra 1 voa/, 900, 'j4_pedra_no_ar', true],
    [/TESTE catapulta pedra caiu/, 150, 'j5_impacto', true],
  ]],
];
for (const [fita, auto, R, fotos] of fitas) {
  const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
  const marcas = [];
  page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/TESTE (roteiro (diz|injeta|cs)|mapa mudou|castelo catapulta|guerra (placa|skill|mortes|batalha)|catapulta)|ERROR/.test(t)) console.log(`[${fita}] ` + t.slice(0, 160)); });
  page.on('pageerror', e => console.log('[pageerror]', e.message));
  page.on('crash', () => console.log('[crash] a aba caiu'));
  await servir(page, web);
  await page.goto(`https://mu.local/index.html?auto=${auto}&gravacao=${fita}&roteiro=` + encodeURIComponent(R));
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
}
await nav.close();
console.log('fotos em', pasta);
