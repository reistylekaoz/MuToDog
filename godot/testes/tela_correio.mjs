// Fotos da rodada 10: toca dados/gravacao_correio.txt (test2Dk em Lorencia; o test1Dk chega perto, manda carta,
// abre a sala, fala na sala, fala em volta e cochicha). Fotografa a aba das cartas, a carta aberta com a foto
// na pose, a sala de chat com as duas falas, o balao e o cochicho no registro, a carta sendo escrita e a caixa do
// Enter aberta.
// Uso: node testes/tela_correio.mjs <pasta-das-fotos> [pasta do export, padrao build/web]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const pasta = process.argv[2] || '/tmp/mu-correio';
const web = process.argv[3] || path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', 'web');
fs.mkdirSync(pasta, { recursive: true });
const tipos = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });

async function sessao(url, passos) {
  const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
  const marcas = [];
  page.on('console', m => { const t = m.text(); if (/TESTE/.test(t)) marcas.push(t); if (/TESTE (roteiro|carta|sala|fala|cochicho)|ERROR/.test(t)) console.log(t.slice(0, 160)); });
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

// o roteiro da gravacao (o test2Dk: aba das cartas, le a ultima, fala na sala, escreve a resposta e fala), com a
// carta e a janela de amigos fechadas depois da foto delas, pra sala e o balao aparecerem inteiros
const roteiro = 'e:24;M:aba,1;e:3;M:ler,-1;e:4;M:fecha,carta;M:fecha,amigos;e:1;M:fala,oi_de_volta;e:10;M:carta,test1Dk,Re:_Ola_amigo,Gostei_da_foto!,5;e:4;M:diz,valeu_pela_carta;e:8';

await sessao('https://mu.local/index.html?auto=test2,x,test2Dk&gravacao=correio&roteiro=' + encodeURIComponent(roteiro), async c => {
  await c.espera(/TESTE roteiro correio \["aba"/);
  await c.pausa(1500);
  await c.foto('c1_aba_cartas');
  await c.espera(/TESTE carta aberta/);
  await c.pausa(2500);
  await c.foto('c2_carta_aberta');
  await c.espera(/TESTE sala test2Dk: oi de volta/);
  await c.pausa(800);
  await c.foto('c3_sala_chat');
  await c.espera(/TESTE fala test1Dk: ola todos/);
  await c.pausa(1500);
  await c.foto('c4_balao');
  await c.espera(/TESTE cochicho de test1Dk/);
  await c.pausa(800);
  await c.foto('c5_cochicho');
  await c.espera(/TESTE roteiro correio \["carta"/);
  await c.pausa(1000);
  await c.foto('c6_escrevendo_carta');
  await c.espera(/TESTE roteiro correio \["diz"/);
  await c.pausa(300);
  await c.foto('c7_caixa_chat');
  await c.espera(/TESTE fala test2Dk: valeu/);
  await c.pausa(1200);
  await c.foto('c8_balao_meu');
});
await nav.close();
console.log('fotos em', pasta);
