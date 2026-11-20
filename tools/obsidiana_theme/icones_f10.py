#!/usr/bin/env python3
"""Icones do menu F10 e do Reset System (MuToDog, rodada 7): os mesmos do cliente Godot do MU Estudo (Meshy,
godot/icones/menu e godot/icones/hud), em 80 x 80, gravados como OZT em themes/modern/menu_f10/ (o obsidiana herda
do modern). Uso: python3 tools/obsidiana_theme/icones_f10.py [pasta godot/icones]"""
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gerar import TEMAS, ozt  # noqa: E402

ICONES = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / "casa/trabalho/mu-online/godot/icones"
MENU = ["inventario", "personagem", "quests", "mover", "minimapa", "comandos_chat", "comandos", "amigos", "guilda",
        "gens", "cash", "helper", "ligar_helper", "menu_jogo", "ajuda"]
HUD = ["reset", "grand_reset", "agenda"]
# os que levam outro nome no F10: Mercado (rodada 15) usa o ícone do NPC da loja
OUTROS = {"mercado": "npc/loja"}
LADO = 80


def main():
    saida = TEMAS / "modern/menu_f10"
    saida.mkdir(exist_ok=True)
    for pasta, nomes in (("menu", MENU), ("hud", HUD)):
        for nome in nomes:
            tmp = saida / f"{nome}.png"
            Image.open(ICONES / pasta / f"{nome}.png").convert("RGBA").resize((LADO, LADO), Image.LANCZOS).save(tmp)
            ozt(tmp, tmp.with_suffix(".ozt"))
            tmp.unlink()
    for nome, origem in OUTROS.items():
        tmp = saida / f"{nome}.png"
        Image.open(ICONES / f"{origem}.png").convert("RGBA").resize((LADO, LADO), Image.LANCZOS).save(tmp)
        ozt(tmp, tmp.with_suffix(".ozt"))
        tmp.unlink()
    print(f"menu_f10: {len(MENU) + len(HUD) + len(OUTROS)} icones em {saida}")


if __name__ == "__main__":
    main()
