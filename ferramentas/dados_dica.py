"""Tira do cliente S6 o que a caixa de informacao do item (RenderItemInfo do MuMain) precisa.
Grava godot/dados/itens_bmd.json ("grupo,numero" -> campos do Item.bmd, nomes em CAMPOS abaixo) e
godot/dados/textos_eng.json (indice -> texto do Text_eng.bmd, o GlobalText do cliente).
Item.bmd: 512 itens por grupo, 84 bytes cada (ITEM_ATTRIBUTE_FILE_LEGACY), cifra BuxConvert (^ FC CF AB).
Text_eng.bmd: cabecalho de 6 bytes, depois [indice int32, tamanho int32, texto com a mesma cifra].
Uso: python3 ferramentas/dados_dica.py"""
import json, os, struct

AQUI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCAL = os.path.join(AQUI, "s6", "cliente", "MU Client 1.04d - Season 6E3", "Data", "Local")
SAIDA = os.path.join(AQUI, "godot", "dados")
CHAVE = (0xFC, 0xCF, 0xAB)
CAMPOS = ["duas_maos", "nivel", "slot", "skill", "larg", "alt", "dano_min", "dano_max", "bloqueio", "defesa",
          "defesa_magica", "velocidade", "andar", "durabilidade", "durabilidade_magica", "magia",
          "forca", "agilidade", "energia", "vitalidade", "comando", "nivel_req", "valor", "zen", "tipo_ataque"]


def decifra(b):
    return bytes(x ^ CHAVE[i % 3] for i, x in enumerate(b))


bmd = open(os.path.join(LOCAL, "Item.bmd"), "rb").read()
itens = {}
for g in range(16):
    for n in range(512):
        r = decifra(bmd[(g * 512 + n) * 84:(g * 512 + n + 1) * 84])
        if r[0] == 0:
            continue  # sem nome: nao existe
        v = struct.unpack_from("<?xHBxHBBBBBBBBBBBBHHHHHHBxiB7B7B", r, 30)
        d = dict(zip(CAMPOS, v[:25]))
        d["duas_maos"] = int(d["duas_maos"])
        d["classes"] = list(v[25:32])       # DW DK Elf MG DL Summoner RF: 0 nao usa, 1 a 3 = a partir de qual evolucao
        d["resistencias"] = list(v[32:39])  # gelo veneno raio fogo terra vento agua
        itens[f"{g},{n}"] = d
json.dump(itens, open(os.path.join(SAIDA, "itens_bmd.json"), "w"), separators=(",", ":"))

b = open(os.path.join(LOCAL, "Eng", "Text_eng.bmd"), "rb").read()
textos, p = {}, 6
while p + 8 <= len(b):
    i, n = struct.unpack_from("<ii", b, p)
    textos[str(i)] = decifra(b[p + 8:p + 8 + n]).split(b"\0")[0].decode("latin1")
    p += 8 + n
json.dump(textos, open(os.path.join(SAIDA, "textos_eng.json"), "w"), ensure_ascii=False, separators=(",", ":"))
print(f"{len(itens)} itens, {len(textos)} textos")
