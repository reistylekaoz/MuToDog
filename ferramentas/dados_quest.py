"""Quests antigas do S6 (troca de classe: Sebina, Marlon, Apostolo Devin) pra godot/dados/quest_legado.json.
Quest_eng.bmd: 200 registros de 744 bytes (CSQuest::OpenQuestScript do MuMain), cada um com a cifra BuxConvert
recomecando nele: condicoes (shQuestConditionNum, shQuestRequestNum), NPC, nome[32], 16 QuestAct de 24 bytes
(tipo 1 item / 2 monstro, grupo e numero do item ou monstro, nivel, quantidade, tipo do pedido, classe[7], 4 falas)
e 16 QuestRequest de 20 bytes (tipo, quest que precisa estar feita, nivel min e max, zen, fala de erro).
Dialog_eng.bmd: 200 falas de 1024 bytes: texto[300], n respostas, 10 links, 10 retornos, 10 respostas[64].
Retorno 1 = aceitar (confere zen e nivel e manda C1 A2), 2 = fechar, 3 = manda C1 A2 direto.
Uso: python3 ferramentas/dados_quest.py"""
import json, os, struct

AQUI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCAL = os.path.join(AQUI, "s6", "cliente", "MU Client 1.04d - Season 6E3", "Data", "Local", "Eng")
CHAVE = (0xFC, 0xCF, 0xAB)


def decifra(b):
    return bytes(x ^ CHAVE[i % 3] for i, x in enumerate(b))


def texto(b):
    return b.split(b"\0")[0].decode("cp1252", "replace")


quests = []
q = open(os.path.join(LOCAL, "Quest_eng.bmd"), "rb").read()
for i in range(len(q) // 744):
    r = decifra(q[i * 744:(i + 1) * 744])
    nc, nr, npc = struct.unpack_from("<hhH", r, 0)
    if nc <= 0:
        break
    acts = []
    for a in range(nc):
        o = 38 + a * 24
        _, tipo, g, sub, nivel, num, pedido = struct.unpack_from("<BBHBBBB", r, o)
        acts.append({"tipo": tipo, "grupo": g, "numero": sub, "nivel": nivel, "quantos": num, "pedido": pedido,
                     "classes": list(r[o + 8:o + 15]), "falas": list(struct.unpack_from("<4h", r, o + 16))})
    pedidos = []
    for a in range(nr):
        _, tipo, feita, nmin, nmax, _, zen, erro = struct.unpack_from("<BBHHHH2xIh", r, 424 + a * 20)
        pedidos.append({"tipo": tipo, "feita": feita if feita != 65535 else -1, "nivel_min": nmin,
                        "nivel_max": nmax, "zen": zen, "erro": erro})
    quests.append({"npc": npc, "nome": texto(r[6:38]), "acts": acts, "pedidos": pedidos})

falas = {}
d = open(os.path.join(LOCAL, "Dialog_eng.bmd"), "rb").read()
for i in range(len(d) // 1024):
    r = decifra(d[i * 1024:(i + 1) * 1024])
    t = texto(r[:300])
    n, = struct.unpack_from("<i", r, 300)
    if not t:
        continue
    links = struct.unpack_from("<10i", r, 304)
    rets = struct.unpack_from("<10i", r, 344)
    falas[str(i)] = {"texto": t, "respostas": [[texto(r[384 + k * 64:384 + (k + 1) * 64]), links[k], rets[k]]
                                               for k in range(max(0, min(n, 10)))]}

json.dump({"quests": quests, "falas": falas}, open(os.path.join(AQUI, "godot", "dados", "quest_legado.json"), "w"),
          ensure_ascii=False, indent=0)
print(len(quests), "quests:", [(x["npc"], x["nome"]) for x in quests], "·", len(falas), "falas")
