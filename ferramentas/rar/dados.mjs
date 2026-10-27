// extrai de um .rar so os arquivos de dado (nenhum programa): node dados.mjs arquivo.rar destino
import { createExtractorFromData } from 'node-unrar-js'
import fs from 'fs'
import path from 'path'
const ok = /\.(xml|lua|ini|txt|sql|dat|att|cfg|bmd|hit|png)$/i
const ex = await createExtractorFromData({ data: Uint8Array.from(fs.readFileSync(process.argv[2])).buffer })
const { files } = ex.extract({ files: h => !h.flags.directory && ok.test(h.name) })
let n = 0
for (const f of files) {
  const alvo = path.resolve(process.argv[3], f.fileHeader.name.replace(/\\/g, '/'))
  if (!alvo.startsWith(path.resolve(process.argv[3]) + path.sep)) throw new Error('caminho fora: ' + f.fileHeader.name)
  fs.mkdirSync(path.dirname(alvo), { recursive: true })
  fs.writeFileSync(alvo, f.extraction); n++
}
console.log('extraidos:', n)
