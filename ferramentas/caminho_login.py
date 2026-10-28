"""Caminho da camera da tela de login (Data/World74/CWScript74.cws) pra godot/dados/mundo74/caminho.json.
CCameraMove::LoadCameraWalkScript: 'CWS\\0', quantidade (uint32) e pontos de 28 bytes
(indice do tile, x, y, z, demora em quadros, aceleracao, nivel da distancia).
Sai [x, y, demora, aceleracao, nivel] por ponto.
Uso: python3 ferramentas/caminho_login.py [pasta Data]"""
import json, os, struct, sys

data = sys.argv[1] if len(sys.argv) > 1 else "s6/cliente/MU Client 1.04d - Season 6E3/Data"
d = open(os.path.join(data, "World74", "CWScript74.cws"), "rb").read()
assina, n = struct.unpack_from("<II", d, 0)
assert assina == 0x00535743, hex(assina)
pontos = []
for i in range(n):
    _, x, y, _z, demora, acel, nivel = struct.unpack_from("<i3fi2f", d, 8 + i * 28)
    pontos.append([round(x, 2), round(y, 2), demora, round(acel, 3), round(nivel, 3)])
json.dump(pontos, open("godot/dados/mundo74/caminho.json", "w"))
print(n, "pontos", pontos[0], pontos[-1])
