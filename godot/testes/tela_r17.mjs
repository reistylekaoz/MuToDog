// Fotos da rodada 17: toca dados/gravacao_r17.txt (testgmDk pega o Mirror of Dimensions, fala com o Lugard em
// Devias, entra no Doppelganger do OpenMU e espera os 3 monstros chegarem no circulo, uns 3 min). Tira a foto alguns segundos
// depois de cada marca do console; Enter fecha a caixa do aviso antes da foto da moldura.
// Uso: node testes/tela_r17.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { servir } from './rota_web.mjs';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-r17';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });

const R = 'e:2;d:/item_14_111;e:3;p;e:4;d:/move_testgmDk_2_233_69;e:6;N:540;e:15;D:0;e:8;d:/skipwait;e:4;d:/skipwait;e:4;d:/skipwait;e:3;e:200';
const fotos = [
  [/TESTE janela doppelganger/, 1500, '1_lugard'], [/TESTE doppel estado 2/, 2500, '2_aviso'],
  [/TESTE doppel estado 2/, 40000, '3_moldura', 'Enter'], [/TESTE doppel passaram 2\/3/, 1200, '4_dois_passaram'],
  [/TESTE doppel resultado/, 2500, '5_resultado']];
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const marcas = [];
page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/TESTE (roteiro|mapa mudou|doppel|janela|musica|sem modelo)|ERROR/.test(t)) console.log(t.slice(0, 160)); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
page.on('crash', () => console.log('[crash] a aba caiu'));
await servir(page, web);
await page.goto('https://mu.local/index.html?auto=testgm,x,testgmDk&gravacao=r17&roteiro=' + encodeURIComponent(R));
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
