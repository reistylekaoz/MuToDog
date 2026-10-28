#!/bin/bash
# Rodada 25 contra o OpenMU daqui (../servidor.sh ligar-teste, com ferramentas/openmu-rodada25.patch): os 14 pacotes
# que faltavam. test400Dl (mestre de Lobos, GM so no teste):
#   F3 15 (foco), J (lista de comandos de chat, C2 F5 01) e um comando escolhido;
#   Lorencia 175,122: /item 14 21 (Rena), Golden Archer (236, C1 94), Registering Rena (C1 95), fechar (C1 97);
#   Valley of Loren 139,103: a bandeira com a marca de Lobos (C1 B9 02), Gatekeeper (220, C1 B9 03 tipo 3),
#   abrir pra quem nao e da guilda (C1 B2 1F), preco +1 passo (B2 09 tipo 3), Enter (B9 05, Land of Trials);
#   guarda as teclas (F3 30). O que o OpenMU nao manda vem pelo P: (fica na fita como recebido): F3 22, 0B, B9 01, 69, BF 0A, BA e F6 03.
#   Rodar de novo com "teclas" confere que o F3 30 volta no login.
#   Antes: Lobos dona do castelo com TaxHunt 30000 (backup/castelo-dados-r25-20261028.txt); depois volte o castelo e
#   a posicao (backup/test400Dl-posicao-r25-20261028.txt). Grava em dados/gravacao_r25.txt.
cd "$(dirname "$0")/.."
RAIZ=$(cd .. && pwd)
GODOT=${GODOT:-$HOME/casa/trabalho/.ferramentas/godot/Godot_v4.7.2-stable_linux.x86_64}
[ -S "$RAIZ/sockmu/44405" ] || { echo "ligue antes: $RAIZ/servidor.sh ligar-teste"; exit 2; }
SEG=${2:-215}
if [ "$1" = "teclas" ]; then
  R="e:6"
  SEG=${2:-30}
  : > dados/gravacao_r25b.txt
  GRAV=dados/gravacao_r25b.txt
else
  : > dados/gravacao_r25.txt
  GRAV=dados/gravacao_r25.txt
  R="e:6;e:2;Z:j;e:3;Z:j,/help;e:2;Z:jx;e:3"
  R="$R;d:/move_test400Dl_0_175_123;e:5;d:/item_14_21;e:3;p;e:4;N:236;e:8;Z:arqueiro,90x295;e:4;Z:arqueiro,x;e:2"
  R="$R;P:C1,0B0101;e:8;P:C1,0B0003;e:3;P:C1,F3225802;e:3"
  R="$R;d:/move_test400Dl_30_139_104;e:6;N:220;e:10;Z:gate,60x115;e:3;Z:gate,120x185;e:1;Z:gate,95x230;e:3"
  R="$R;P:C1,B901010000;e:2;P:C1,B901010005;e:2;P:C1,690025001000MEU;e:2;P:C1,BF0A00D7MEU0100MEU;e:3;P:C1,BAMEU2805;e:2;P:C1,F6030500010000000000;e:2"
  R="$R;Z:teclas;e:2;Z:gate,95x330;e:8"
fi
MU_GRAVAR=$PWD/$GRAV MU_PONTE=$PWD/testes/ponte_unix.py MU_SOCKETS=$RAIZ/sockmu \
  timeout $((SEG + 30)) "$GODOT" --headless --path . -- --auto test400,test400,${HEROI:-test400Dl} $MU_EXTRA --roteiro "$R" --sair "$SEG" 2>&1 \
  | grep --line-buffered -E "TESTE (roteiro|mapa mudou|gatekeeper|arqueiro|fichas|comando|teclas|futebol|invasao|skill monstro|nova|corrente|quests|pedra|marca|selecao|foco|caixa|msg)|ERROR|SCRIPT" | grep --line-buffered -v "TESTE objeto"
