#!/usr/bin/env python3
"""Rodada 14 (NPC com nome e ícone sempre à mostra): leva os ícones dos NPCs do cliente Godot (icones/npc/<tipo>.png,
ferramentas/icones/icones_npc.py, os mesmos de cima da cabeça e do minimapa) pra themes/modern/npc/<tipo>.ozt,
96 x 96. As regras de qual NPC leva qual ícone estão em src/source/UI/Estudo/IconesNpc.cpp (cópia do icones_npc.gd).
Uso: python3 tools/obsidiana_theme/icones_npc.py [pasta godot]"""
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gerar import TEMAS, ozt  # noqa: E402

GODOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / "casa/trabalho/mu-online/godot"


def main():
    destino = TEMAS / "modern/npc"
    destino.mkdir(exist_ok=True)
    feitos = 0
    for png in sorted((GODOT / "icones/npc").glob("*.png")):
        tmp = destino / png.name
        Image.open(png).convert("RGBA").resize((96, 96), Image.LANCZOS).save(tmp)
        ozt(tmp, tmp.with_suffix(".ozt"))
        tmp.unlink()
        feitos += 1
    print("npc: %d icones" % feitos)


if __name__ == "__main__":
    main()
