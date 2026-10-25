// Serve o export web pra uma aba do Playwright sem porta (page.route em https://mu.local/).
// O Playwright passa cada resposta pelo canal do devtools em base64, com teto de 100 MB por mensagem:
// o index.pck passou de 75 MB e derrubava o navegador. Arquivo grande vai em pedacos de 32 MB
// (?parte=N) e um fetch trocado na pagina junta os pedacos antes de entregar pro Godot.
import fs from 'fs';
import path from 'path';

const PEDACO = 32 * 1024 * 1024;
const tipos = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };

export async function servir(page, web) {
  const grandes = {};
  for (const f of fs.readdirSync(web)) {
    const t = fs.statSync(path.join(web, f)).size;
    if (t > PEDACO) grandes['/' + f] = t;
  }
  await page.addInitScript(([grandes, pedaco]) => {
    const original = window.fetch.bind(window);
    window.fetch = async (url, op) => {
      const u = new URL(typeof url === 'string' ? url : url.url, location.href);
      const tam = grandes[u.pathname];
      if (!tam) return original(url, op);
      const partes = [];
      for (let i = 0; i * pedaco < tam; i++) partes.push(await (await original(`${u.pathname}?parte=${i}`)).arrayBuffer());
      return new Response(new Blob(partes), { status: 200, headers: { 'content-length': String(tam), 'content-type': 'application/octet-stream' } });
    };
  }, [grandes, PEDACO]);
  await page.route('https://mu.local/**', async rota => {
    const u = new URL(rota.request().url());
    const arq = path.join(web, u.pathname.replace(/^\//, '') || 'index.html');
    if (!fs.existsSync(arq)) return rota.fulfill({ status: 404, body: '' });
    let corpo = fs.readFileSync(arq);
    const parte = u.searchParams.get('parte');
    if (parte !== null) corpo = corpo.subarray(Number(parte) * PEDACO, (Number(parte) + 1) * PEDACO);
    await rota.fulfill({ status: 200, body: corpo, headers: { 'content-type': tipos[path.extname(arq)] || 'application/octet-stream' } });
  });
}
