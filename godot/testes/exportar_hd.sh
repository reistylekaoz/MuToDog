#!/bin/bash
# Pacotes HD do PC (build/hd_pck/hd_*.pck): as texturas de dados/hd/ (ferramentas/gerar_hd.sh) no MESMO caminho
# das originais. PacoteMapa.montar_pc monta os hd_*.pck por ultimo, por cima (replace_files), entao chao,
# objetos, personagens, monstros e itens trocam sem codigo nenhum. Option > HD textures desliga (vale ao reabrir).
# Como faz: guarda a original em saida/sd_guardado, poe a HD no lugar, importa, exporta e devolve a original
# (tambem se cair no meio; se sobrar saida/sd_guardado de uma rodada morta, a proxima devolve antes de comecar).
# Nao rode junto com o gerar_hd.sh (ele leria a HD no lugar da original e ampliaria de novo).
# Uso: bash testes/exportar_hd.sh [mundo1 modelos ...]   (sem nada = tudo de dados/hd)    depois: bash testes/publicar_pc.sh (copia os hd_*.pck pro launcher)
set -e
cd "$(dirname "$0")/.."
G=${GODOT:-$HOME/casa/trabalho/.ferramentas/godot/Godot_v4.7.2-stable_linux.x86_64}
D=build/hd_pck
B=../saida/sd_guardado

devolver() {
  [ -d $B ] || return 0
  (cd $B && find . -type f) | while read -r f; do cp -p "$B/$f" "dados/$f"; done
  rm -rf $B
  [ -f build/export_presets.hd.cfg ] && mv build/export_presets.hd.cfg export_presets.cfg
  $G --headless --import >/dev/null 2>&1 || true
  echo "originais de volta"
}
devolver
trap devolver EXIT

python3 - "$@" <<'PY'
import os, shutil, sys
B = '../saida/sd_guardado'
n = 0
so = set(sys.argv[1:])
for raiz, _, arqs in os.walk('dados/hd'):
    if so and os.path.relpath(raiz, 'dados/hd').split('/')[0] not in so:
        continue
    for a in arqs:
        if not a.endswith('.png') or a.endswith('_n.png'):
            continue
        hd = os.path.join(raiz, a)
        rel = os.path.relpath(hd, 'dados/hd')
        sd = os.path.join('dados', rel)
        if not os.path.exists(sd):
            continue
        os.makedirs(os.path.dirname(os.path.join(B, rel)), exist_ok=True)
        shutil.copy2(sd, os.path.join(B, rel))
        shutil.copyfile(hd, sd)
        n += 1
print('trocadas', n)
PY
$G --headless --import >/dev/null 2>&1 || true

cp export_presets.cfg build/export_presets.hd.cfg
python3 - <<'PY'
import os, re
cfg = open('export_presets.cfg').read()
cfg = re.split(r'\n\[preset\.\d+\]\n\nname="(?:Mapa|Modelos|HD)', cfg)[0].rstrip('\n') + '\n'
i0 = re.search(r'\[preset\.(\d+)\]\n\nname="Windows"', cfg).group(1)
opcoes = re.search(r'\[preset\.%s\.options\]\n(.*?)(?=\n\[|\Z)' % i0, cfg, re.S).group(1).strip()
base = max(int(i) for i in re.findall(r'^\[preset\.(\d+)\]', cfg, re.M)) + 1
B = '../saida/sd_guardado'
grupos = {}
for raiz, _, arqs in os.walk(B):
    for a in sorted(arqs):
        rel = os.path.relpath(os.path.join(raiz, a), B)
        topo = rel.split('/')[0]
        grupos.setdefault(topo, []).append('dados/' + rel)
pacotes = []
for topo in sorted(grupos):
    fs = sorted(grupos[topo])
    if topo.startswith('mundo'):
        pacotes.append((f'hd_{topo}', fs))
        continue
    # itens e personagens em pedacos de ~60 MB
    atual, soma, k = [], 0, 1
    for f in fs:
        t = os.path.getsize(f)
        if atual and soma + t > 60_000_000:
            pacotes.append((f'hd_{topo}{k}', atual)); atual, soma, k = [], 0, k + 1
        atual.append(f); soma += t
    if atual:
        pacotes.append((f'hd_{topo}{k}', atual))
for j, (nome, fs) in enumerate(pacotes):
    cfg += f'''
[preset.{base + j}]

name="HD {nome}"
platform="Windows Desktop"
runnable=false
dedicated_server=false
custom_features=""
export_filter="resources"
export_files=PackedStringArray({", ".join(f'"res://{x}"' for x in fs)})
include_filter=""
exclude_filter=""
export_path=""

[preset.{base + j}.options]

{opcoes}
'''
open('export_presets.cfg', 'w').write(cfg)
print('pacotes', len(pacotes))
PY
[ $# -eq 0 ] && rm -rf $D; mkdir -p $D
for p in $(grep -o 'name="HD [a-z0-9_]*"' export_presets.cfg | cut -d'"' -f2 | cut -d' ' -f2); do
  $G --headless --export-pack "HD $p" $D/$p.pck 2>&1 | grep -i "error" || true
done
ls $D | wc -l
du -sh $D
