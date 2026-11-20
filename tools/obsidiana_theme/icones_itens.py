#!/usr/bin/env python3
"""Rodada 15 (Mercado): os ícones de todos os itens, tirados do atlas do cliente Godot (dados/icones.png + icones.json),
numa folha só, 40 x 40 por item, 32 por linha: themes/modern/itens/todos.ozt. O @spritesheet (item-<grupo>-<numero>)
é escrito entre as marcas /* sprites */ do mercado.rcss do modern e do legacy (o obsidiana vem do modern), e a lista
das chaves que têm desenho vai pra dados/itens_icones.json (o C++ só põe decorator no que existe).
A TDC (a moeda da casa, 255,255) é desenhada aqui: moeda de ouro com T, como no Godot (janela_mercado.gd).
Uso: python3 tools/obsidiana_theme/icones_itens.py [pasta godot]"""
import json
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gerar import TEMAS, ozt  # noqa: E402

GODOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / "casa/trabalho/mu-online/godot"
LADO, POR_LINHA = 40, 32


def icone(atlas, caixa, lado):
    x, y, w, h = caixa
    im = atlas.crop((x, y, x + w, y + h))
    e = min(lado / w, lado / h)
    im = im.resize((max(1, round(w * e)), max(1, round(h * e))), Image.LANCZOS)
    casa = Image.new("RGBA", (lado, lado))
    casa.paste(im, ((lado - im.width) // 2, (lado - im.height) // 2), im)
    return casa


def tdc(lado):
    g = 4 * lado
    im = Image.new("RGBA", (g, g))
    d = ImageDraw.Draw(im)
    d.ellipse((g * 0.12, g * 0.12, g * 0.88, g * 0.88), fill=(212, 174, 106, 255))
    d.ellipse((g * 0.2, g * 0.2, g * 0.8, g * 0.8), fill=(150, 110, 40, 255))
    try:
        f = ImageFont.truetype("DejaVuSans-Bold.ttf", int(g * 0.42))
    except OSError:
        f = ImageFont.load_default()
    d.text((g / 2, g / 2), "T", font=f, fill=(255, 240, 200, 255), anchor="mm")
    return im.resize((lado, lado), Image.LANCZOS)


def main():
    caixas = json.loads((GODOT / "dados/icones.json").read_text())
    atlas = Image.open(GODOT / "dados/icones.png").convert("RGBA")
    # "14,11+8" é a caixa por nível: o mercado mostra o desenho do item (grupo,numero)
    caixas = {k: v for k, v in caixas.items() if "+" not in k}
    chaves = sorted(caixas, key=lambda k: tuple(int(x) for x in k.split(","))) + ["255,255"]
    linhas = (len(chaves) + POR_LINHA - 1) // POR_LINHA
    folha = Image.new("RGBA", (LADO * POR_LINHA, LADO * linhas))
    sprites = []
    for k, chave in enumerate(chaves):
        x, y = (k % POR_LINHA) * LADO, (k // POR_LINHA) * LADO
        folha.paste(tdc(LADO) if chave == "255,255" else icone(atlas, caixas[chave], LADO), (x, y))
        g, n = chave.split(",")
        sprites.append(f"\titem-{g}-{n}: {x}px {y}px {LADO}px {LADO}px;")
    pasta = TEMAS / "modern/itens"
    pasta.mkdir(exist_ok=True)
    tmp = pasta / "todos.png"
    folha.save(tmp)
    ozt(tmp, pasta / "todos.ozt")
    tmp.unlink()
    (TEMAS.parent / "dados/itens_icones.json").write_text(json.dumps(chaves, separators=(",", ":")) + "\n")
    bloco = ("/* sprites */\n@spritesheet itens-todos\n{\n\tsrc: \"../modern/itens/todos.tga\";\n"
             + "\n".join(sprites) + "\n}\n/* fim dos sprites */")
    for tema in ("modern", "legacy"):
        rcss = TEMAS / tema / "mercado.rcss"
        texto = rcss.read_text()
        novo = re.sub(r"/\* sprites \*/.*?/\* fim dos sprites \*/", lambda _: bloco, texto, flags=re.S)
        assert novo != texto or bloco in texto, rcss
        rcss.write_text(novo)
    print(f"itens: {len(chaves)} icones, folha {folha.width} x {folha.height}")


if __name__ == "__main__":
    main()
