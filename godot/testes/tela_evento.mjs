// Fotos das rodadas 12, 13 e 14: toca dados/gravacao_ds.txt (testgmElf no Charon em Noria, entra no Devil Square 7,
// contagem, caca e placar) e dados/gravacao_bc.txt (testgmDk no Mensageiro em Devias, entra no Blood Castle 8,
// contagem, janela do tempo e o resultado) e dados/gravacao_cc.txt (testgmDk usa a Armor of Guardsman em
// Devias, entra no Chaos Castle 7, contagem, comeco e o resultado). Fotografa a janela de entrada, a contagem, o mapa e o placar.
// Uso: node testes/tela_evento.mjs <pasta-das-fotos> [pasta do export, padrao build/web] [ds|bc|cc, padrao os tres]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { servir } from './rota_web.mjs';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-evento';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
const quais = process.argv[4] ? [process.argv[4]] : ['ds', 'bc', 'cc'];
fs.mkdirSync(pasta, { recursive: true });
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });

const sessoes = {
  ds: { quem: 'testgm,x,testgmElf', roteiro: 'd:/startds;e:3;n:Charon;e:8;d:/skipwait;e:4;d:/skipwait;K:300', npc: 'ds',
    contagem: /TESTE evento contagem 0/, dentro: /TESTE pacote mapa 0 ok/, fim: /TESTE ds placar/ },
  bc: { quem: 'testgm,x,testgmDk', roteiro: 'd:/item_13_18_8;e:2;p;e:3;d:/startbc;e:3;n:Messenger;e:8;d:/skipwait;e:4;d:/skipwait;e:10',
    npc: 'bc', contagem: /TESTE evento contagem 3/, dentro: /TESTE laco ibloodcastle/, fim: /TESTE bc resultado/ },
  cc: { quem: 'testgm,x,testgmDk', roteiro: 'T:8;e:2;d:/item_13_29;e:3;p;e:3;d:/startcc;e:3;u:13,29;e:3;O;e:8;d:/skipwait;K:300',
    janela: /TESTE cc abre/, contagem: /TESTE evento contagem 10/, dentro: /TESTE laco ichaoscastle/, fim: /TESTE cc resultado/ },
};

for (const q of quais) {
  const s = sessoes[q];
  const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
  const marcas = [];
  page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/TESTE (roteiro|evento|janela evento|ds placar|bc (estado [02]|resultado)|cc |caos|pacote|sem modelo|terreno|mapa mudou)|ERROR/.test(t)) console.log(t.slice(0, 160)); });
  page.on('pageerror', e => console.log('[pageerror]', e.message));
  page.on('crash', () => console.log('[crash] a aba caiu'));
  await servir(page, web);
  const foto = n => page.screenshot({ path: path.join(pasta, `${q}_${n}.png`) });
  const espera = async re => { for (let i = 0; i < 2400 && !marcas.some(t => re.test(t)); i++) await page.waitForTimeout(250); };
  const pausa = ms => page.waitForTimeout(ms);
  await page.goto(`https://mu.local/index.html?auto=${s.quem}&gravacao=${q}&roteiro=` + encodeURIComponent(s.roteiro));
  await espera(s.janela || new RegExp(`TESTE janela evento ${s.npc}`));
  await pausa(800);
  await foto('1_janela');
  await espera(s.contagem);
  await pausa(2500);
  await foto('2_contagem');
  await espera(s.dentro);
  for (let i = 0; i < 3; i++) { await pausa(4000); await foto(`3_dentro_${i}`); }
  await espera(s.fim);
  await pausa(1500);
  await foto('4_placar');
  await page.close();
}
await nav.close();
console.log('fotos em', pasta);
