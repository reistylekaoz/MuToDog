#!/bin/bash
# Exporta o launcher pro Windows (build/MUEstudo.exe, pck embutido com a chave) e monta o zip
# da entrega (build/MUEstudo-launcher.zip). So precisa refazer quando boot.gd mudar: o launcher.gd
# vai no launcher.pck que o godot/testes/publicar_pc.sh poe no ar e o boot baixa sozinho.
set -e
cd "$(dirname "$0")"
G=${GODOT:-$HOME/casa/trabalho/.ferramentas/godot/Godot_v4.7.2-stable_linux.x86_64}
[ -f chave.txt ] || cp ~/casa/trabalho/.segredos/mu-estudo-chave-pc chave.txt
rm -rf build; mkdir -p build
$G --headless --import >/dev/null 2>&1 || true
$G --headless --export-release "Windows" build/MUEstudo.exe 2>&1 | grep -i "error" || true
cp LEIA.txt build/
(cd build && zip -q -9 MUEstudo-launcher.zip MUEstudo.exe LEIA.txt)
ls -la build
