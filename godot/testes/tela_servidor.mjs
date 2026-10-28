// Fotos da escolha do servidor (CServerSelWin) e do login depois dela, sem servidor: toca a fita
// dados/gravacao_servidor.txt (o ola e a lista do connect server do OpenMU daqui, a mesma lista de novo
// com o servidor 3 em 40% pra barra aparecer, o endereco e o ola do servidor do jogo).
// Uso: node testes/tela_servidor.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { servir } from './rota_web.mjs';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-servidor';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const W = 1280, H = 720;
const page = await nav.newPage({ viewport: { width: W, height: H } });
const marcas = [];
page.on('console', m => { const t = m.text(); if (/TESTE|REDE|ERROR/.test(t)) { marcas.push(t); console.log(t.slice(0, 160)); } });
page.on('pageerror', e => console.log('[pageerror]', e.message));
await servir(page, web);
await page.goto('https://mu.local/index.html?gravacao=servidor');

// a tela do login e 800 x 600 esticada (escala de 1 a 2) e a janela fica no meio
const esc = Math.min(Math.max(Math.min(W / 800, H / 600), 1), 2);
const lw = W / esc, lh = H / esc;
const ox = Math.floor((lw - 465) / 2), oy = Math.floor((lh - 504) / 2);
const base = oy + 504 - (26 * 11 + 10 + 52);
const tela = (x, y) => [x * esc, y * esc];
const grupo1 = tela(ox + 54, base + 13);
const servidor = i => tela(ox + 136 + 96, base + 26 * i + 13);

async function espera(re, n = 1) {
  for (let i = 0; i < 1200; i++) { if (marcas.filter(t => re.test(t)).length >= n) return true; await page.waitForTimeout(250); }
  console.log('sem marca', re); return false;
}
const foto = async nome => { await page.screenshot({ path: path.join(pasta, nome + '.png') }); console.log('foto', nome); };

await espera(/TESTE servidores/);
await page.waitForTimeout(2500);
await foto('s1_grupos');
await page.mouse.move(...grupo1);
await page.waitForTimeout(400);
await foto('s2_grupo_mouse');
await page.mouse.click(...grupo1);
await espera(/TESTE servidores/, 2);
await page.mouse.move(...servidor(1));
await page.waitForTimeout(1200);
await foto('s3_servidores');
await page.mouse.click(...servidor(0));
await espera(/TESTE servidor escolhido/);
await espera(/REDE esperando_login/);
await page.waitForTimeout(1500);
await foto('s4_login');
await page.close();
await nav.close();
console.log('fotos em', pasta);
