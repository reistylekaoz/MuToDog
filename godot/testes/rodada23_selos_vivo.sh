#!/bin/bash
# Rodada 23 (selos, scrolls e VIP) contra o OpenMU daqui (../servidor.sh ligar-teste, com ferramentas/openmu-selos.patch e
# ferramentas/selos_openmu.py gravado). test0Dk (nivel 3) em Lorencia 146,129, com W Coin dado por CashShopCoinGrant:
#   compra: caca 3 sem nada (vai e volta da cidade: a loja so abre la); compra Seal of Wealth (1 dia), usa do deposito e da mochila (buff 30); caca 3 (XP x2);
#           compra Scroll of Quickness e Gold Channel Ticket, usa os dois (buffs 44 e 180, VIP); caca 3 (XP x2,5).
#   volta: entra de novo e confere que os buffs voltaram com o tempo que falta (TimedEffectStore).
# Antes e depois: backup/r23-test0Dk-20261027.txt (exp, posicao) e o arquivo efeitos_tempo.json do servidor.
# Uso: testes/rodada23_selos_vivo.sh compra|volta [segundos]   (grava em dados/gravacao_r23_selos_<fase>.txt)
cd "$(dirname "$0")/.."
RAIZ=$(cd .. && pwd)
GODOT=${GODOT:-$HOME/casa/trabalho/.ferramentas/godot/Godot_v4.7.2-stable_linux.x86_64}
[ -S "$RAIZ/sockmu/44405" ] || { echo "ligue antes: $RAIZ/servidor.sh ligar-teste"; exit 2; }
FASE=${1:-compra}
case "$FASE" in
  compra) SEG=${2:-420}; R="e:5;b;w:185,128;e:15;K:3;e:50;w:146,129;e:20;H:x;e:4;H:c,Seal_of_Wealth,0;e:3;H:s;H:u,0;e:3;H:x;e:2;u:13,44;e:3;b;w:185,128;e:15;K:3;e:50;w:146,129;e:20;H:x;e:3;H:c,Scroll_of_Quickness,0;e:3;H:c,Gold_Channel_Ticket,0;e:3;H:s;H:u,0;e:3;H:s;H:u,0;e:3;H:x;e:2;u:14,72;e:2;u:13,124;e:3;b;w:185,128;e:15;K:3;e:50;w:146,129;e:20;b" ;;
  volta) SEG=${2:-30}; R="e:8;b;e:3;b" ;;
esac
: > dados/gravacao_r23_selos_$FASE.txt
MU_GRAVAR=$PWD/dados/gravacao_r23_selos_$FASE.txt MU_PONTE=$PWD/testes/ponte_unix.py MU_SOCKETS=$RAIZ/sockmu \
  timeout $((SEG + 30)) "$GODOT" --headless --path . -- --auto test0,test0,test0Dk --roteiro "${ROTEIRO:-$R}" --sair "$SEG" 2>&1 \
  | grep --line-buffered -E "TESTE (roteiro|loja (0[13B]|caixa|estado)|experiencia|mapa mudou|mirando)|ERROR|SCRIPT" | grep --line-buffered -v "TESTE objeto"
