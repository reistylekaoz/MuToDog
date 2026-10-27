#!/bin/bash
# Rodada 22 contra o OpenMU daqui (../servidor.sh ligar-teste, com ferramentas/openmu-castelo.patch): a batalha do
# Castle Siege. test400Dl (mestre de Lobos, dona do castelo, GM so no teste) no Valley of Loren (mapa 30) em 93,121:
#   /csestado 5 (aviso: Lobos defende, Ursos ataca), /csestado 6 (preparo: alavancas e portoes fechados, C1 B2 19 lado)
#   -> alavanca 219 abre e fecha o portao (B2 13: animacao, som, chao); /csestado 7 (batalha) -> vai ate a catapulta
#   de defesa (222 em 105,188), janela (B7 00), Front yard1 e Shoot (B7 01, pedra, B7 04).
#   O que o OpenMU nao manda vem pelo passo P: do roteiro (fica na fita como recebido): B2 17 inicio, B2 1E relogio,
#   B2 1D comando, C2 B6 e BB pontos do minimapa, B7 02 pedra vinda de longe, B2 14/15/16/18 da coroa e B2 20 perto
#   dos interruptores. O comandante manda o B2 1D pelo minimapa (G:).
#   Antes: Lobos dona (CastleSiegeData), Ursos inscrita com 5 marcas, test400Dl GM (32) em 93,121 do mapa 30;
#   depois volte (backup/test400Dl-posicao-r22-20261027.txt e backup/castelo-dados-r22-20261027.txt).
#   Grava em dados/gravacao_r22.txt.
cd "$(dirname "$0")/.."
RAIZ=$(cd .. && pwd)
GODOT=${GODOT:-$HOME/casa/trabalho/.ferramentas/godot/Godot_v4.7.2-stable_linux.x86_64}
[ -S "$RAIZ/sockmu/44405" ] || { echo "ligue antes: $RAIZ/servidor.sh ligar-teste"; exit 2; }
SEG=${1:-225}
: > dados/gravacao_r22.txt
URSOS=5572736f73000000
QUEST=717565737431446b000000
R=${ROTEIRO:-"e:5;d:/move_test400Dl_30_93_121;e:5;d:/csestado_5;e:3;d:/csestado_6;e:4;N:219;e:3;O;e:6;N:219;e:3;O;e:4;d:/csestado_7;e:3;d:/move_test400Dl_30_104_185;e:5;N:222;e:3;C:56x148;e:2;C:95x264;e:6;P:C1,B21701;P:C1,B21E0137;P:C1,B21D03966E00;P:C1,B21D05787801;P:C2,B6030000006AB46EBE64B8;P:C2,BB02005D7201503C;G:g1;G:c0;G:m40x40;e:2;G:a;G:a;P:C1,B7020270B0;e:6;P:C1,B2140203EU02;e:4;P:C1,B2150088130000;e:4;P:C1,B21600;e:4;P:C1,B21801${URSOS};e:4;d:/move_test400Dl_30_170_198;e:5;P:C1,B22002030102${URSOS}${QUEST};e:6;d:/csestado_8;e:4"}
MU_GRAVAR=$PWD/dados/gravacao_r22.txt MU_PONTE=$PWD/testes/ponte_unix.py MU_SOCKETS=$RAIZ/sockmu \
  timeout $((SEG + 30)) "$GODOT" --headless --path . -- --auto test400,test400,${HEROI:-test400Dl} $MU_EXTRA --roteiro "$R" --sair "$SEG" 2>&1 \
  | grep --line-buffered -E "TESTE (roteiro|mapa mudou|castelo|guerra|catapulta|janela|falando|aviso|msg|caixa)|ERROR|SCRIPT" | grep --line-buffered -v "TESTE objeto"
