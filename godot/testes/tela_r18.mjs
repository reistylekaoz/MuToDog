// Fotos da rodada 18: toca dados/gravacao_r18b.txt, a gravacao do OpenMU daqui (testgmDk pega o Gaion's Order,
// fala com o Jerint em Devias, entra no Imperial Fortress 1 com neblina, espera e corre contra o tempo) com um
// F7 06 1 (zona limpa) posto a mao aos 110 s, pra foto da caixa do resultado (o /killall trava o OpenMU aqui).
// Tira a foto alguns segundos depois de cada marca do console.
// Uso: node testes/tela_r18.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { servir } from './rota_web.mjs';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-r18';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });

const R = 'e:2;d:/item_14_102;e:3;p;e:4;d:/move_testgmDk_2_229_218;e:6;N:522;e:8;Y:0;e:10;d:/skipwait;e:4;d:/skipwait;e:6;e:150';
const fotos = [
  [/TESTE janela imperial/, 1200, '1_jerint'], [/TESTE imperial entrou/, 4000, '2_neblina'],
  [/TESTE imperial tempo/, 3000, '3_espera'], [/TESTE imperial tempo tipo 2/, 8000, '4_corrida'],
  [/TESTE imperial resultado/, 1500, '5_zona_limpa']];
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const marcas = [];
page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/TESTE (roteiro|mapa mudou|imperial|janela|musica|sem modelo|pacote)|ERROR/.test(t)) console.log(t.slice(0, 160)); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
page.on('crash', () => console.log('[crash] a aba caiu'));
await servir(page, web);
await page.goto('https://mu.local/index.html?auto=testgm,x,testgmDk&gravacao=r18b&roteiro=' + encodeURIComponent(R));
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
