#!/usr/bin/env python3
"""Logo do Mu TD na tela de entrada (27/11, o Murilo escolheu o logo 4 do Gemini): o PNG sem fundo de
mu-online/marca/final, gravado como OZT em Data/Interface/RmlUi/mutd/logo.ozt (login_scene.rml pede logo.tga).
Uso: python3 tools/obsidiana_theme/logo_mutd.py [mutd_logo_1024.png]"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gerar import TEMAS, ozt  # noqa: E402

ORIGEM = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / "casa/trabalho/mu-online/marca/final/mutd_logo_1024.png"


def main():
    saida = TEMAS.parent / "mutd"
    saida.mkdir(exist_ok=True)
    ozt(ORIGEM, saida / "logo.ozt")
    print(f"logo: {saida / 'logo.ozt'}")


if __name__ == "__main__":
    main()
