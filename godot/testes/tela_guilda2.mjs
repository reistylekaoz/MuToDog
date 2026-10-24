// Fotos da rodada 8: toca dados/gravacao_guilda2a.txt (test400Dl, mestre de Lobos) e gravacao_guilda2b.txt
// (quest1Dk, mestre de Ursos). Lobos pede alianca, abre a aba Alliance, tira Ursos, vira rival e chama pra
// guerra; Ursos recebe as caixas. Fotografa a aba Alliance, os nomes com a alianca, a caixa de tirar, o rival
// em vermelho, as caixas de pedido, o comeco da guerra com o placar, a luta e o fim.
// Uso: node testes/tela_guilda2.mjs <pasta-das-fotos> [pasta do export, padrao build/web] [a, b e f: quais sessoes, padrao ab]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-guilda2';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
const lados = process.argv[4] || 'ab';
fs.mkdirSync(pasta, { recursive: true });
const tipos = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });

async function sessao(url, passos) {
  const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
  const marcas = [];
  page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/TESTE (guilda|guerra|roteiro)|SCRIPT ERROR/.test(t)) console.log(t.slice(0, 160)); });
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

const roteiro_a = 'e:2;G:fim_rival,quest1Dk;e:6;G:alianca,quest1Dk;e:6;G:abrir;G:aba,2;e:8;G:tirar_alianca,Ursos;e:6;' +
  'G:rival,quest1Dk;e:6;G:aba,0;e:4;G:fechar;d:/war_Ursos;e:4;w:221,81;e:6;A:quest1Dk;e:300';

if (lados.includes('a')) await sessao('https://mu.local/index.html?auto=test400,x,test400Dl&gravacao=guilda2a&roteiro=' + encodeURIComponent(roteiro_a), async c => {
  await c.espera(/TESTE roteiro guilda \["aba", "2"\]/);
  await c.espera(/TESTE guilda alianca lista/);
  await c.page.mouse.move(640, 600);
  await c.pausa(1200);
  await c.foto('a1_aba_alianca');
  await c.espera(/TESTE roteiro guilda \["tirar_alianca"/);
  await c.pausa(600);
  await c.foto('a2_tirar_da_alianca');
  await c.page.keyboard.press('Enter');
  await c.espera(/TESTE roteiro guilda \["aba", "0"\]/);
  await c.pausa(900);
  await c.foto('a3_janela_rival');
  await c.espera(/TESTE roteiro guilda \["fechar"\]/);
  await c.pausa(900);
  await c.foto('a4_nomes_rival');
  await c.espera(/TESTE guerra comecou/);
  await c.pausa(1000);
  await c.foto('a5_guerra_comecou');
  await c.espera(/TESTE guerra placar 8 x 0/);
  await c.pausa(700);
  await c.foto('a6_guerra_placar');
  await c.espera(/TESTE guerra fim/);
  await c.pausa(1000);
  await c.foto('a7_guerra_fim');
});

if (lados.includes('b')) await sessao('https://mu.local/index.html?auto=quest1,x,quest1Dk&gravacao=guilda2b', async c => {
  await c.espera(/TESTE guilda relacao: test400Dl pediu 2\/2/);
  await c.pausa(500);
  await c.foto('b1_pedido_fim_rival');
  await c.page.keyboard.press('Enter');
  await c.espera(/TESTE guilda relacao: test400Dl pediu 1\/1/);
  await c.pausa(500);
  await c.foto('b2_pedido_alianca');
  await c.page.keyboard.press('Enter');
  await c.espera(/TESTE guilda alianca agora 'Lobos'/);
  await c.pausa(1500);
  await c.foto('b3_nomes_alianca');
  await c.espera(/TESTE guilda relacao: test400Dl pediu 2\/1/);
  await c.pausa(500);
  await c.foto('b4_pedido_rival');
  await c.page.keyboard.press('Enter');
  await c.espera(/TESTE guerra: Lobos chamou/);
  await c.pausa(500);
  await c.foto('b5_pedido_guerra');
  await c.page.keyboard.press('Enter');
  await c.espera(/TESTE guerra placar 0 x 6/);
  await c.pausa(500);
  await c.foto('b6_placar_perdendo');
});
// Battle Soccer: dados/gravacao_futebol.txt (Lobos chama Ursos, os dois vao pra Arena e Lobos faz 5 gols)
if (lados.includes('f')) await sessao('https://mu.local/index.html?auto=test400,x,test400Dl&gravacao=futebol&roteiro=' +
    encodeURIComponent('e:2;d:/battlesoccer_Ursos;e:8;F;e:200'), async c => {
  await c.espera(/TESTE mapa mudou 6/);
  await c.pausa(4000);
  await c.foto('f1_futebol_comecou');
  await c.espera(/TESTE guerra placar 40 x 0/);
  await c.pausa(2500);
  await c.foto('f2_futebol_placar');
  await c.espera(/TESTE guerra fim/);
  await c.pausa(800);
  await c.foto('f3_futebol_fim');
});
await nav.close();
console.log('fotos em', pasta);
