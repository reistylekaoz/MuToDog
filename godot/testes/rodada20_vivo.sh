#!/bin/bash
# Rodada 20 contra o OpenMU daqui (../servidor.sh ligar-teste): o evento do Crywolf de verdade.
#   testes/rodada20_vivo.sh [segundos]: testgmElf vai pro Crywolf (mapa 34) perto do altar 1 (205 em 125,27; 124,30 e a parede da estatua),
#     o cliente pede o estado (C1 BD 00); /crywolf pula as esperas ate o Ready, a elfa pisa no altar, fala com ele
#     (caixa 2006/2007, OK manda o C1 BD 03), o servidor confirma com o BD 03 e os altares no BD 02; /crywolf
#     comeca a luta (BD 00 estado 4, musica da luta, BD 04 relogio, BD 05 Balgass) e outro /crywolf encerra
#     (BD 07 rank, BD 08 herois, faixa e caixa do resultado).
#   ROTEIRO=... troca os passos (os mapas do Balgass: d:/move_testgmElf_41_..; o Raklion: d:/move_.._57_..).
#   Grava em dados/gravacao_r20.txt.
cd "$(dirname "$0")/.."
RAIZ=$(cd .. && pwd)
GODOT=${GODOT:-$HOME/casa/trabalho/.ferramentas/godot/Godot_v4.7.2-stable_linux.x86_64}
[ -S "$RAIZ/sockmu/44405" ] || { echo "ligue antes: $RAIZ/servidor.sh ligar-teste"; exit 2; }
SEG=${1:-300}
: > dados/gravacao_r20.txt
R=${ROTEIRO:-'e:2;T:8;e:2;d:/move_testgmElf_34_230_40;e:6;W:3;d:/move_testgmElf_34_125_26;e:6;N:205;e:6;O;e:12;W:4;e:50;W:5;e:30'}
MU_GRAVAR=$PWD/dados/gravacao_r20.txt MU_PONTE=$PWD/testes/ponte_unix.py MU_SOCKETS=$RAIZ/sockmu \
  timeout $((SEG + 30)) "$GODOT" --headless --path . -- --auto testgm,testgm,${HEROI:-testgmElf} $MU_EXTRA --roteiro "$R" --sair "$SEG" 2>&1 \
  | grep --line-buffered -E "TESTE (roteiro|mapa mudou|crywolf|raklion|janela|falando|musica|aviso|msg|caixa|inv|mirando)|ERROR|SCRIPT" | grep --line-buffered -v "TESTE objeto"
