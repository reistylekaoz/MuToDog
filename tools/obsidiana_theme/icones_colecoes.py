#!/usr/bin/env python3
"""Coleções (MuToDog, rodada 8): os ícones das peças dos sets e o colecoes.json, tirados do cliente Godot do MU Estudo.
- dados/colecoes.json (os sets, os pedidos e os bônus; o mesmo do servidor, ferramentas/colecoes.py) vai pra
  Data/Interface/RmlUi/dados/colecoes.json;
- as peças de todos os sets saem do atlas do Godot (dados/icones.png + icones.json) numa folha só, 64 x 64 por peça,
  16 por linha: themes/modern/colecoes/itens.ozt; o @spritesheet (it-<grupo>-<numero>) é escrito entre as marcas
  /* sprites */ do colecoes.rcss do modern e do legacy (o obsidiana vem do modern pelo gerar.py);
- o ícone do F10 (a armadura Dragon Knight, 8,29) e o do buff (icones/hud/buff_colecao.png) vão pro menu_f10/.
Uso: python3 tools/obsidiana_theme/icones_colecoes.py [pasta godot]"""
import json
import re
import shutil
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gerar import TEMAS, ozt  # noqa: E402

GODOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / "casa/trabalho/mu-online/godot"
LADO, POR_LINHA = 64, 16


def icone(atlas, caixas, chave, lado):
    x, y, w, h = caixas[chave]
    im = atlas.crop((x, y, x + w, y + h))
    e = min(lado / w, lado / h)
    im = im.resize((max(1, round(w * e)), max(1, round(h * e))), Image.LANCZOS)
    casa = Image.new("RGBA", (lado, lado))
    casa.paste(im, ((lado - im.width) // 2, (lado - im.height) // 2), im)
    return casa


def main():
    dados = json.loads((GODOT / "dados/colecoes.json").read_text())
    destino = TEMAS.parent / "dados/colecoes.json"
    destino.parent.mkdir(exist_ok=True)
    shutil.copyfile(GODOT / "dados/colecoes.json", destino)
    caixas = json.loads((GODOT / "dados/icones.json").read_text())
    atlas = Image.open(GODOT / "dados/icones.png").convert("RGBA")
    pecas = sorted({tuple(p) for c in dados["colecoes"] for p in c["pecas"]} | {(g, 29) for g in range(7, 12)})
    linhas = (len(pecas) + POR_LINHA - 1) // POR_LINHA
    folha = Image.new("RGBA", (LADO * POR_LINHA, LADO * linhas))
    sprites = []
    for k, (g, n) in enumerate(pecas):
        x, y = (k % POR_LINHA) * LADO, (k // POR_LINHA) * LADO
        folha.paste(icone(atlas, caixas, f"{g},{n}", LADO), (x, y))
        sprites.append(f"\tit-{g}-{n}: {x}px {y}px {LADO}px {LADO}px;")
    pasta = TEMAS / "modern/colecoes"
    pasta.mkdir(exist_ok=True)
    tmp = pasta / "itens.png"
    folha.save(tmp)
    ozt(tmp, pasta / "itens.ozt")
    tmp.unlink()
    bloco = ("/* sprites */\n@spritesheet colecoes-itens\n{\n\tsrc: \"../modern/colecoes/itens.tga\";\n"
             + "\n".join(sprites) + "\n}\n/* fim dos sprites */")
    for tema in ("modern", "legacy"):
        rcss = TEMAS / tema / "colecoes.rcss"
        texto = rcss.read_text()
        rcss.write_text(re.sub(r"/\* sprites \*/.*?/\* fim dos sprites \*/", lambda _: bloco, texto, flags=re.S))
    menu = TEMAS / "modern/menu_f10"
    for nome, im in (("colecoes", icone(atlas, caixas, "8,29", 80)),
                     ("buff_colecao", Image.open(GODOT / "icones/hud/buff_colecao.png").convert("RGBA").resize((80, 80), Image.LANCZOS))):
        tmp = menu / f"{nome}.png"
        im.save(tmp)
        ozt(tmp, tmp.with_suffix(".ozt"))
        tmp.unlink()
    print(f"colecoes: {len(pecas)} pecas em {folha.size}, {len(dados['colecoes'])} sets")


if __name__ == "__main__":
    main()
