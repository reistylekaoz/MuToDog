#!/bin/bash
# Cliente contra o OpenMU daqui, sem porta: o servidor escuta em socket Unix
# (../servidor.sh ligar-teste) e o cliente fala por testes/ponte_unix.py.
cd "$(dirname "$0")/.."
RAIZ=$(cd .. && pwd)
GODOT=${GODOT:-$HOME/casa/trabalho/.ferramentas/godot/Godot_v4.7.2-stable_linux.x86_64}
[ -S "$RAIZ/sockmu/44405" ] || { echo "ligue antes: $RAIZ/servidor.sh ligar-teste"; exit 2; }
MU_DEBUG=${MU_DEBUG:-} MU_PONTE=$PWD/testes/ponte_unix.py MU_SOCKETS=$RAIZ/sockmu \
  timeout 120 "$GODOT" --headless --path . -s testes/rede_teste.gd 2>&1 | grep -E "TESTE|REDE|ERROR|SCRIPT|WARNING"
