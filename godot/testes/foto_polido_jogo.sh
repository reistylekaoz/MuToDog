#!/bin/bash
# Foto do mapa no visualizador com a luz do jogo (Polido ?polido=jogo) ou o original, no Xvfb :77.
# Uso: bash testes/foto_polido_jogo.sh <saida.png> <mundo> <x> <y> [original|jogo]  
cd "$(dirname "$0")/.."
G=${GODOT:-$HOME/casa/trabalho/.ferramentas/godot/Godot_v4.7.2-stable_linux.x86_64}
pol="--polido ${5:-jogo}"; [ "$5" = original ] && pol=""
DISPLAY=${DISPLAY:-:77} ESPERA=${ESPERA:-10} timeout 150 $G --path . --rendering-driver opengl3 --resolution 1280x720 res://main.tscn -- \
  --mundo $2 --x $3 --y $4 --giro ${GIRO:-45} --inclinacao 40 --dist 14 $pol --foto $1 2>&1 | grep -E "SCRIPT ERROR|Parse Error" | head -3
