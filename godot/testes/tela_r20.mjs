// Fotos da rodada 20: toca dados/gravacao_r20.txt, a gravacao do OpenMU daqui (testes/rodada20_vivo.sh: testgmElf
// no Crywolf, /crywolf pula as esperas, pisa no altar 1, fala com ele e faz o contrato, a luta comeca com o painel, a
// estatua, as balistas e o Balgass, e termina com a faixa e a caixa do resultado).
// Tira a foto alguns segundos depois de cada marca do console.
// Uso: node testes/tela_r20.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { servir } from './rota_web.mjs';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-r20';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });

const R = fs.readFileSync(path.join(path.dirname(new URL(import.meta.url).pathname), 'rodada20_vivo.sh'), 'utf8').match(/ROTEIRO:-'([^']+)'/)[1];
const fotos = [
  [/TESTE crywolf estado 3/, 2500, '1_pronto'], [/TESTE caixa \["You have been registered/, 300, '2_altar'],
  [/TESTE crywolf estado 4/, 500, '3_luta'], [/TESTE crywolf estatua 51/, 100, '4_estatua'],
  [/TESTE crywolf faixa/, 700, '5_faixa'], [/TESTE crywolf caixa do resultado/, 1200, '6_resultado']];
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const marcas = [];
page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/TESTE (roteiro|mapa mudou|crywolf|janela|musica|sem modelo|pacote|caixa)|ERROR/.test(t)) console.log(t.slice(0, 160)); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
page.on('crash', () => console.log('[crash] a aba caiu'));
await servir(page, web);
await page.goto('https://mu.local/index.html?auto=testgm,x,testgmElf&gravacao=r20&roteiro=' + encodeURIComponent(R));
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
