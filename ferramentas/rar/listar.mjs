// lista um .rar sem extrair: nome, tamanho, cifrado
import { createExtractorFromData } from 'node-unrar-js'
import fs from 'fs'
const buf = Uint8Array.from(fs.readFileSync(process.argv[2])).buffer
const ex = await createExtractorFromData({ data: buf })
const l = ex.getFileList()
console.log(JSON.stringify(l.arcHeader))
for (const h of l.fileHeaders) console.log([h.unpSize, h.flags.encrypted ? 'CIFRADO' : '', h.flags.directory ? 'DIR' : '', h.name].join('\t'))
