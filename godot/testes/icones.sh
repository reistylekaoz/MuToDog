#!/bin/bash
# Refaz o atlas dos icones dos itens (dados/icones.png e .json) a partir de dados/itens/*.glb
# (conversor itens). Precisa do Chromium do Playwright (WebGL por swiftshader).
cd "$(dirname "$0")/.."
GODOT=${GODOT:-$HOME/casa/trabalho/.ferramentas/godot/Godot_v4.7.2-stable_linux.x86_64}
"$GODOT" --headless --import >/dev/null 2>&1
mkdir -p build/icones
"$GODOT" --headless --export-release Icones build/icones/index.html >/dev/null 2>&1 || { echo "export falhou"; exit 1; }
node testes/icones.mjs
