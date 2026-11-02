// Fotos do teste de remasterizacao (Polido) no export build/web_polido (testes/exportar_polido.sh).
// Uso: node testes/tela_polido.mjs <pasta> "<query da vista>" [modo ...]   modo = original|luz|hd|tudo
// ex.: node testes/tela_polido.mjs /tmp/p "x=134&y=127&giro=45&inclinacao=38&dist=9&heroi=..." original luz hd tudo
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { servir } from './rota_web.mjs';
const require = createRequire(import.meta.url);
const { chromium } = require('/usr/local/lib/node_modules/playwright');

const [pasta, query, ...modos] = process.argv.slice(2);
const web = path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'build', process.env.WEB || 'web_polido');
fs.mkdirSync(pasta, { recursive: true });
const nav = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
for (const modo of (modos.length ? modos : ['original', 'luz', 'hd', 'tudo'])) {
  const page = await nav.newPage({ viewport: { width: 1280, height: 720 } });
  let pronto = false;
  page.on('console', m => { const t = m.text(); if (/TESTE mundo/.test(t)) pronto = true; if (/error|erro|TESTE|warn/i.test(t)) console.log(`[${modo}]`, t.slice(0, 300)); });
  page.on('pageerror', e => console.log('[pageerror]', e.message));
  await servir(page, web);
  await page.goto(`https://mu.local/index.html?vista=1&${query}${modo === 'original' ? '' : `&polido=${modo}`}`);
  for (let i = 0; i < 360 && !pronto; i++) await page.waitForTimeout(500);
  await page.waitForTimeout(Number(process.env.ESPERA || 10) * 1000);
  const foto = path.join(pasta, `${modo}.png`);
  await page.screenshot({ path: foto });
  console.log('foto', foto, pronto ? '' : '(sem TESTE no console)');
  await page.close();
}
await nav.close();
