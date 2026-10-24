#!/bin/bash
# Dois clientes juntos contra o OpenMU daqui (../servidor.sh ligar-teste): troca e loja pessoal.
# Uso: testes/dois.sh "conta,senha,Pers1" "--troca Pers2" "conta,senha,Pers2" "--aceitar 1" [segundos]
# GRAVAR_A=arquivo e GRAVAR_B=arquivo gravam o que cada um recebe (MU_GRAVAR) pras fotos no navegador
cd "$(dirname "$0")/.."
RAIZ=$(cd .. && pwd)
GODOT=${GODOT:-$HOME/casa/trabalho/.ferramentas/godot/Godot_v4.7.2-stable_linux.x86_64}
[ -S "$RAIZ/sockmu/44405" ] || { echo "ligue antes: $RAIZ/servidor.sh ligar-teste"; exit 2; }
SEG=${5:-40}
roda() {
  MU_GRAVAR=$4 MU_PONTE=$PWD/testes/ponte_unix.py MU_SOCKETS=$RAIZ/sockmu \
    timeout $((SEG + 30)) "$GODOT" --headless --path . -- --auto "$1" --sair "$SEG" $2 2>&1 \
    | grep -E "TESTE|ERROR|SCRIPT" | grep -v "TESTE item no chao\|TESTE objeto" | sed "s/^/[$3] /"
}
roda "$1" "$2" A "$GRAVAR_A" &
sleep 4
roda "$3" "$4" B "$GRAVAR_B" &
wait
echo "fim"
