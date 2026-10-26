#!/bin/bash
# Rodada 18 contra o OpenMU daqui (../servidor.sh ligar-teste): o Imperial Fortress de verdade.
#   testes/rodada18_vivo.sh [segundos]: testgmDk ganha o Gaion's Order (/item 14 102, cai no chao e o roteiro
#     pega), vai pra Devias e fala com o Jerint (522, em 229,221); a janela 0x24 abre e o Enter manda o C1 F7 01.
#     O servidor leva pro mapa do dia (segunda e quinta 69, terca e sexta 70, quarta e sabado 71, domingo 72 com
#     o Complete Secromicon) e manda o F7 02 (dia, zona, clima); /skipwait pula a espera e o F7 04 traz o tempo
#     e os monstros a cada segundo. Sem /killall: aqui ele inunda de C1 11 (10 mil por segundo) e trava o
#     cliente; zona limpa (F7 06 1) e vitoria (F7 06 2) ficam no testes/rodada18.gd. Em 229,224 o terreno e
#     bloqueado e o servidor manda pro nascer da cidade: por isso 229,218. Grava em dados/gravacao_r18.txt.
# O OpenMU pede grupo pra entrar (IsPartyRequired); aqui o teste roda com um personagem so, entao a configuracao
# do plugin no banco local foi trocada pra false (config."PlugInConfiguration", TypeId 7e3b9c15...).
# Depois de um evento a conta pode ficar presa (F1 01 03): ../servidor.sh desligar; ../servidor.sh ligar-teste.
cd "$(dirname "$0")/.."
RAIZ=$(cd .. && pwd)
GODOT=${GODOT:-$HOME/casa/trabalho/.ferramentas/godot/Godot_v4.7.2-stable_linux.x86_64}
[ -S "$RAIZ/sockmu/44405" ] || { echo "ligue antes: $RAIZ/servidor.sh ligar-teste"; exit 2; }
SEG=${1:-600}
: > dados/gravacao_r18.txt
R='e:2;d:/item_14_102;e:3;p;e:4;d:/move_testgmDk_2_229_218;e:6;N:522;e:8;Y:0;e:10;d:/skipwait;e:4;d:/skipwait;e:6'
R="$R;e:150"
MU_GRAVAR=$PWD/dados/gravacao_r18.txt MU_PONTE=$PWD/testes/ponte_unix.py MU_SOCKETS=$RAIZ/sockmu \
  timeout $((SEG + 30)) "$GODOT" --headless --path . -- --auto testgm,testgm,testgmDk $MU_EXTRA --roteiro "$R" --sair "$SEG" 2>&1 \
  | grep --line-buffered -E "TESTE (roteiro|mapa|imperial|janela|falando|musica|fundo|evento contagem|aviso|msg|caixa)|ERROR|SCRIPT" | grep --line-buffered -v "TESTE objeto"
