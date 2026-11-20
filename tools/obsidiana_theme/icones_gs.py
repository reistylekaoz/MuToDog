#!/usr/bin/env python3
"""Rodada 12 (gear score): leva do cliente Godot pro MuMain
- dados/gear_score_base.json (o Base Score de cada item, ferramentas/gear_score_tabela.py tira do banco do servidor)
  pra Data/Interface/RmlUi/dados/gear_score_base.json;
- o ícone do GS (icones/hud/buff_gs.png, ferramentas/icones/icones_hud.py) pra themes/modern/menu_f10/buff_gs.ozt,
  80 x 80 como o buff_colecao (icones_colecoes.py).
Uso: python3 tools/obsidiana_theme/icones_gs.py [pasta godot]"""
import shutil
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gerar import TEMAS, ozt  # noqa: E402

GODOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / "casa/trabalho/mu-online/godot"


def main():
    dados = TEMAS.parent / "dados"
    shutil.copyfile(GODOT / "dados/gear_score_base.json", dados / "gear_score_base.json")
    tmp = TEMAS / "modern/menu_f10/buff_gs.png"
    Image.open(GODOT / "icones/hud/buff_gs.png").convert("RGBA").resize((80, 80), Image.LANCZOS).save(tmp)
    ozt(tmp, tmp.with_suffix(".ozt"))
    tmp.unlink()
    print("gear score: tabela e icone prontos")


if __name__ == "__main__":
    main()
