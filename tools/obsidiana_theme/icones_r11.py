#!/usr/bin/env python3
"""Rodada 11 (MuToDog): a arte do horario dos eventos e os icones do F10, tirados do cliente Godot do MU Estudo (Meshy).
- os 9 cartazes dos eventos (godot/icones/eventos/<arte>.png, 320 x 180) cortados no meio na proporcao da arte do
  cartao (200 x 74, como o janela_eventos.gd faz), numa folha 3 x 3 de 320 x 118: themes/modern/eventos/folha.ozt
  (sprites ev-<arte> no eventos.rcss);
- os icones do F10 de Eventos (H) e Log de caca (K): menu_f10/eventos.ozt e menu_f10/log_caca.ozt.
Uso: python3 tools/obsidiana_theme/icones_r11.py [pasta godot]"""
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gerar import TEMAS, ozt  # noqa: E402

GODOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / "casa/trabalho/mu-online/godot"
ARTES = ["bc", "ds", "cc", "hh", "dourado", "dragao", "mago", "kanturu", "goblins"]
W, H = 320, 118


def main():
    pasta = TEMAS / "modern/eventos"
    pasta.mkdir(exist_ok=True)
    folha = Image.new("RGBA", (W * 3, H * 3))
    for k, nome in enumerate(ARTES):
        im = Image.open(GODOT / f"icones/eventos/{nome}.png").convert("RGBA").resize((320, 180), Image.LANCZOS)
        y = (180 - H) // 2
        folha.paste(im.crop((0, y, W, y + H)), ((k % 3) * W, (k // 3) * H))
        print(f"\tev-{nome}: {(k % 3) * W}px {(k // 3) * H}px {W}px {H}px;")
    tmp = pasta / "folha.png"
    folha.save(tmp)
    ozt(tmp, pasta / "folha.ozt")
    tmp.unlink()
    menu = TEMAS / "modern/menu_f10"
    for nome in ("eventos", "log_caca"):
        tmp = menu / f"{nome}.png"
        Image.open(GODOT / f"icones/menu/{nome}.png").convert("RGBA").resize((80, 80), Image.LANCZOS).save(tmp)
        ozt(tmp, tmp.with_suffix(".ozt"))
        tmp.unlink()


if __name__ == "__main__":
    main()
