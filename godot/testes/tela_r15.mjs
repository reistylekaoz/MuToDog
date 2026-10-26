// Fotos da rodada 15: toca dados/gravacao_r15.txt (testgmDk larga o Lost Map na Lorencia, entra no portao,
// anda no Kalima 1, vai pra Santa Village e pra Arena) e dados/gravacao_duelo.txt (o duelo do testgmDk com o
// socketDk). Tira a foto alguns segundos depois de cada marca do console.
// Uso: node testes/tela_r15.mjs <pasta-das-fotos> [pasta do export, padrao build/web] [mapas|duelo, padrao os dois]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { servir } from './rota_web.mjs';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-r15';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
const quais = process.argv[4] ? [process.argv[4]] : ['mapas', 'duelo'];
fs.mkdirSync(pasta, { recursive: true });
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });

const R = 'T:8;e:2;d:/move_testgmDk_0_180_130;e:5;d:/item_14_28_1;e:3;p;e:3;L:14,28;e:12;K:10;e:2;d:/move_testgmDk_62_210_25;e:15;d:/move_testgmDk_64_101_64;e:15';
const RD = 'e:8;d:/move_testgmDk_0_180_130;e:3;d:/move_socketDk_0_181_130;e:6;d:/duelstart_socketDk;e:6;A:socketDk;e:45;d:/duelend;e:10';
const sessoes = {
  mapas: { quem: 'testgm,x,testgmDk', gravacao: 'r15', roteiro: R, fotos: [
    [/TESTE roteiro larga/, 2500, '1_portao'], [/TESTE mapa mudou 24/, 7000, '2_kalima'], [/TESTE roteiro caca|TESTE nadando true/, 4000, '3_kalima_nado'],
    [/TESTE mapa mudou 62/, 3000, '4_santa'], [/TESTE mapa mudou 64/, 7000, '5_arena']] },
  duelo: { quem: 'testgm,x,testgmDk', gravacao: 'duelo', roteiro: RD, fotos: [
    [/TESTE duelo resultado 0/, 1500, '1_aceitou'], [/TESTE mapa mudou 64/, 6000, '2_arena'], [/TESTE duelo fim/, 1000, '3_fim']] },
};

for (const q of quais) {
  const s = sessoes[q];
  const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
  const marcas = [];
  page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/TESTE (roteiro|mapa mudou|duelo|nadando|pacote|ambiente|sem modelo)|ERROR/.test(t)) console.log(t.slice(0, 160)); });
  page.on('pageerror', e => console.log('[pageerror]', e.message));
  page.on('crash', () => console.log('[crash] a aba caiu'));
  await servir(page, web);
  await page.goto(`https://mu.local/index.html?auto=${s.quem}&gravacao=${s.gravacao}&roteiro=` + encodeURIComponent(s.roteiro));
  for (const [re, ms, nome] of s.fotos) {
    for (let i = 0; i < 2400 && !marcas.some(t => re.test(t)); i++) await page.waitForTimeout(250);
    await page.waitForTimeout(ms);
    await page.screenshot({ path: path.join(pasta, `${q}_${nome}.png`) });
    console.log('foto', nome);
  }
  await page.close();
}
await nav.close();
console.log('fotos em', pasta);
