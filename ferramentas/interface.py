"""Texturas da interface do cliente S6 (Data/Interface) pra PNG: OZJ = 24 bytes + JPEG, OZT = 4 bytes + TGA.
Uso: python3 ferramentas/interface.py <pasta Interface> <saida> nome_no_cliente=nome_png ..."""
import io, os, sys
from PIL import Image

pasta, saida = sys.argv[1], sys.argv[2]
arqs = {f.lower(): f for f in os.listdir(pasta)}
for par in sys.argv[3:]:
    orig, novo = par.split("=")
    base = os.path.splitext(orig)[0].lower()
    for ext, pula in ((".ozt", 4), (".ozj", 24)):
        if base + ext in arqs:
            dados = open(os.path.join(pasta, arqs[base + ext]), "rb").read()[pula:]
            img = Image.open(io.BytesIO(dados))
            img.convert("RGBA").save(os.path.join(saida, novo + ".png"))
            print(novo, img.size, img.mode)
            break
    else:
        print("falta", orig)
