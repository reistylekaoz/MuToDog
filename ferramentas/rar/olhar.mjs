// abre na memoria os arquivos que batem com a regex e mostra hash, cabecalho PE e textos suspeitos
import { createExtractorFromData } from 'node-unrar-js'
import fs from 'fs'
import crypto from 'crypto'
const ex = await createExtractorFromData({ data: Uint8Array.from(fs.readFileSync(process.argv[2])).buffer })
const re = new RegExp(process.argv[3], 'i')
const { files } = ex.extract({ files: h => re.test(h.name) })
for (const f of files) {
  const b = Buffer.from(f.extraction)
  console.log('\n##', f.fileHeader.name, b.length, crypto.createHash('sha256').update(b).digest('hex'))
  if (b[0] === 0x4d && b[1] === 0x5a) {
    const pe = b.readUInt32LE(0x3c), maq = b.readUInt16LE(pe + 4), ts = b.readUInt32LE(pe + 8), ns = b.readUInt16LE(pe + 6), opt = b.readUInt16LE(pe + 20)
    const secs = []
    for (let i = 0; i < ns; i++) { const o = pe + 24 + opt + i * 40; secs.push(b.toString('latin1', o, o + 8).replace(/\0+$/, '')) }
    console.log('PE', maq.toString(16), new Date(ts * 1000).toISOString().slice(0, 10), 'secoes:', secs.join(' '))
    const txt = b.toString('latin1')
    const asc = (txt.match(/[\x20-\x7e]{6,}/g) || []), uni = (b.toString('utf16le').match(/[\x20-\x7e]{6,}/g) || [])
    const todos = [...new Set([...asc, ...uni])]
    const susp = todos.filter(s => /https?:\/\/|ftp:|\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b|powershell|cmd\.exe|URLDownload|InternetOpen|WinHttp|CreateRemoteThread|WriteProcessMemory|VirtualAllocEx|SetWindowsHook|GetAsyncKeyState|RegSetValue|\\Run\b|CurrentVersion\\Run|bitcoin|wallet|discord|telegram|pastebin|\.onion/i.test(s))
    console.log(susp.slice(0, 40).join('\n'))
  } else console.log(b.toString('latin1').slice(0, 600))
}
