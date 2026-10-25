#!/bin/bash
# O cliente parado no jogo pelo wss do site, igual ao launcher do PC.
cd "$(dirname "$0")/.."
GODOT=${GODOT:-$HOME/casa/trabalho/.ferramentas/godot/Godot_v4.7.2-stable_linux.x86_64}
MU_SITE=mu-estudo.integraction.com.br MU_CHAVE=$(cat ~/casa/trabalho/.segredos/mu-estudo-chave-pc) \
MU_PARADO_S=${1:-360} timeout $(( ${1:-360} + 60 )) "$GODOT" --headless --path . -s testes/parado_wss.gd 2>&1 | grep -E "TESTE|ERROR|SCRIPT"
