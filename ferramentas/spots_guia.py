"""Spots do guia em Lorencia e Noria, por cima do que o spots.py montou.
Fonte: https://guidemuonline.com/maps/lorencia e /maps/noria (lidos em 23/10/2026; os dados ficam no chunk JS do site:
"spots":[{"tipo","coordenadaX","coordenadaY","cantidadmobs","monsters"}], monstro pelo indice da lista do mapa).
O guia marca so os spots principais (6 em Lorencia, 3 em Noria): cada um entra no lugar exato, com o tipo e a quantidade
dele, trocando o spot mais perto do mesmo monstro. Os outros spots (e os monstros que o guia nao marca) ficam como estao.
Uso: python3 ferramentas/spots_guia.py [--gravar]
Desfazer: python3 ferramentas/spots_guia.py --voltar backup/spots-guia-antes-<data>.json"""
import json, os, subprocess, sys, time

AQUI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAIO = 2
# (mapa, tipo do guia, x, y, monstros, numero do monstro no OpenMU, nome)
GUIA = [
    (0, "high", 44, 57, 5, 7, "Giant"),
    (0, "medium", 33, 102, 4, 4, "Elite Bull Fighter"),
    (0, "low", 64, 198, 3, 1, "Hound"),
    (0, "high", 120, 211, 5, 14, "Skeleton Warrior"),
    (0, "high", 164, 228, 5, 6, "Lich"),
    (0, "low", 180, 60, 3, 0, "Bull Fighter"),
    (3, "low", 231, 229, 3, 31, "Agon"),
    (3, "low", 135, 211, 3, 30, "Forest Monster"),
    (3, "low", 107, 42, 3, 29, "Hunter"),
]
os.environ["PGPASSWORD"] = "local"


def sql(q):
    r = subprocess.run(["psql", "-h", os.path.join(AQUI, "sock"), "-U", "postgres", "-d", "openmu", "-qAt", "-F", "\t",
                        "-v", "ON_ERROR_STOP=1"], input=q, capture_output=True, text=True)
    if r.returncode:
        sys.exit(r.stderr)
    return [l.split("\t") for l in r.stdout.splitlines() if l]


if "--voltar" in sys.argv:
    antes = json.load(open(sys.argv[sys.argv.index("--voltar") + 1]))
    sql("begin;\n" + "\n".join("update config.\"MonsterSpawnArea\" set \"X1\"=%s,\"Y1\"=%s,\"X2\"=%s,\"Y2\"=%s,\"Quantity\"=%s "
                               "where \"Id\"='%s';" % (a[1], a[2], a[3], a[4], a[5], a[0]) for a in antes) + "\ncommit;")
    print("voltou:", len(antes), "spots")
    sys.exit()

antes, q = [], ["begin;"]
for mapa, tipo, x, y, n, monstro, nome in GUIA:
    terreno = bytes.fromhex(sql("select encode(\"TerrainData\",'hex') from config.\"GameMapDefinition\" where \"Number\"=%d"
                                % mapa)[0][0])[3:]
    livres = sum(terreno[(y + j) * 256 + x + i] == 0 for i in range(-RAIO, RAIO + 1) for j in range(-RAIO, RAIO + 1))
    perto = sql("select s.\"Id\", s.\"X1\", s.\"Y1\", s.\"X2\", s.\"Y2\", s.\"Quantity\" from config.\"MonsterSpawnArea\" s "
                "join config.\"GameMapDefinition\" g on g.\"Id\"=s.\"GameMapId\" join config.\"MonsterDefinition\" m on "
                "m.\"Id\"=s.\"MonsterDefinitionId\" where g.\"Number\"=%d and m.\"Number\"=%d and s.\"SpawnTrigger\"=0 and "
                "s.\"X2\"-s.\"X1\"=%d order by greatest(abs(s.\"X1\"+%d-%d), abs(s.\"Y1\"+%d-%d)) limit 1"
                % (mapa, monstro, 2 * RAIO, RAIO, x, RAIO, y))
    if not perto or livres == 0:
        sys.exit("sem spot de %s pra trocar ou (%d, %d) sem chao" % (nome, x, y))
    a = perto[0]
    antes.append(a)
    print("%-9s %-18s %-6s %d em (%d, %d): troca o spot de %s em (%d, %d); %d de 25 tiles andaveis" %
          ("Lorencia" if mapa == 0 else "Noria", nome, tipo, n, x, y, a[5], int(a[1]) + RAIO, int(a[2]) + RAIO, livres))
    q.append("update config.\"MonsterSpawnArea\" set \"X1\"=%d,\"Y1\"=%d,\"X2\"=%d,\"Y2\"=%d,\"Quantity\"=%d where \"Id\"='%s';"
             % (x - RAIO, y - RAIO, x + RAIO, y + RAIO, n, a[0]))

