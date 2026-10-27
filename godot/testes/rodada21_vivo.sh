#!/bin/bash
# Rodada 21 contra o OpenMU daqui (../servidor.sh ligar-teste, com ferramentas/openmu-castelo.patch): Castle Siege fora
# da batalha. test400Dl (mestre de Lobos, GM so no teste) no Valley of Loren (mapa 30) perto do Guardsman (224 em 86,61):
#   /csestado 1 (inscricao) -> fala com o Guardsman (janela 0x0D, o cliente pede o C1 B2 00 e o B2 03), aba Announce,
#   inscreve (B2 01), aba List (C1 B4); /csestado 3 (marcas) -> /item 14 21 3 e pega o Sign of Lord, Register (B2 04),
#   List; Abandon com a caixa (B2 02, desfaz a inscricao); /csestado 5 (aviso), List (C1 B5); vai ate o Senior
#   (223 em 179,214, janela 0x0C): portoes (C1 B3 01), estatuas (B3 02), impostos (B2 08).
#   Antes: Character test400Dl com CharacterStatus 32 no mapa 30 (93,64) e RegisterMinMembers 1 (Lobos tem poucos);
#   depois volte (backup/test400Dl-posicao-20261027.txt e backup/castelo-config-20261027.txt).
#   Grava em dados/gravacao_r21.txt.
cd "$(dirname "$0")/.."
RAIZ=$(cd .. && pwd)
GODOT=${GODOT:-$HOME/casa/trabalho/.ferramentas/godot/Godot_v4.7.2-stable_linux.x86_64}
[ -S "$RAIZ/sockmu/44405" ] || { echo "ligue antes: $RAIZ/servidor.sh ligar-teste"; exit 2; }
SEG=${1:-200}
: > dados/gravacao_r21.txt
R=${ROTEIRO:-'e:4;d:/csestado_1;e:3;N:224;e:5;C:95x95;e:3;C:95x131;e:4;C:30x405;e:2;d:/csestado_3;e:3;N:224;e:5;C:95x95;e:3;C:95x210;e:4;C:150x95;e:4;C:30x405;e:2;d:/move_test400Dl_30_93_119;e:5;N:219;e:4;O;e:5;N:219;e:4;O;e:5;d:/move_test400Dl_30_93_64;e:5;d:/csestado_1;e:3;N:224;e:5;C:150x95;e:4;C:95x380;e:2;O;e:4;C:30x405;e:2;d:/csestado_2;e:3'}
MU_GRAVAR=$PWD/dados/gravacao_r21.txt MU_PONTE=$PWD/testes/ponte_unix.py MU_SOCKETS=$RAIZ/sockmu \
  timeout $((SEG + 30)) "$GODOT" --headless --path . -- --auto test400,test400,${HEROI:-test400Dl} $MU_EXTRA --roteiro "$R" --sair "$SEG" 2>&1 \
  | grep --line-buffered -E "TESTE (roteiro|mapa mudou|castelo|janela|falando|aviso|msg|caixa|inv|pegou)|ERROR|SCRIPT" | grep --line-buffered -v "TESTE objeto"
