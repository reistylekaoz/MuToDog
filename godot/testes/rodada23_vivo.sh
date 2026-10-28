#!/bin/bash
# Rodada 23 contra o OpenMU daqui (../servidor.sh ligar-teste): a loja de cash (In-Game Shop).
# test400Dl (GM so no teste, pro /move) na cidade de Lorencia, com 10000 W Coin (C), 10000 W Coin (P) e 20000 Goblin
# Points dados por CashShopCoinGrant (o servidor aplica no D2 01):
#   X abre (D2 02), saldo e deposito; Goblin Point > Box > Box of Kundun +1 (Buy, confirmar: D2 03);
#   Buff > Cherry Blossom Petal; W Coin (C) > Special > Gold Channel Ticket (4 precos, o 3o; o OpenMU nao vende);
#   W Coin (P) > Special, pagina 3 > [Vault Expansion Certificate] de presente pra test400Dk (mesma conta, D2 04);
#   Use no primeiro item do deposito (D2 0B: o Box of Kundun vai pra mochila); aba Gift Inventory (D2 0E); X fecha.
#   Antes e depois: backup/r23-personagens-20261027.txt (status, posicao, moedas) e apagar grants e deposito.
#   Grava em dados/gravacao_r23.txt.
cd "$(dirname "$0")/.."
RAIZ=$(cd .. && pwd)
GODOT=${GODOT:-$HOME/casa/trabalho/.ferramentas/godot/Godot_v4.7.2-stable_linux.x86_64}
[ -S "$RAIZ/sockmu/44405" ] || { echo "ligue antes: $RAIZ/servidor.sh ligar-teste"; exit 2; }
SEG=${1:-150}
: > dados/gravacao_r23.txt
R=${ROTEIRO:-"e:5;d:/move_test400Dl_0_135_128;e:5;H:x;e:4;H:s;H:285x11;H:49x77;H:310x260;H:265x335;H:286x278;e:3;H:s;H:320x242;H:49x110;H:188x139;H:265x335;H:286x278;e:3;H:320x242;H:133x11;H:49x44;H:188x139;H:242x280;H:264x363;H:286x278;e:3;H:320x242;H:209x11;H:317x408;H:317x408;H:432x139;H:321x335;H:n,test400Dk,presente_do_estudo;H:276x324;H:286x278;e:3;H:320x242;H:s;H:598x409;H:284x294;H:284x278;e:4;H:s;H:320x242;H:557x218;e:3;H:s;H:x;e:3"}
MU_GRAVAR=$PWD/dados/gravacao_r23.txt MU_PONTE=$PWD/testes/ponte_unix.py MU_SOCKETS=$RAIZ/sockmu \
  timeout $((SEG + 30)) "$GODOT" --headless --path . -- --auto test400,test400,${HEROI:-test400Dl} $MU_EXTRA --roteiro "$R" --sair "$SEG" 2>&1 \
  | grep --line-buffered -E "TESTE (roteiro|mapa mudou|loja|caixa|msg)|ERROR|SCRIPT" | grep --line-buffered -v "TESTE objeto"
