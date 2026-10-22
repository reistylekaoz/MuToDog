"""Quests novas do S6 (sistema F6, CQuestMng do MuMain): godot/dados/quest_nova.json.
QuestProgress.bmd: entradas de 41 bytes (indice uint32 = grupo << 16 | passo; tipo de janela uint8, fala do NPC,
fala do jogador, 5 respostas, assunto e resumo, todos int32 = indice no QuestWords), cada uma com a cifra
BuxConvert (^ FC CF AB) recomecando nela. Texto do QuestWords_eng.bmd (mesma leitura do dados_dialogo.py).
Saida: {"passos": {"<indice>": [janela, fala, fala do jogador, [respostas], assunto, resumo]}, "palavras": {1007, 1501, 1502}}
Passo sem respostas = mostra o que a quest pede e o que da (C1 F6 0C).
Uso: python3 ferramentas/dados_quest_nova.py"""
import json, os, struct

AQUI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCAL = os.path.join(AQUI, "s6", "cliente", "MU Client 1.04d - Season 6E3", "Data", "Local")
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

passos = {}
b = open(os.path.join(LOCAL, "QuestProgress.bmd"), "rb").read()
for o in range(0, len(b) - 40, 41):
    v = struct.unpack("<IB9i", decifra(b[o:o + 41]))
    p = lambda k: palavras.get(k, "") if k else ""
    passos[str(v[0])] = [v[1], p(v[2]), p(v[3]), [p(k) for k in v[4:9] if k], p(v[9]), p(v[10])]

json.dump({"passos": passos, "palavras": {k: palavras.get(k, "") for k in (1007, 1501, 1502)}},
          open(os.path.join(AQUI, "godot", "dados", "quest_nova.json"), "w"), ensure_ascii=False, indent=0, sort_keys=True)
grupos = {}
for k in passos:
    grupos.setdefault(int(k) >> 16, []).append(int(k) & 0xFFFF)
print(len(passos), "passos;", {g: len(v) for g, v in sorted(grupos.items())})
