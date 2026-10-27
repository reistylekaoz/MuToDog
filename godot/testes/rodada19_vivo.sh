#!/bin/bash
# Rodada 19 contra o OpenMU daqui (../servidor.sh ligar-teste): o evento do Kanturu de verdade.
#   testes/rodada19_vivo.sh [segundos]: testgmDk ganha o Moonstone Pendant (/item 13 38, cai no chao, o roteiro
#     pega e veste no anel livre), /startkanturu abre a entrada, /move pro Kanturu 2 perto do Gateway Machine
#     (367 em 141,191), fala com ele (o servidor responde o C1 D1 00 e a janela abre), Enter (C1 D1 01) leva
#     pro mapa 39; /skipwait pula a contagem e as esperas e os C1 D1 03, 05 e 07 chegam com as fases da Maya.
#   Grava em dados/gravacao_r19.txt.
cd "$(dirname "$0")/.."
RAIZ=$(cd .. && pwd)
GODOT=${GODOT:-$HOME/casa/trabalho/.ferramentas/godot/Godot_v4.7.2-stable_linux.x86_64}
[ -S "$RAIZ/sockmu/44405" ] || { echo "ligue antes: $RAIZ/servidor.sh ligar-teste"; exit 2; }
SEG=${1:-300}
: > dados/gravacao_r19.txt
R=${ROTEIRO:-'e:2;d:/item_13_38;e:3;p;e:3;u:13,38;e:2;d:/startkanturu;e:2;d:/move_testgmDk_38_141_185;e:8;N:367;e:6;Q:1;e:10;d:/skipwait;e:8;d:/skipwait;e:8;d:/skipwait;e:200'}
MU_GRAVAR=$PWD/dados/gravacao_r19.txt MU_PONTE=$PWD/testes/ponte_unix.py MU_SOCKETS=$RAIZ/sockmu \
  timeout $((SEG + 30)) "$GODOT" --headless --path . -- --auto testgm,testgm,testgmDk $MU_EXTRA --roteiro "$R" --sair "$SEG" 2>&1 \
  | grep --line-buffered -E "TESTE (roteiro|mapa mudou|kanturu|janela|falando|musica|aviso|msg|caixa|inv)|ERROR|SCRIPT" | grep --line-buffered -v "TESTE objeto"
