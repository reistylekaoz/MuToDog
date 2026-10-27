// extrai um .rar (node-unrar-js, WASM): node abrir.mjs arquivo.rar destino
import { createExtractorFromFile } from 'node-unrar-js'
const ex = await createExtractorFromFile({ filepath: process.argv[2], targetPath: process.argv[3] })
let n = 0
for (const f of ex.extract().files) n++
console.log('arquivos:', n)
