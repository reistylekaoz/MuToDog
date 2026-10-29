// Fotos do telhado que some (Mundo.atualizar_telhados): toca dados/gravacao_telhado.txt (test1Dk na Lorencia em
// 124,142, entra na taverna pela porta 128,131 e sai de novo; gravada ao vivo com MU_GRAVAR e o roteiro
// e:4;w:124,128;e:8;w:124,142;e:8). Foto antes de entrar, la dentro e depois de sair.
// Uso: node testes/tela_telhado.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { servir } from './rota_web.mjs';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-telhado';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const marcas = [];
page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
await servir(page, web);
async function esperar(re, seg) {
  for (let i = 0; i < seg * 2; i++) { const t = marcas.find(t => re.test(t)); if (t) return t; await page.waitForTimeout(500); }
  return null;
}
await page.goto('https://mu.local/index.html?auto=test1,x,test1Dk&gravacao=telhado&roteiro=e:4;w:124,128;e:8;w:124,142;e:8');
console.log(await esperar(/TESTE entrou/, 300) ? 'entrou' : 'nao entrou');
await page.waitForTimeout(2500);
await page.screenshot({ path: path.join(pasta, '1_fora.png') });
console.log(await esperar(/TESTE telhado some/, 120));
await page.waitForTimeout(4000);
await page.screenshot({ path: path.join(pasta, '2_dentro.png') });
console.log(await esperar(/TESTE telhado volta/, 120));
await page.waitForTimeout(4000);
await page.screenshot({ path: path.join(pasta, '3_saiu.png') });
await nav.close();
console.log('fotos em', pasta);
