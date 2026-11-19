#!/usr/bin/env python3
"""Alma (MuToDog, rodada 10): a arte do Meshy e o alma.json, tirados do cliente Godot do MU Estudo.
- dados/alma.json (elementos, marcos, custo de refazer; o mesmo do servidor, ferramentas/alma.py) vai pra
  Data/Interface/RmlUi/dados/alma.json com os acentos nos nomes (o do servidor nao tem);
- os 16 ícones dos elementos, o aro e o cadeado numa folha (128 x 128 cada, 6 por linha): themes/modern/alma/folha.ozt
  (os nomes dos sprites, al-0 ... al-15, al-aro, al-cadeado, estão no alma.rcss);
- o fundo da janela e as 4 cartas (uma por árvore): themes/modern/alma/fundo.ozt e carta_<n>.ozt;
- o ícone do F10 (icones/menu/alma.png) vai pro menu_f10/alma.ozt.
Uso: python3 tools/obsidiana_theme/icones_alma.py [pasta godot]"""
import json
import re
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gerar import TEMAS, ozt  # noqa: E402

GODOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / "casa/trabalho/mu-online/godot"
LADO, POR_LINHA = 128, 6
ACENTOS = {"critico": "crítico", "Experiencia": "Experiência", "Reducao": "Redução", "maximo": "máximo",
           "maxima": "máxima", "min.": "mín.", "max.": "máx.", "Cacador": "Caçador", "Couraca": "Couraça",
           "Essencia": "Essência", "Renovacao": "Renovação"}


def acentuar(texto):
    return re.sub(r"[\w.]+", lambda m: ACENTOS.get(m.group(0), m.group(0)), texto)


def gravar(im, destino):
    tmp = destino.with_suffix(".png")
    im.save(tmp)
    ozt(tmp, destino)
    tmp.unlink()


def main():
    dados = json.loads((GODOT / "dados/alma.json").read_text())
    for t in dados["tipos"].values():
        t[0] = acentuar(t[0])
    for e in dados["elementos"]:
        e["nome"] = acentuar(e["nome"])
    destino = TEMAS.parent / "dados/alma.json"
    destino.write_text(json.dumps(dados, ensure_ascii=False, indent=1) + "\n")

    pasta = TEMAS / "modern/alma"
    pasta.mkdir(exist_ok=True)
    pecas = [GODOT / f"icones/alma/{i}.png" for i in range(16)] + [GODOT / "icones/alma/aro.png",
                                                                   GODOT / "icones/alma/cadeado.png"]
    folha = Image.new("RGBA", (LADO * POR_LINHA, LADO * ((len(pecas) + POR_LINHA - 1) // POR_LINHA)))
    for k, arq in enumerate(pecas):
        im = Image.open(arq).convert("RGBA").resize((LADO, LADO), Image.LANCZOS)
        folha.paste(im, ((k % POR_LINHA) * LADO, (k // POR_LINHA) * LADO))
    gravar(folha, pasta / "folha.ozt")
    gravar(Image.open(GODOT / "icones/alma/fundo.jpg").convert("RGBA"), pasta / "fundo.ozt")
    for n in range(4):
        gravar(Image.open(GODOT / f"icones/alma/carta_{n}.jpg").convert("RGBA"), pasta / f"carta_{n}.ozt")
    menu = Image.open(GODOT / "icones/menu/alma.png").convert("RGBA").resize((80, 80), Image.LANCZOS)
    gravar(menu, TEMAS / "modern/menu_f10/alma.ozt")
    print(f"alma: {len(dados['elementos'])} elementos, folha {folha.size}")


if __name__ == "__main__":
    main()
