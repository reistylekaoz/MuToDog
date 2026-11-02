#!/usr/bin/env python3
# GLB de item com as texturas embutidas ampliadas (ampliar.py) e normal map no material.
# Uso: ~/casa/trabalho/.ferramentas/esrgan/bin/python ferramentas/glb_hd.py <pasta-saida> <a.glb> [b.glb ...] [--escala 2]
# O modo polido do cliente (Polido) baixa de modelos_hd/ em vez de modelos/.
import io, json, os, struct, sys
sys.path.insert(0, os.path.dirname(__file__))
import torch
from PIL import Image
import ampliar


def ler(caminho):
    d = open(caminho, 'rb').read()
    n = struct.unpack('<I', d[12:16])[0]
    j = json.loads(d[20:20 + n])
    p = 20 + n
    bn = struct.unpack('<I', d[p:p + 4])[0]
    return j, d[p + 8:p + 8 + bn]


def gravar(caminho, j, blob):
    js = json.dumps(j, separators=(',', ':')).encode()
    js += b' ' * (-len(js) % 4)
    blob += b'\0' * (-len(blob) % 4)
    total = 12 + 8 + len(js) + 8 + len(blob)
    with open(caminho, 'wb') as f:
        f.write(struct.pack('<III', 0x46546C67, 2, total))
        f.write(struct.pack('<II', len(js), 0x4E4F534A) + js)
        f.write(struct.pack('<II', len(blob), 0x004E4942) + blob)


def main():
    args = sys.argv[1:]
    escala = 2
    if '--escala' in args:
        i = args.index('--escala')
        escala = int(args[i + 1])
        del args[i:i + 2]
    saida, glbs = args[0], args[1:]
    os.makedirs(saida, exist_ok=True)
    torch.set_num_threads(os.cpu_count())
    r = ampliar.rede('forte')
    for g in glbs:
        destino = os.path.join(saida, os.path.basename(g))
        if os.path.exists(destino) and os.path.getmtime(destino) > os.path.getmtime(g):
            continue
        j, bin_ = ler(g)
        views = j['bufferViews']
        pedacos = [bin_[v.get('byteOffset', 0):v.get('byteOffset', 0) + v['byteLength']] for v in views]
        normais = {}
        for ii, im in enumerate(j.get('images', [])):
            img = Image.open(io.BytesIO(pedacos[im['bufferView']]))
            img.load()
            hd = ampliar.ampliar(r, img, escala)
            b = io.BytesIO()
            hd.save(b, 'PNG')
            pedacos[im['bufferView']] = b.getvalue()
            nb = io.BytesIO()
            ampliar.normal(hd).save(nb, 'PNG')
            pedacos.append(nb.getvalue())
            views.append({'buffer': 0, 'byteLength': 0})
            j['images'].append({'bufferView': len(views) - 1, 'mimeType': 'image/png'})
            j['textures'].append({'source': len(j['images']) - 1, **({'sampler': j['textures'][0]['sampler']} if 'sampler' in j['textures'][0] else {})})
            normais[ii] = len(j['textures']) - 1
        # cada material com textura de cor ganha o normal map da mesma imagem
        for m in j.get('materials', []):
            t = m.get('pbrMetallicRoughness', {}).get('baseColorTexture')
            if t is not None:
                src = j['textures'][t['index']]['source']
                if src in normais:
                    m['normalTexture'] = {'index': normais[src]}
        # remonta o buffer com os pedacos novos (alinhados em 4)
        blob = b''
        for v, p in zip(views, pedacos):
            blob += b'\0' * (-len(blob) % 4)
            v['byteOffset'] = len(blob)
            v['byteLength'] = len(p)
            blob += p
        j['buffers'][0]['byteLength'] = len(blob)
        gravar(destino, j, blob)
        print(destino, os.path.getsize(g), '->', os.path.getsize(destino), flush=True)


if __name__ == '__main__':
    main()
