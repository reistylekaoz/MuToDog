#!/bin/bash
# Foto do teste de remasterizacao (Polido) no jogo nativo com tela (Xvfb :77 ligado, ver memoria).
# Uso: bash testes/foto_polido.sh <pasta> <modo ...>   (modo = original|luz|hd|tudo; VISTA muda a camera)
cd "$(dirname "$0")/.."
G=${GODOT:-$HOME/casa/trabalho/.ferramentas/godot/Godot_v4.7.2-stable_linux.x86_64}
P=$1; shift
mkdir -p $P
VISTA=${VISTA:-"--x 138 --y 124 --giro 45 --inclinacao 40 --dist 11"}
HEROI=${HEROI:-"0=0,5;2=7,1;3=8,1;4=9,1;5=10,1;6=11,1;7=12,5;niveis=0:13,2:11,3:11,4:11,5:11,6:11"}
for m in "$@"; do
  pol=""; [ "$m" != original ] && pol="--polido $m"
  DISPLAY=${DISPLAY:-:77} timeout 180 $G --path . --rendering-driver opengl3 --resolution 1280x720 res://main.tscn -- \
    $VISTA --heroi "$HEROI" --heroi_giro ${GIRO_HEROI:-200} $pol --foto $P/$m.png 2>&1 | grep -E "TESTE (polido|heroi|foto)|SCRIPT ERROR|Parse Error" | head -5
done
