// Fotos da rodada 9: toca dados/gravacao_gens.txt (quest3Elf entra no Duprian com o socketElf, do Vanert, ao
// lado em Lorencia). Fotografa a conversa do Gregory com a marca do Vanert no outro, o "bem-vindo" com a marca
// propria, a janela B, a contribuicao na conversa, o premio recusado e os dois nomes com marca.
// Uso: node testes/tela_gens.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-gens';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const tipos = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });

async function sessao(url, passos) {
  const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
  const marcas = [];
  page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/TESTE|SCRIPT ERROR/.test(t)) console.log(t.slice(0, 160)); });
  page.on('pageerror', e => console.log('[pageerror]', e.message));
  await page.route('https://mu.local/**', async rota => {
    const arq = path.join(web, new URL(rota.request().url()).pathname.replace(/^\//, '') || 'index.html');
    if (!fs.existsSync(arq)) return rota.fulfill({ status: 404, body: '' });
    await rota.fulfill({ status: 200, body: fs.readFileSync(arq), headers: { 'content-type': tipos[path.extname(arq)] || 'application/octet-stream' } });
  });
  const ctx = {
    page,
    foto: n => page.screenshot({ path: path.join(pasta, `${n}.png`) }),
    espera: async re => { for (let i = 0; i < 1600 && !marcas.some(t => re.test(t)); i++) await page.waitForTimeout(250); },
    pausa: ms => page.waitForTimeout(ms),
  };
  await page.goto(url);
  await passos(ctx);
  await page.close();
}

// o da gravacao era 'e:3;n:543;e:6;o:4;e:2;o:1;e:4;B;e:5;B;e:2;n:543;e:6;o:6;e:4;w:138,146;e:8'. No navegador a fita
// chega antes do segundo n:543 (que fecharia a conversa recem aberta), entao ele vira espera. O
// socketElf ficou em (149,134), atras do predio: a foto dos nomes vem da segunda gravacao
const roteiro = 'e:3;n:543;e:6;o:4;e:2;o:1;e:4;B;e:5;B;e:3;e:6;o:6;e:4;e:8';

await sessao('https://mu.local/index.html?auto=quest3,x,quest3Elf&gravacao=gens&roteiro=' + encodeURIComponent(roteiro), async c => {
  await c.espera(/TESTE dialogo do npc 543 .* contribuicao 0/);
  await c.pausa(1200);
  await c.foto('g1_conversa_gregory');
  await c.espera(/TESTE gens entrou 0/);
  await c.pausa(200);   // logo, antes do o:1 do roteiro (atrasado em relacao a fita) voltar a conversa pro comeco
  await c.foto('g2_entrou_duprian');
  await c.espera(/TESTE janela gens true/);
  await c.pausa(1200);
  await c.foto('g3_janela_b');
  await c.espera(/TESTE dialogo do npc 543 .* contribuicao 10/);
  await c.pausa(1000);
  await c.foto('g4_contribuicao');
  await c.espera(/TESTE gens premio/);
  await c.pausa(1000);
  await c.foto('g5_premio_recusado');
});
// dados/gravacao_gens2.txt: os dois parados lado a lado (quest3Elf Duprian, socketElf Vanert), cada um com a marca
await sessao('https://mu.local/index.html?auto=quest3,x,quest3Elf&gravacao=gens2&roteiro=e:14', async c => {
  await c.espera(/TESTE gens jogadores \["\d+ g2/);
  await c.pausa(2500);
  await c.foto('g6_nomes_com_marca');
});
await nav.close();
console.log('fotos em', pasta);