# spot encostado num do guia (menos de 2 tiles de folga) vai pro lugar livre mais perto (5x5 andavel, sem encostar em nenhum)
for mapa in {g[0] for g in GUIA}:
    terreno = bytes.fromhex(sql("select encode(\"TerrainData\",'hex') from config.\"GameMapDefinition\" where \"Number\"=%d"
                                % mapa)[0][0])[3:]
    livre = lambda x, y: all(0 <= x + i < 256 and 0 <= y + j < 256 and terreno[(y + j) * 256 + x + i] == 0
                             for i in range(-RAIO, RAIO + 1) for j in range(-RAIO, RAIO + 1))
    trocados = {a[0] for a in antes}
    guia = [(x, y) for m, _, x, y, _, _, _ in GUIA if m == mapa]
    todos = sql("select s.\"Id\", s.\"X1\", s.\"Y1\", s.\"X2\", s.\"Y2\", s.\"Quantity\" from config.\"MonsterSpawnArea\" s join "
                "config.\"GameMapDefinition\" g on g.\"Id\"=s.\"GameMapId\" where g.\"Number\"=%d and s.\"SpawnTrigger\"=0 and "
                "s.\"X2\"-s.\"X1\"=%d" % (mapa, 2 * RAIO))
    centros = {a[0]: (int(a[1]) + RAIO, int(a[2]) + RAIO) for a in todos if a[0] not in trocados}
    longe = lambda c, d, menos: all(max(abs(c[0] - p[0]), abs(c[1] - p[1])) > d for k, p in menos)
    for a in todos:
        c = centros.get(a[0])
        if c is None or longe(c, 2 * RAIO + 2, [(0, g) for g in guia]):
            continue
        outros = [(k, p) for k, p in centros.items() if k != a[0]] + [(0, g) for g in guia]
        novo = min(((x, y) for x in range(c[0] - 25, c[0] + 26) for y in range(c[1] - 25, c[1] + 26)
                    if livre(x, y) and longe((x, y), 2 * RAIO, outros) and longe((x, y), 2 * RAIO + 2, [(0, g) for g in guia])),
                   key=lambda p: max(abs(p[0] - c[0]), abs(p[1] - c[1])), default=None)
        if novo is None:
            sys.exit("sem lugar pro spot em %s" % (c,))
        centros[a[0]] = novo
        antes.append(a)
        print("  spot de %s em %s encostava no guia: vai pra %s" % (a[5], c, novo))
        q.append("update config.\"MonsterSpawnArea\" set \"X1\"=%d,\"Y1\"=%d,\"X2\"=%d,\"Y2\"=%d where \"Id\"='%s';"
                 % (novo[0] - RAIO, novo[1] - RAIO, novo[0] + RAIO, novo[1] + RAIO, a[0]))

if "--gravar" in sys.argv:
    sql("\n".join(q + ["commit;"]))
    arq = os.path.join(AQUI, "backup", "spots-guia-antes-%s.json" % time.strftime("%Y%m%d-%H%M"))
    json.dump(antes, open(arq, "w"))
    print("gravado; pra desfazer: python3 ferramentas/spots_guia.py --voltar", arq)
