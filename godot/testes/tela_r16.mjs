// Fotos da rodada 16: toca dados/gravacao_r16.txt (testgmDk fala com a Mirage em Devias, vai pro templo 1 e
// recebe os C1 BF que o roteiro montou: estado, placar, pontos, Protecao e o resultado). Tira a foto alguns
// segundos depois de cada marca do console.
// Uso: node testes/tela_r16.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { servir } from './rota_web.mjs';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-r16';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });

const R = 'e:2;d:/move_testgmDk_2_197_56;e:6;N:385;e:6;J:0;e:3;J:1;e:2;d:/move_testgmDk_45_138_48;e:12;I:09,0101;e:3;I:01,2c01EUaa5401000001EU2d8a30;e:3;I:06,0c;e:3;S:210;e:2;I:02,0100d2EUEU;e:5;I:07,00d2EU;e:3;I:01,1e01ffff000002000001EU2d8a30;e:6;I:04,020002NOME2d000488130000526976616c00000000002d0100b0040000;e:8';
const fotos = [
  [/TESTE janela templo/, 1500, '1_mirage'], [/TESTE templo efeito reliquia/, 2500, '2_hud'],
  [/TESTE templo efeito 210/, 1200, '3_protecao'], [/TESTE templo placar 2 x 0/, 1200, '4_placar'],
  [/TESTE templo resultado/, 2500, '5_resultado']];
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const marcas = [];
page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/TESTE (roteiro|mapa mudou|templo|janela|Mirage|musica|sem modelo)|ERROR/.test(t)) console.log(t.slice(0, 160)); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
page.on('crash', () => console.log('[crash] a aba caiu'));
await servir(page, web);
await page.goto('https://mu.local/index.html?auto=testgm,x,testgmDk&gravacao=r16&roteiro=' + encodeURIComponent(R));
for (const [re, ms, nome] of fotos) {
  for (let i = 0; i < 2400 && !marcas.some(t => re.test(t)); i++) await page.waitForTimeout(250);
  await page.waitForTimeout(ms);
  await page.screenshot({ path: path.join(pasta, nome + '.png') });
  console.log('foto', nome);
}
await page.close();
await nav.close();
console.log('fotos em', pasta);
