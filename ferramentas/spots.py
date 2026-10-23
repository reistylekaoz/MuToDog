"""Spots de monstro no OpenMU daqui: troca as areas gigantes (um tipo espalhado pelo mapa todo) por spots como no MU,
quadrados de 5x5 com 3 (low), 4 (medium), 5 (big) ou 6 (hot) monstros, renascendo a cada 6 s.
O OpenMU sorteia o ponto de cada renascimento dentro da area (NonPlayerCharacter.GetNewSpawnPoint), entao area pequena = spot.
Mantem o total de cada tipo; o centro do spot e o tile mais longe dos spots ja postos, com os 25 tiles andaveis e fora da zona
segura (TerrainData: 3 bytes de cabecalho e 256x256, andavel = atributo sem bits alem do 1, zona segura = bit 1).
Mexe so em area com SpawnTrigger 0, 4+ monstros e mais de 400 tiles, nos mapas de MAPAS.
Uso: python3 ferramentas/spots.py [--gravar]   (sem --gravar so mostra; com, guarda as areas antigas em backup/ e troca)
Desfazer: python3 ferramentas/spots.py --voltar backup/spots-antes-<data>.json"""
import json, os, random, subprocess, sys, time

AQUI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAPAS = [0, 2, 3, 51]          # Lorencia, Devias, Noria, Elvenland
TAMANHOS = [(3, 3), (4, 4), (5, 2), (6, 1)]   # (monstros, peso); low = 3 como no guidemuonline.com
RAIO = 2                       # 5x5
RENASCER = "6 seconds"
os.environ["PGPASSWORD"] = "local"


def sql(q, ler=True):
    r = subprocess.run(["psql", "-h", os.path.join(AQUI, "sock"), "-U", "postgres", "-d", "openmu", "-qAt", "-F", "\t",
                        "-v", "ON_ERROR_STOP=1"], input=q, capture_output=True, text=True)
    if r.returncode:
        sys.exit(r.stderr)
    return [l.split("\t") for l in r.stdout.splitlines() if l] if ler else r.stdout


def divide(total, rnd):
    """Quebra o total em spots de 3/4/5/6."""
    spots = []
    while total:
        # sobrar 1 ou 2 nao fecha com 3/4/5/6
        ok = [(t, p) for t, p in TAMANHOS if t <= total and total - t not in (1, 2)]
        n = rnd.choices([t for t, _ in ok], [p for _, p in ok])[0]
        spots.append(n)
        total -= n
    return spots


def voltar(arquivo):
    antes = json.load(open(arquivo))
    q = ["begin;", "delete from config.\"MonsterSpawnArea\" where \"Id\" in (%s);" % ",".join("'%s'" % i for i in antes["novos"])]
    for a in antes["areas"]:
        q.append("insert into config.\"MonsterSpawnArea\" values (%s);" % ",".join("NULL" if v is None else "'%s'" % v for v in a))
    for n, d in antes["renascer"].items():
        q.append("update config.\"MonsterDefinition\" set \"RespawnDelay\"='%s' where \"Id\"='%s';" % (d, n))
    sql("\n".join(q + ["commit;"]), False)
    print("voltou:", len(antes["areas"]), "areas,", len(antes["novos"]), "spots apagados")


if "--voltar" in sys.argv:
    voltar(sys.argv[sys.argv.index("--voltar") + 1])
    sys.exit()

gravar = "--gravar" in sys.argv
rnd = random.Random(6)
colunas = [c[0] for c in sql("select column_name from information_schema.columns where table_schema='config' and "
                             "table_name='MonsterSpawnArea' order by ordinal_position")]
