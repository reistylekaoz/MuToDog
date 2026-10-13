import { File } from 'megajs'
import fs from 'fs'
const f = File.fromURL(process.argv[2])
await f.loadAttributes()
console.log('nome:', f.name, 'tamanho:', (f.size/1e6).toFixed(1), 'MB')
const destino = process.argv[3] + '/' + f.name
let ult = 0
const s = f.download()
s.on('progress', p => { const pc = Math.floor(p.bytesLoaded*100/p.bytesTotal); if (pc >= ult+10) { ult = pc; console.log(pc + '%') } })
s.pipe(fs.createWriteStream(destino)).on('finish', () => console.log('ok', destino))
s.on('error', e => { console.error('erro', e.message); process.exit(1) })
