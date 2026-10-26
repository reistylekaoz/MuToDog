#!/bin/bash
# Rodada 17 contra o OpenMU daqui (../servidor.sh ligar-teste): o Doppelganger de verdade.
#   testes/rodada17_vivo.sh [segundos]: testgmDk ganha o Mirror of Dimensions (/item 14 111), vai pra Devias
#     (2) e fala com o Lugard (540, em 233,66); a janela 0x23 abre e o Enter manda o C1 BF 0E FF. O servidor
#     leva pro mapa 65; /skipwait pula as esperas (entrada e preparo), a moldura liga no C1 BF 10 2 e o
#     roteiro espera o resultado (C1 BF 13). Grava em
#     dados/gravacao_r17.txt.
cd "$(dirname "$0")/.."
RAIZ=$(cd .. && pwd)
GODOT=${GODOT:-$HOME/casa/trabalho/.ferramentas/godot/Godot_v4.7.2-stable_linux.x86_64}
[ -S "$RAIZ/sockmu/44405" ] || { echo "ligue antes: $RAIZ/servidor.sh ligar-teste"; exit 2; }
SEG=${1:-300}
: > dados/gravacao_r17.txt
R='e:2;d:/item_14_111;e:3;p;e:4;d:/move_testgmDk_2_233_69;e:6;N:540;e:15;D:0;e:8;d:/skipwait;e:4;d:/skipwait;e:4;d:/skipwait;e:3'
# e espera: os monstros andam fora da vista do heroi e 3 chegam no circulo em uns 2 min (C1 BF 13 2, derrota).
# O /killall do OpenMU nao serve aqui: depois dele o servidor manda uns 11 mil C1 11 por segundo em 5 objetos
# (0x0202 a 0x0206) e o cliente cai pra 2 fps. A vitoria (Ice Walker, bau, BF 13 0) fica no testes/rodada17.gd.
R="$R;e:200"
MU_GRAVAR=$PWD/dados/gravacao_r17.txt MU_PONTE=$PWD/testes/ponte_unix.py MU_SOCKETS=$RAIZ/sockmu \
  timeout $((SEG + 30)) "$GODOT" --headless --path . -- --auto testgm,testgm,testgmDk $MU_EXTRA --roteiro "$R" --sair "$SEG" 2>&1 \
  | grep --line-buffered -E "TESTE (roteiro|mapa|doppel|janela|falando|musica|evento contagem|aviso|msg|caixa)|ERROR|SCRIPT" | grep --line-buffered -v "TESTE objeto"