antes = {"areas": [], "novos": [], "renascer": {}}
q = ["begin;"]
for mapa in MAPAS:
    gid, nome, terreno = sql("select \"Id\", split_part(\"Name\",'||',1), encode(\"TerrainData\",'hex') from "
                             "config.\"GameMapDefinition\" where \"Number\"=%d" % mapa)[0]
    att = bytes.fromhex(terreno)[3:]
    livre = lambda x, y: 0 <= x < 256 and 0 <= y < 256 and att[y * 256 + x] == 0
    areas = sql("select %s from config.\"MonsterSpawnArea\" where \"GameMapId\"='%s' and \"SpawnTrigger\"=0 and "
                "\"Quantity\">=4 and (abs(\"X2\"-\"X1\")+1)*(abs(\"Y2\"-\"Y1\")+1)>400" %
                (",".join('"%s"' % c for c in colunas), gid))
    pedidos = []
    for a in areas:
        d = dict(zip(colunas, a))
        antes["areas"].append([None if v == "" else v for v in a])
        cand = [(x, y) for x in range(min(int(d["X1"]), int(d["X2"])), max(int(d["X1"]), int(d["X2"])) + 1)
                for y in range(min(int(d["Y1"]), int(d["Y2"])), max(int(d["Y1"]), int(d["Y2"])) + 1)
                if all(livre(x + i, y + j) for i in range(-RAIO, RAIO + 1) for j in range(-RAIO, RAIO + 1))]
        pedidos += [(d, n, cand) for n in divide(int(d["Quantity"]), rnd)]
    rnd.shuffle(pedidos)
    postos, sobrou, cont = [], 0, {}
    for d, n, cand in pedidos:
        melhor, dist = None, -1
        for c in cand:
            m = min((max(abs(c[0] - p[0]), abs(c[1] - p[1])) for p in postos), default=99)
            if m > dist or (m == dist and rnd.random() < 0.3):
                melhor, dist = c, m
        if melhor is None or dist <= 2 * RAIO:
            sobrou += n
            continue
        postos.append(melhor)
        cont[n] = cont.get(n, 0) + 1
        x, y = melhor
        q.append("insert into config.\"MonsterSpawnArea\" (\"Id\",\"MonsterDefinitionId\",\"GameMapId\",\"X1\",\"Y1\",\"X2\","
                 "\"Y2\",\"Direction\",\"Quantity\",\"SpawnTrigger\",\"WaveNumber\") values (gen_random_uuid(),'%s','%s',"
                 "%d,%d,%d,%d,0,%d,0,0) returning \"Id\";" % (d["MonsterDefinitionId"], gid, x - RAIO, y - RAIO,
                                                               x + RAIO, y + RAIO, n))
    for d, _, _ in pedidos:
        antes["renascer"].setdefault(d["MonsterDefinitionId"], None)
    q.append("delete from config.\"MonsterSpawnArea\" where \"Id\" in (%s);" % ",".join("'%s'" % dict(zip(colunas, a))["Id"]
                                                                                 for a in areas))
    print("%-10s %d areas -> %d spots (low %d, medium %d, big %d, hot %d), %d monstros nao couberam" %
          (nome, len(areas), len(postos), cont.get(3, 0), cont.get(4, 0), cont.get(5, 0), cont.get(6, 0),
           sobrou))

ids = ",".join("'%s'" % i for i in antes["renascer"])
for i, d in sql("select \"Id\", \"RespawnDelay\" from config.\"MonsterDefinition\" where \"Id\" in (%s)" % ids):
    antes["renascer"][i] = d
q.append("update config.\"MonsterDefinition\" set \"RespawnDelay\"='%s' where \"Id\" in (%s);" % (RENASCER, ids))
if gravar:
    saida = sql("\n".join(q + ["commit;"]), False)
    antes["novos"] = [l for l in saida.split() if len(l) == 36]
    arq = os.path.join(AQUI, "backup", "spots-antes-%s.json" % time.strftime("%Y%m%d-%H%M"))
    json.dump(antes, open(arq, "w"))
    print("gravado;", len(antes["novos"]), "spots; pra desfazer: python3 ferramentas/spots.py --voltar", arq)
