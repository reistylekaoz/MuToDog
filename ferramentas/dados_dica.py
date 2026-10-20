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

# --- set ancient, harmony, socket e opcao 380 (CSItemOption.cpp, UIJewelHarmony.cpp, SocketSystem.cpp,
# ItemAddOptioninfo.cpp do MuMain): grava godot/dados/itens_extra.json
ENG = os.path.join(LOCAL, "Eng")


def nome_c(b):
    return b.split(b"\0")[0].decode("latin1")


extra = {"set_do_item": {}, "sets": {}, "harmonia": [], "socket": [], "op380": {}}
b = open(os.path.join(LOCAL, "itemsettype.bmd"), "rb").read()
for i in range(8192):
    o1, o2 = decifra(b[i * 4:i * 4 + 2])   # a cifra recomeca a cada item
    if o1 not in (0, 255) or o2 not in (0, 255):
        extra["set_do_item"][f"{i // 512},{i % 512}"] = [o1, o2]
b = open(os.path.join(ENG, "itemsetoption_eng.bmd"), "rb").read()
for n in range(64):
    r = decifra(b[n * 110:(n + 1) * 110])
    nome = nome_c(r[:64])
    if not nome:
        continue
    padrao = [[r[64 + o * 2], r[76 + o * 2]] for o in range(6)]   # so a 1a das 2 colunas e usada
    ext = [[r[88 + o], r[90 + o]] for o in range(2)]
    full = [[r[93 + o], r[98 + o]] for o in range(5)]
    itens = sum(1 for v in extra["set_do_item"].values() for x in v if x == n)
    extra["sets"][str(n)] = {"nome": nome, "itens": itens, "contagem": r[92], "padrao": padrao, "ext": ext,
                             "full": full, "classes": list(r[103:110])}
b = decifra(open(os.path.join(ENG, "JewelOfHarmonyOption_eng.bmd"), "rb").read())
for tp in range(3):
    lista = []
    for o in range(10):
        p = (tp * 10 + o) * 180
        lista.append({"nome": nome_c(b[p + 4:p + 64]), "min": struct.unpack_from("<i", b, p + 64)[0],
                      "nivel": list(struct.unpack_from("<14i", b, p + 68))})
    extra["harmonia"].append(lista)
b = open(os.path.join(ENG, "socketitem_eng.bmd"), "rb").read()
for tp in range(3):
    lista = []
    for i in range(50):
        r = decifra(b[(tp * 50 + i) * 104:(tp * 50 + i + 1) * 104])
        _id, cat = struct.unpack_from("<ii", r, 0)
        lista.append({"cat": cat, "nome": nome_c(r[8:72]), "tipo": r[72], "valores": list(struct.unpack_from("<5i", r, 76))})
    extra["socket"].append(lista)
b = decifra(open(os.path.join(LOCAL, "ItemAddOption.bmd"), "rb").read())
for i in range(8192):
    o1, v1, o2, v2 = struct.unpack_from("<BxHBxH", b, i * 16)
    if o1 or o2:
        extra["op380"][f"{i // 512},{i % 512}"] = [o1, v1, o2, v2]
json.dump(extra, open(os.path.join(SAIDA, "itens_extra.json"), "w"), ensure_ascii=False, separators=(",", ":"))
print(f"{len(extra['sets'])} sets, {len(extra['set_do_item'])} itens de set, {len(extra['op380'])} itens 380")
