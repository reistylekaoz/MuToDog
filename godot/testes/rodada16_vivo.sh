#!/bin/bash
# Rodada 16 contra o OpenMU daqui (../servidor.sh ligar-teste). O OpenMU nao tem o Illusion Temple
# (EventNotImplementedYet): a Mirage nao abre janela e os pacotes C1 BF nao tem quem responda.
#   testes/rodada16_vivo.sh [segundos]: testgmDk vai pra Devias (2) e fala com a Mirage (197,53); sem janela
#     do servidor, o cliente abre a entrada dele e o Enter manda o C1 BF 00 (o OpenMU ignora). Depois vai pro
#     templo 1 (mapa 45, base da MU Alliance) e o roteiro monta os C1 BF que o servidor mandaria (passo I:),
#     usa a Protecao (S:210, sai o C1 BF 02 de verdade) e mostra o resultado. Grava em dados/gravacao_r16.txt.
cd "$(dirname "$0")/.."
RAIZ=$(cd .. && pwd)
GODOT=${GODOT:-$HOME/casa/trabalho/.ferramentas/godot/Godot_v4.7.2-stable_linux.x86_64}
[ -S "$RAIZ/sockmu/44405" ] || { echo "ligue antes: $RAIZ/servidor.sh ligar-teste"; exit 2; }
SEG=${1:-130}
: > dados/gravacao_r16.txt
R='e:2;d:/move_testgmDk_2_197_56;e:6;N:385;e:6;J:0;e:3;J:1;e:2;d:/move_testgmDk_45_138_48;e:12'
R="$R;I:09,0101;e:3;I:01,2c01EUaa5401000001EU2d8a30;e:3;I:06,0c;e:3;S:210;e:2;I:02,0100d2EUEU;e:5;I:07,00d2EU"
R="$R;e:3;I:01,1e01ffff000002000001EU2d8a30;e:6;I:04,020002NOME2d000488130000526976616c00000000002d0100b0040000;e:8"
MU_GRAVAR=$PWD/dados/gravacao_r16.txt MU_PONTE=$PWD/testes/ponte_unix.py MU_SOCKETS=$RAIZ/sockmu \
  timeout $((SEG + 30)) "$GODOT" --headless --path . -- --auto testgm,testgm,testgmDk --roteiro "$R" --sair "$SEG" 2>&1 \
  | grep -E "TESTE (roteiro|mapa|templo|janela|Mirage|falando|musica|pacote 0?BF|aviso|msg)|Mirage|ERROR|SCRIPT" | grep -v "TESTE objeto"
