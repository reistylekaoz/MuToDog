// Fotos das telas que saiam com o tema do Godot e agora usam as texturas do cliente: ?ui_teste=1 abre a caixa
// do Esc, a janela Option, a caixa de quantos pontos, um convite (OK e Cancel), a janela Move e a de amigos.
// Toca dados/gravacao_cidade.txt (test1Dk na Lorencia).
// Uso: node testes/tela_ui.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { servir } from './rota_web.mjs';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-ui';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
const marcas = [];
page.on('console', m => { const t = m.text(); if (/TESTE|SCRIPT ERROR/.test(t)) marcas.push(t); if (/SCRIPT ERROR/.test(t)) console.log(t); });
page.on('pageerror', e => console.log('[pageerror]', e.message));
await servir(page, web);
async function esperar(re, seg) {
  for (let i = 0; i < seg * 2; i++) { const t = marcas.find(t => re.test(t)); if (t) return t; await page.waitForTimeout(500); }
  return null;
}
await page.goto('https://mu.local/index.html?auto=test1,x,test1Dk&gravacao=cidade&ui_teste=1');
console.log(await esperar(/TESTE entrou/, 300) ? 'entrou' : 'nao entrou');
for (const n of ['menu', 'opcao', 'pontos', 'convite', 'mover']) {
  console.log(await esperar(new RegExp('TESTE ui ' + n), 60) || 'sem ' + n);
  await page.waitForTimeout(1200);
  await page.screenshot({ path: path.join(pasta, n + '.png') });
}
await nav.close();
console.log('fotos em', pasta);
