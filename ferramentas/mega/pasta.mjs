// lista (e baixa com 2o argumento) uma pasta do MEGA, mantendo a arvore
import { File } from 'megajs'
import fs from 'fs'
import path from 'path'
const raiz = File.fromURL(process.argv[2])
await raiz.loadAttributes()
const destino = process.argv[3]
async function anda(n, dir) {
  if (n.directory) {
    if (destino) fs.mkdirSync(path.join(destino, dir), { recursive: true })
    for (const c of n.children || []) await anda(c, path.join(dir, c.name))
    return
  }
  console.log((n.size/1e6).toFixed(1).padStart(8), 'MB ', dir)
  if (!destino || (process.argv[4] && !new RegExp(process.argv[4]).test(dir))) return
  const alvo = path.join(destino, dir)
  if (fs.existsSync(alvo) && fs.statSync(alvo).size === n.size) return
  await new Promise((ok, erro) => n.download().on('error', erro).pipe(fs.createWriteStream(alvo)).on('finish', ok))
}
await anda(raiz, raiz.name)
console.log('fim')
