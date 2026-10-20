"""Minimapa do Tab: imagem de cada mapa, marcas do cliente S6 e os spots de monstro do OpenMU.
- Data/WorldN/mini_map.OZT -> godot/dados/minimapa/mapa<N-1>.png (512 x 512, 2 pixels por tile)
- Data/Local/Eng/Minimap/Minimap_WorldN_eng.bmd: 100 registros de 116 bytes (BuxConvert)
  [tipo (1 NPC, 2 portal), x, y, giro, nome]
- config.MonsterSpawnArea (so monstro, ObjectKind 0): os pontos do mesmo monstro a ate 12 tiles
  viram um spot [x1, y1, x2, y2, nome, nivel, quantidade]
Grava godot/dados/minimapa.json: mapa -> {"marcas": [...], "spots": [...]}.
Uso: python3 ferramentas/dados_minimapa.py (com o Postgres do OpenMU ligado)"""
import glob, io, json, os, struct, subprocess
from PIL import Image

AQUI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(AQUI, "s6", "cliente", "MU Client 1.04d - Season 6E3", "Data")
SAIDA = os.path.join(AQUI, "godot", "dados")
CHAVE = [0xFC, 0xCF, 0xAB]


def consulta(sql):
    r = subprocess.run(["psql", "-h", os.path.join(AQUI, "sock"), "-U", "postgres", "-d", "openmu", "-At", "-c",
                        f"select coalesce(json_agg(t), '[]') from ({sql}) t"],
                       env={**os.environ, "PGPASSWORD": "local"}, capture_output=True, text=True, check=True,
                       stdin=subprocess.DEVNULL)
    return json.loads(r.stdout)


saida = {}
os.makedirs(os.path.join(SAIDA, "minimapa"), exist_ok=True)
for arq in glob.glob(os.path.join(DATA, "World*", "mini_map.OZT")):
    mapa = int(os.path.basename(os.path.dirname(arq))[5:]) - 1
    img = Image.open(io.BytesIO(open(arq, "rb").read()[4:])).convert("RGBA")
    img.resize((512, 512), Image.LANCZOS).save(os.path.join(SAIDA, "minimapa", f"mapa{mapa}.png"))
    marcas = []
    bmd = os.path.join(DATA, "Local", "Eng", "Minimap", f"Minimap_World{mapa + 1}_eng.bmd")
    if os.path.exists(bmd):
        b = open(bmd, "rb").read()
        for i in range(100):
            e = bytes(x ^ CHAVE[j % 3] for j, x in enumerate(b[i * 116:(i + 1) * 116]))
            if e[0] == 0:
                break
            x, y, giro = struct.unpack_from("<3i", e, 4)
            marcas.append([e[0], x, y, giro, e[16:116].split(b"\0")[0].decode("utf-8", "replace")])
    saida[str(mapa)] = {"marcas": marcas, "spots": []}

pontos = consulta('''select m."Number" mapa, split_part(d."Designation", '||', 1) nome, d."Number" numero,
    a."X1" x1, a."Y1" y1, a."X2" x2, a."Y2" y2, a."Quantity" q,
    coalesce((select ma."Value" from config."MonsterAttribute" ma join config."AttributeDefinition" ad
        on ad."Id" = ma."AttributeDefinitionId" where ma."MonsterDefinitionId" = d."Id" and ad."Designation" = 'Level'), 0) nivel
    from config."MonsterSpawnArea" a join config."GameMapDefinition" m on m."Id" = a."GameMapId"
    join config."MonsterDefinition" d on d."Id" = a."MonsterDefinitionId"
    where d."ObjectKind" = 0 and a."SpawnTrigger" = 0''')

grupos = {}
for p in pontos:
    if str(p["mapa"]) in saida:
        grupos.setdefault((p["mapa"], p["numero"]), []).append(p)
for (mapa, _), lista in grupos.items():
    spots = []   # [x1, y1, x2, y2, quantidade]
    for p in lista:
        r = [min(p["x1"], p["x2"]), min(p["y1"], p["y2"]), max(p["x1"], p["x2"]), max(p["y1"], p["y2"]), p["q"]]
        # junta com os spots a ate 12 tiles (de novo ate parar, um ponto pode ligar dois)
        while True:
            perto = [s for s in spots if r[0] - 12 <= s[2] and s[0] - 12 <= r[2] and r[1] - 12 <= s[3] and s[1] - 12 <= r[3]]
            if not perto:
                break
            for s in perto:
                spots.remove(s)
                r = [min(r[0], s[0]), min(r[1], s[1]), max(r[2], s[2]), max(r[3], s[3]), r[4] + s[4]]
        spots.append(r)
    for s in spots:
        # a mesma area com outro monstro entra no mesmo spot
        igual = [t for t in saida[str(mapa)]["spots"] if t[:4] == s[:4]]
        if igual:
            igual[0][4].append([lista[0]["nome"], int(lista[0]["nivel"]), s[4]])
        else:
            saida[str(mapa)]["spots"].append(s[:4] + [[[lista[0]["nome"], int(lista[0]["nivel"]), s[4]]]])
for m in saida.values():
    for s in m["spots"]:
        s[4].sort(key=lambda x: x[1])

json.dump(saida, open(os.path.join(SAIDA, "minimapa.json"), "w"), ensure_ascii=False, separators=(",", ":"))
for m in sorted(saida, key=int):
    print(m, len(saida[m]["marcas"]), "marcas,", len(saida[m]["spots"]), "spots")
