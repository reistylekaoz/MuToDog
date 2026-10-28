"""Data/Local/ServerList.bmd pra godot/dados/servidores.json (CServerListManager::LoadServerListScript).
Cada grupo: WORD indice, char nome[32], BYTE posicao (0 esquerda, 1 direita, 2 meio), BYTE ordem,
BYTE nonpvp[15], short tamanho da descricao, e a descricao. Tudo passa pelo BuxConvert (xor FC CF AB).
Uso: python3 ferramentas/dados_servidores.py <ServerList.bmd> <saida.json>"""
import json, struct, sys

CHAVE = (0xFC, 0xCF, 0xAB)


def bux(b):
    return bytes(x ^ CHAVE[i % 3] for i, x in enumerate(b))


d = open(sys.argv[1], "rb").read()
grupos, o = [], 0
while o + 53 <= len(d):
    r = bux(d[o:o + 53])
    o += 53
    n, = struct.unpack_from("<h", r, 51)
    desc = bux(d[o:o + n]).split(b"\0")[0].decode("utf-8", "replace").strip()
    o += n
    grupos.append({"indice": struct.unpack_from("<H", r, 0)[0], "nome": r[2:34].split(b"\0")[0].decode("utf-8"),
                   "posicao": r[34], "ordem": r[35], "nonpvp": list(r[36:51]), "descricao": desc})
json.dump(grupos, open(sys.argv[2], "w"), ensure_ascii=False, indent=1)
print(len(grupos), "grupos:", ", ".join(g["nome"] for g in grupos))
