// Fotos da rodada 19: toca dados/gravacao_r19b.txt, a gravacao do OpenMU daqui (testgmDk veste o Moonstone
// Pendant, fala com o Gateway Machine no Kanturu 2, entra na torre, a Maya sobe, luta e joga a tempestade e a
// chuva de pedras) com um D1 04 0 (falhou) posto a mao aos 104 s (entre a tempestade e a chuva), pra foto do resultado.
// Tira a foto alguns segundos depois de cada marca do console.
// Uso: node testes/tela_r19.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { servir } from './rota_web.mjs';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-r19';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });

const R = 'e:2;d:/item_13_38;e:3;p;e:3;u:13,38;e:2;d:/startkanturu;e:2;d:/move_testgmDk_38_141_185;e:8;N:367;e:6;Q:1;e:10;d:/skipwait;e:8;d:/skipwait;e:8;d:/skipwait;e:200';
const fotos = [
  [/TESTE kanturu info/, 1200, '1_gateway'], [/TESTE kanturu estado 2 detalhe 2/, 2500, '2_maya_sobe'],
  [/TESTE kanturu tempo/, 3000, '3_luta'], [/TESTE kanturu ataque da maya 0/, 700, '4_tempestade'],
  [/TESTE kanturu resultado/, 3000, '5_falhou'], [/TESTE kanturu ataque da maya 1/, 2200, '6_chuva']];
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const marcas = [];
page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/TESTE (roteiro|mapa mudou|kanturu|janela|musica|sem modelo|pacote)|ERROR/.test(t)) console.log(t.slice(0, 160)); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
page.on('crash', () => console.log('[crash] a aba caiu'));
await servir(page, web);
await page.goto('https://mu.local/index.html?auto=testgm,x,testgmDk&gravacao=r19b&roteiro=' + encodeURIComponent(R));
for (const [re, ms, nome, tecla] of fotos) {
  for (let i = 0; i < 4000 && !marcas.some(t => re.test(t)); i++) await page.waitForTimeout(250);
  await page.waitForTimeout(ms);
  if (tecla) { await page.keyboard.press(tecla); await page.waitForTimeout(800); }
  await page.screenshot({ path: path.join(pasta, nome + '.png') });
  console.log('foto', nome);
}
await page.close();
await nav.close();
console.log('fotos em', pasta);
