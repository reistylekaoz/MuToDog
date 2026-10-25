#!/bin/bash
# Rodada 14 contra o OpenMU daqui (../servidor.sh ligar-teste): testgmDk (master) tira o Fenrir (barra a
# entrada), cria e pega a Armor of Guardsman (gasta a cada entrada), abre o Chaos Castle, usa a armadura,
# aperta OK, pula a espera da entrada (um 2o /skipwait acabaria o jogo) e caca la dentro.
# Grava em dados/gravacao_cc.txt pras fotos.
# Uso: testes/caos_vivo.sh [segundos]
cd "$(dirname "$0")/.."
RAIZ=$(cd .. && pwd)
GODOT=${GODOT:-$HOME/casa/trabalho/.ferramentas/godot/Godot_v4.7.2-stable_linux.x86_64}
[ -S "$RAIZ/sockmu/44405" ] || { echo "ligue antes: $RAIZ/servidor.sh ligar-teste"; exit 2; }
SEG=${1:-300}
: > dados/gravacao_cc.txt
R='T:8;e:2;d:/item_13_29;e:3;p;e:3;d:/startcc;e:3;u:13,29;e:3;O;e:8;d:/skipwait;K:300'
MU_GRAVAR=$PWD/dados/gravacao_cc.txt MU_PONTE=$PWD/testes/ponte_unix.py MU_SOCKETS=$RAIZ/sockmu \
  timeout $((SEG + 30)) "$GODOT" --headless --path . -- --auto testgm,testgm,testgmDk --roteiro "$R" --sair "$SEG" 2>&1
