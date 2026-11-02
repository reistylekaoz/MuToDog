#!/bin/bash
# Export Web do teste de remasterizacao (Polido) em build/web_polido, com dados/hd/ dentro do pck.
# O jogo de verdade deixa dados/hd/ de fora (exclude_filter); aqui tira so durante o export.
# Uso: bash testes/exportar_polido.sh   depois: WEB=web_polido node testes/tela.mjs <pasta> <vista> (com &polido=...)
set -e
cd "$(dirname "$0")/.."
G=${GODOT:-$HOME/casa/trabalho/.ferramentas/godot/Godot_v4.7.2-stable_linux.x86_64}
D=build/web_polido
cp export_presets.cfg build/export_presets.cfg.antes
trap 'cp build/export_presets.cfg.antes export_presets.cfg' EXIT
python3 - <<'PY'
import re
cfg = open('export_presets.cfg').read()
a, b = cfg.split('[preset.1]', 1) if '[preset.1]' in cfg else (cfg, None)
a = a.replace(',dados/hd/*', '', 1)
open('export_presets.cfg', 'w').write(a + ('[preset.1]' + b if b is not None else ''))
PY
mkdir -p $D
$G --headless --import >/dev/null 2>&1 || true
$G --headless --export-release "Web" $D/index.html 2>&1 | grep -i "error" || true
[ -e $D/modelos ] || ln -s ../web/modelos $D/modelos
[ -e $D/mapas ] || ln -s ../web/mapas $D/mapas
[ -e $D/modelos_hd ] || ln -s ../modelos_hd $D/modelos_hd
ls -la $D/index.pck
