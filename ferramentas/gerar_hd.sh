#!/bin/bash
# Texturas HD 2x de tudo que o jogo desenha em 3D (ampliar.py, Real-ESRGAN no processador, ~0,5 s cada):
# chao (tiles) e objetos (modelos) de cada mapa, itens (dados/modelos) e personagens/monstros (dados/personagens)
# -> godot/dados/hd/ no mesmo caminho. Altura, luz e mapa sao dados do mapa e ficam de fora.
# Refaz so o que mudou (o ampliar.py pula o que ja e mais novo). Log em saida/gerar_hd.log.
# Uso: bash ferramentas/gerar_hd.sh [mundo1 mundo3 ... | modelos | personagens]   (sem nada = tudo)
cd "$(dirname "$0")/../godot/dados"
PY=$HOME/casa/trabalho/.ferramentas/esrgan/bin/python
export TORCH_CPP_LOG_LEVEL=ERROR
A=../../ferramentas/ampliar.py
alvos=("$@")
[ ${#alvos[@]} -eq 0 ] && alvos=($(ls -d mundo* | sort -V) modelos personagens)
for d in "${alvos[@]}"; do
  if [ "$d" = modelos ] || [ "$d" = personagens ]; then
    mkdir -p ../../saida/hd_tmp/$d; find $d -maxdepth 1 -name '*.png' -exec ln -sf "$PWD/{}" ../../saida/hd_tmp/$d/ \;
    $PY $A ../../saida/hd_tmp/$d hd/$d --escala 2 | tail -1
    continue
  fi
  for sub in tiles modelos; do
    [ -d $d/$sub ] && $PY $A $d/$sub hd/$d/$sub --escala 2 | tail -1
  done
done
echo "fim $(date +%H:%M)"
