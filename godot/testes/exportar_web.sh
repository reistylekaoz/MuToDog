#!/bin/bash
# Export Web com os mapas de fora (PacoteMapa.FORA) em pacotes a parte.
# Uso: bash testes/exportar_web.sh [pasta em build/, padrao web_novo]
# Grava build/<pasta>/index.* e build/<pasta>/mapas/mundo<N>.pck; modelos/ aponta pro de build/web.
# O site le build/web direto: exporte em web_novo, teste, e so depois copie pra web.
set -e
cd "$(dirname "$0")/.."
G=${GODOT:-$HOME/casa/trabalho/.ferramentas/godot/Godot_v4.7.2-stable_linux.x86_64}
D=build/${1:-web_novo}
FORA=$(grep -o 'const FORA := \[[0-9, ]*\]' scripts/pacote_mapa.gd | grep -o '[0-9]\+' | tr '\n' ' ')
# presets Mapa<N>: so os arquivos de dados/mundo<N> (refeitos a cada export, os dados mudam)
python3 - $FORA <<'PY'
import os, re, sys
cfg = open('export_presets.cfg').read()
cfg = re.split(r'\n\[preset\.\d+\]\n\nname="Mapa', cfg)[0].rstrip('\n') + '\n'
base = max(int(i) for i in re.findall(r'^\[preset\.(\d+)\]', cfg, re.M)) + 1
opcoes = re.search(r'\[preset\.0\.options\]\n(.*?)(?=\n\[|\Z)', cfg, re.S).group(1).strip()
for k, n in enumerate(sys.argv[1:]):
    fs = sorted('res://' + os.path.join(r, x) for r, _, f in os.walk(f'dados/mundo{n}') for x in f if x.endswith(('.png', '.glb', '.mp3', '.wav')))
    i = base + k
    cfg += f'''
[preset.{i}]

name="Mapa{n}"
platform="Web"
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
open('export_presets.cfg', 'w').write(cfg)
PY
mkdir -p $D/mapas
$G --headless --import >/dev/null 2>&1 || true
$G --headless --export-release "Web" $D/index.html 2>&1 | grep -i "error" || true
for n in $FORA; do
  $G --headless --export-pack "Mapa$n" $D/mapas/mundo$n.pck 2>&1 | grep -i "error" || true
done
[ "$D" != build/web ] && [ ! -e $D/modelos ] && ln -s ../web/modelos $D/modelos
ls -la $D/index.pck $D/mapas/
