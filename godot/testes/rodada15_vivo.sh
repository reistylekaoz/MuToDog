#!/bin/bash
# Rodada 15 contra o OpenMU daqui (../servidor.sh ligar-teste).
#   testes/rodada15_vivo.sh mapas [segundos]: testgmDk vai pra fora da cidade na Lorencia, cria o Lost Map +1,
#     larga no chao (o portao 152 nasce e leva pro Kalima 1), anda la (nadando), vai pra Santa Village (62) e
#     pra Arena (64). Grava em dados/gravacao_r15.txt pras fotos.
#   testes/rodada15_vivo.sh duelo [segundos]: testgmDk e socketDk na Lorencia; o GM chama pro duelo
#     (/duelstart socketDk), o outro aceita (--aceitar), os dois vao pra Arena e o GM para (/duelend).
#     Grava o do GM em dados/gravacao_duelo.txt.
cd "$(dirname "$0")/.."
RAIZ=$(cd .. && pwd)
GODOT=${GODOT:-$HOME/casa/trabalho/.ferramentas/godot/Godot_v4.7.2-stable_linux.x86_64}
[ -S "$RAIZ/sockmu/44405" ] || { echo "ligue antes: $RAIZ/servidor.sh ligar-teste"; exit 2; }
QUAL=${1:-mapas}
SEG=${2:-120}
if [ "$QUAL" = mapas ]; then
  : > dados/gravacao_r15.txt
  R='T:8;e:2;d:/move_testgmDk_0_180_130;e:5;d:/item_14_28_1;e:3;p;e:3;L:14,28;e:12;K:10;e:2;d:/move_testgmDk_62_210_25;e:15;d:/move_testgmDk_64_101_64;e:15'
  MU_GRAVAR=$PWD/dados/gravacao_r15.txt MU_PONTE=$PWD/testes/ponte_unix.py MU_SOCKETS=$RAIZ/sockmu \
    timeout $((SEG + 30)) "$GODOT" --headless --path . -- --auto testgm,testgm,testgmDk --roteiro "$R" --sair "$SEG" 2>&1 \
    | grep -E "TESTE (roteiro|mapa|pacote|ambiente|nadando|aviso|msg)|Kalima|Gate|ERROR|SCRIPT" | grep -v "TESTE objeto"
else
  : > dados/gravacao_duelo.txt
  RA='e:8;d:/move_testgmDk_0_180_130;e:3;d:/move_socketDk_0_181_130;e:6;d:/duelstart_socketDk;e:6;A:socketDk;e:45;d:/duelend;e:10'
  GRAVAR_A=$PWD/dados/gravacao_duelo.txt testes/dois.sh "testgm,testgm,testgmDk" "--roteiro $RA" "socket,socket,socketDk" "--aceitar 1" "$SEG"
fi
