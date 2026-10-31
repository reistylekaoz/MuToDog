#!/bin/bash
# Rodada 26 contra o OpenMU daqui (../servidor.sh ligar-teste, com ferramentas/openmu-castelo.patch): tomar a coroa
# ao vivo, com 4 clientes juntos no Valley of Loren (mapa 30):
#   A test400Dl  mestre de Lobos (dona do castelo, GM so no teste) em 93,121: /csestado 5, 6, 7; depois da troca de
#                lados a Lobos vira ataque e ele vai ate a catapulta de ataque (221 em 63,19): janela, area e Shoot.
#   B quest1Dk   mestre de Ursos (inscrita com 5 marcas) em 176,211, do lado da coroa (176,212)
#   C quest3Dk   battle master de Ursos em 167,195, do lado do interruptor 1 (167,194): mortes pelo P: (o OpenMU nao
#                manda o C1 B8 01) e Shift + skill (Z:cs)
#   D ancientDk  assistente de Ursos em 184,196, do lado do interruptor 2 (184,195)
# Com os 2 interruptores e a coroa na mao do mesmo lado, 30 s depois a Ursos vira dona e os lados trocam.
# Antes: Lobos dona (CastleSiegeData), Ursos inscrita, quest3Dk (3) e ancientDk (4) na Ursos, posicoes acima com o
# servidor desligado e test400Dl GM (32); depois volte (backup/openmu-antes-r26-*.dump e backup/*-antes-r26-*.txt).
# Grava dados/gravacao_r26{a,b,c,d}.txt.
cd "$(dirname "$0")/.."
RAIZ=$(cd .. && pwd)
GODOT=${GODOT:-$HOME/casa/trabalho/.ferramentas/godot/Godot_v4.7.2-stable_linux.x86_64}
[ -S "$RAIZ/sockmu/44405" ] || { echo "ligue antes: $RAIZ/servidor.sh ligar-teste"; exit 2; }
SEG=${1:-170}
roda() {
  : > dados/gravacao_r26$3.txt
  MU_GRAVAR=$PWD/dados/gravacao_r26$3.txt MU_PONTE=$PWD/testes/ponte_unix.py MU_SOCKETS=$RAIZ/sockmu \
    timeout $((SEG + 30)) "$GODOT" --headless --path . -- --auto "$1" --roteiro "$2" --sair "$SEG" 2>&1 \
    | grep --line-buffered -E "TESTE (roteiro|mapa mudou|castelo|guerra|catapulta|janela|aviso|msg|caixa|skill)|ERROR|SCRIPT" \
    | grep --line-buffered -v "TESTE objeto" | sed -u "s/^/[$3] /"
}
# o OpenMU nao manda o C1 B2 17 (inicio e fim da batalha): entra pelo P: em cada um, como na rodada 22
roda quest1,quest1,quest1Dk "e:50;P:C1,B21701;e:4;b;e:50;b;e:16;P:C1,B21700;e:4" b &
sleep 3
roda quest3,quest3,quest3Dk "e:50;P:C1,B21701;e:4;b;P:C1,B80104;Z:cs;e:6;P:C1,B80102;Z:cs,1;e:30;b;e:12;P:C1,B21700;e:4" c &
sleep 3
roda ancient,ancient,ancientDk "e:50;P:C1,B21701;e:4;b;e:50;b;e:10;P:C1,B21700;e:4" d &
sleep 3
roda test400,test400,test400Dl "e:18;d:/csestado_5;e:3;d:/csestado_6;e:5;d:/csestado_7;P:C1,B21701;e:55;b;d:/move_test400Dl_30_63_22;e:6;N:221;e:3;C:56x148;e:2;C:95x264;e:8;b;d:/csestado_8;P:C1,B21700;e:4" a &
wait
echo "fim"
