#!/bin/bash
# Export Windows com os mapas de fora (PacoteMapa.FORA) e os modelos (itens e bonecos) em pacotes
# a parte: build/windows/openmu.exe + openmu.pck + mapas/mundo<N>.pck + mapas/modelos<K>.pck
# (PacoteMapa.montar_pc monta todos na partida).
# Assim cada zip de entrega fica abaixo dos 50 MB do app arquivos.
# Uso: bash testes/exportar_windows.sh [pasta, padrao build/windows]
set -e
cd "$(dirname "$0")/.."
G=${GODOT:-$HOME/casa/trabalho/.ferramentas/godot/Godot_v4.7.2-stable_linux.x86_64}
D=${1:-build/windows}
FORA=$(grep -o 'const FORA := \[[0-9, ]*\]' scripts/pacote_mapa.gd | grep -o '[0-9]\+' | tr '\n' ' ')
cp export_presets.cfg /tmp/export_presets.$$.cfg
trap 'cp /tmp/export_presets.$$.cfg export_presets.cfg; rm -f /tmp/export_presets.$$.cfg' EXIT
python3 - $FORA <<'PY'
import os, re, sys
cfg = open('export_presets.cfg').read()
cfg = re.split(r'\n\[preset\.\d+\]\n\nname="Mapa', cfg)[0].rstrip('\n') + '\n'
fora = ''.join(f'dados/mundo{n}/*,' for n in sys.argv[1:]) + 'dados/efeitos_todos/*,dados/modelos/*.glb,dados/modelos/*.png,dados/personagens/*.glb,dados/personagens/*.png,'
cfg = re.sub(r'(name="Windows"\n(?:.*\n)*?exclude_filter=")', r'\g<1>' + fora, cfg, count=1)
i0 = re.search(r'\[preset\.(\d+)\]\n\nname="Windows"', cfg).group(1)
opcoes = re.search(r'\[preset\.%s\.options\]\n(.*?)(?=\n\[|\Z)' % i0, cfg, re.S).group(1).strip()
base = max(int(i) for i in re.findall(r'^\[preset\.(\d+)\]', cfg, re.M)) + 1
for k, n in enumerate(sys.argv[1:]):
    fs = sorted('res://' + os.path.join(r, x) for r, _, f in os.walk(f'dados/mundo{n}') for x in f if x.endswith(('.png', '.glb', '.mp3', '.wav')))
    i = base + k
    cfg += f'''
[preset.{i}]

name="Mapa{n}"
platform="Windows Desktop"
runnable=false
dedicated_server=false
custom_features=""
export_filter="resources"
export_files=PackedStringArray({", ".join(f'"{x}"' for x in fs)})
include_filter="dados/mundo{n}/*.json"
exclude_filter=""
export_path=""

[preset.{i}.options]

{opcoes}
'''
# modelos dos itens e dos personagens em pedacos de ~30 MB
grupos = []
for d in ('dados/modelos', 'dados/personagens'):
    atual, soma = [], 0
    for x in sorted(os.listdir(d)):
        if not x.endswith(('.glb', '.png')):
            continue
        t = os.path.getsize(f'{d}/{x}')
        if atual and soma + t > 30_000_000:
            grupos.append(atual); atual, soma = [], 0
        atual.append(f'res://{d}/{x}'); soma += t
    grupos.append(atual)
for k, fs in enumerate(grupos):
    i = base + len(sys.argv) - 1 + k
    cfg += f'''
[preset.{i}]

name="Modelos{k + 1}"
platform="Windows Desktop"
runnable=false
dedicated_server=false
custom_features=""
export_filter="resources"
export_files=PackedStringArray({", ".join(f'"{x}"' for x in fs)})
include_filter=""
exclude_filter=""
export_path=""

[preset.{i}.options]

{opcoes}
'''
open('export_presets.cfg', 'w').write(cfg)
PY
rm -rf $D; mkdir -p $D/mapas
$G --headless --import >/dev/null 2>&1 || true
$G --headless --export-release "Windows" $D/openmu.exe 2>&1 | grep -i "error" || true
for n in $FORA; do
  $G --headless --export-pack "Mapa$n" $D/mapas/mundo$n.pck 2>&1 | grep -i "error" || true
done
for m in $(grep -o 'name="Modelos[0-9]*"' export_presets.cfg | cut -d'"' -f2); do
  $G --headless --export-pack "$m" $D/mapas/$(echo $m | tr M m).pck 2>&1 | grep -i "error" || true
done
ls -la $D $D/mapas
