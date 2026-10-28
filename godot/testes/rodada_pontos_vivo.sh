#!/bin/bash
# Pontos em massa contra o OpenMU daqui (../servidor.sh ligar-teste): socketDl (com pontos sobrando) clica no +
# da forca e manda 250 (/add str 250: o servidor manda a ficha de novo e o mapa recarrega no mesmo lugar),
# depois 1 na agilidade (C1 F3 06 do original) e 40 na vitalidade. Confira no TESTE entrou: pontos e atributos.
# Uso: testes/rodada_pontos_vivo.sh [segundos]
cd "$(dirname "$0")/.."
RAIZ=$(cd .. && pwd)
GODOT=${GODOT:-$HOME/casa/trabalho/.ferramentas/godot/Godot_v4.7.2-stable_linux.x86_64}
[ -S "$RAIZ/sockmu/44405" ] || { echo "ligue antes: $RAIZ/servidor.sh ligar-teste"; exit 2; }
SEG=${1:-25}
MU_PONTE=$PWD/testes/ponte_unix.py MU_SOCKETS=$RAIZ/sockmu \
  timeout $((SEG + 30)) "$GODOT" --headless --path . -- --auto socket,socket,socketDl --roteiro "${ROTEIRO:-e:5;U:0,250;e:4;U:1,1;e:3;U:2,40;e:4}" --sair "$SEG" 2>&1 \
  | grep --line-buffered -E "TESTE (entrou|roteiro|pontos|ponto|caixa)|ERROR|SCRIPT" | grep --line-buffered -v "TESTE objeto"
