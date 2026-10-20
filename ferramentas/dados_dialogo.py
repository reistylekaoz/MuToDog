"""Tira do cliente S6 os dialogos de NPC (CNewUINPCDialogue do MuMain): godot/dados/npc_dialogo.json.
NPCDialogue.bmd: entradas de 88 bytes (indice uint32 = npc * 0x10000 + estado, fala int32, 10 respostas
[texto int32, resultado int32]), cada uma com a cifra BuxConvert (^ FC CF AB) recomecando nela.
QuestWords_eng.bmd: [indice int32, tamanho int16] e o texto UTF-8, cada pedaco cifrado a parte.
Resultado: ate 900 = vai pro estado, 901 lista de quests, 902 buff do NPC (C1 F6 31), 903 a 907 gens.
Uso: python3 ferramentas/dados_dialogo.py"""
import json, os, struct

AQUI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCAL = os.path.join(AQUI, "s6", "cliente", "MU Client 1.04d - Season 6E3", "Data", "Local")
SAIDA = os.path.join(AQUI, "godot", "dados")
CHAVE = (0xFC, 0xCF, 0xAB)


def decifra(b):
    return bytes(x ^ CHAVE[i % 3] for i, x in enumerate(b))


palavras = {}
b = open(os.path.join(LOCAL, "Eng", "QuestWords_eng.bmd"), "rb").read()
i = 0
while i + 6 <= len(b):
    idx, n = struct.unpack("<ih", decifra(b[i:i + 6]))
    palavras[idx] = decifra(b[i + 6:i + 6 + n]).split(b"\0")[0].decode("utf-8", "replace")
    i += 6 + n

dialogo = {}
b = open(os.path.join(LOCAL, "NPCDialogue.bmd"), "rb").read()
for o in range(0, len(b) - 87, 88):
    v = struct.unpack("<I21i", decifra(b[o:o + 88]))
    npc, estado = v[0] >> 16, v[0] & 0xFFFF
    respostas = [[palavras.get(v[2 + 2 * k], ""), v[3 + 2 * k]] for k in range(10) if v[2 + 2 * k]]
    dialogo["%d,%d" % (npc, estado)] = {"fala": palavras.get(v[1], ""), "respostas": respostas}

json.dump({"dialogo": dialogo, "lista_quests": [palavras.get(1501, ""), palavras.get(1502, "")]},
          open(os.path.join(SAIDA, "npc_dialogo.json"), "w"), ensure_ascii=False, indent=0, sort_keys=True)
print(len(palavras), "palavras,", len(dialogo), "estados:", sorted({k.split(",")[0] for k in dialogo}))
print(json.dumps({k: v for k, v in dialogo.items() if k.startswith("257,")}, ensure_ascii=False, indent=1))
