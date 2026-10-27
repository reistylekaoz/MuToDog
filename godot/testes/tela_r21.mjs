// Fotos da rodada 21: toca as tres gravacoes do castelo feitas com o OpenMU daqui (testes/rodada21_vivo.sh, conta test400Dl,
// mestre da guilda Lobos):
//   r21a: castelo sem dono, inscreve a guilda, entrega o Sign of Lord, ve a lista e desiste;
//   r21b: Lobos dona, lista do aviso no Guardsman e a janela do Senior (portoes, estatuas e impostos);
//   r21c: Lobos dona no Ready, a alavanca abre e fecha o portao.
// A foto sai um pouco depois de cada marca do console, na ordem (a marca so vale depois da anterior). A fita toca no
// tempo dela, entao a lista chega antes do clique na aba: a marca sem nome so serve pra andar na ordem.
// Uso: node testes/tela_r21.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { servir } from './rota_web.mjs';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-r21';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });

const sessoes = [
  ['r21a', 'e:4;d:/csestado_1;e:3;N:224;e:5;C:95x95;e:3;C:95x131;e:4;O;e:2;C:30x405;e:2;d:/csestado_3;e:3;N:224;e:5;C:95x95;e:3;C:95x210;e:4;O;e:2;C:150x95;e:4;C:30x405;e:2;d:/csestado_1;e:3;N:224;e:5;C:150x95;e:4;C:95x380;e:2;O;e:4;C:30x405;e:2;d:/csestado_2;e:3', [
    [/TESTE castelo guarda estado 1/, 1500, 'a1_status'], [/TESTE caixa \["Castle Siege registration is successful/, 400, 'a2_inscrita'],
    [/TESTE castelo marcas registradas 1/, 400, 'a3_marca'], [/TESTE castelo inscritas \["Lobos:1"\]/, 0, null], [/TESTE castelo aba 2/, 1200, 'a4_lista'],
    [/TESTE caixa \["Abandon/, 400, 'a5_desistir']]],
  ['r21b', 'e:4;d:/csestado_3;e:3;N:224;e:5;C:95x95;e:3;C:95x210;e:4;C:150x95;e:4;C:30x405;e:2;d:/csestado_1;e:3;N:224;e:5;C:150x95;e:4;C:95x380;e:2;O;e:4;C:30x405;e:2;d:/csestado_5;e:3;N:224;e:5;C:150x95;e:4;C:30x405;e:2;d:/move_test400Dl_30_179_211;e:6;N:223;e:6;C:69x161;e:3;C:95x40;e:3;C:150x40;e:4;C:30x405;e:2;d:/csestado_2;e:3', [
    [/TESTE castelo lados/, 0, null], [/TESTE castelo aba 2/, 1200, 'b1_aviso'], [/TESTE castelo escolhido/, 600, 'b2_portao'],
    [/TESTE castelo aba 1/, 1200, 'b3_estatua'], [/TESTE castelo aba 2/, 1200, 'b4_impostos']]],
  ['r21c', 'e:4;d:/csestado_6;e:6;N:219;e:4;O;e:6;N:219;e:4;O;e:5;d:/csestado_2;e:4;d:/move_test400Dl_30_93_64;e:4', [
    [/TESTE caixa \["Castle Gate Switch/, 400, 'c1_alavanca'], [/TESTE castelo portao 525 aberto/, 1500, 'c2_aberto']]],
];
for (const [fita, R, fotos] of sessoes) {
  const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
  const marcas = [];
  page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/TESTE (roteiro diz|mapa mudou|castelo (guarda|resposta|lados|inscritas|escolhido|aba|portao))|ERROR/.test(t)) console.log(t.slice(0, 160)); });
  page.on('pageerror', e => console.log('[pageerror]', e.message));
  page.on('crash', () => console.log('[crash] a aba caiu'));
  await servir(page, web);
  await page.goto('https://mu.local/index.html?auto=test400,x,test400Dl&gravacao=' + fita + '&roteiro=' + encodeURIComponent(R));
  let desde = 0;
  for (const [re, ms, nome] of fotos) {
    let i = 0, achou = -1;
    for (; i < 2400; i++) { achou = marcas.findIndex((t, k) => k >= desde && re.test(t)); if (achou >= 0) break; await page.waitForTimeout(250); }
    if (achou < 0) { console.log('sem marca para', nome); continue; }
    desde = achou + 1;
    if (!nome) continue;
    await page.waitForTimeout(ms);
    await page.screenshot({ path: path.join(pasta, nome + '.png') });
    console.log('foto', nome);
  }
  await page.close();
}
await nav.close();
console.log('fotos em', pasta);
