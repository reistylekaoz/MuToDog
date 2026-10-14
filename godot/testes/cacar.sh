#!/bin/bash
# Caca de verdade contra o OpenMU daqui (../servidor.sh ligar-teste): o personagem
# mira o monstro mais perto, bate ate matar, pega o que cair. Grava a sessao.
# Uso: testes/cacar.sh [conta,senha,personagem] [monstros] [segundos] [gravacao] [andar x,y antes]
# MU_EXTRA="--skill 41" caca com a skill 41 no lugar do golpe comum.
cd "$(dirname "$0")/.."
RAIZ=$(cd .. && pwd)
GODOT=${GODOT:-$HOME/casa/trabalho/.ferramentas/godot/Godot_v4.7.2-stable_linux.x86_64}
[ -S "$RAIZ/sockmu/44405" ] || { echo "ligue antes: $RAIZ/servidor.sh ligar-teste"; exit 2; }
AUTO=${1:-test0,test0,test0Dk}; N=${2:-3}; SEG=${3:-90}; GRAVA=${4:-}; ANDAR=${5:+--andar $5}
[ -n "$GRAVA" ] && : > "$GRAVA"
MU_GRAVAR=$GRAVA MU_PONTE=$PWD/testes/ponte_unix.py MU_SOCKETS=$RAIZ/sockmu \
  timeout $((SEG + 30)) "$GODOT" --headless --path . -- --auto "$AUTO" --cacar "$N" --sair "$SEG" $ANDAR $MU_EXTRA 2>&1 \
  | grep -E "TESTE|ERROR|SCRIPT" | grep -v "TESTE item no chao" ; echo "fim"
