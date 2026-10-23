"""Nivel e vida maxima de cada monstro, do banco do OpenMU daqui -> godot/dados/monstros_vida.json ({numero: [nivel, vida]}).
O servidor nao manda a vida do monstro pro cliente 1.04d; com a vida maxima o cliente estima a barra pelo dano que viu.
Uso: python3 ferramentas/monstros_vida.py"""
import json, os, subprocess

AQUI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
q = ("select m.\"Number\", split_part(d.\"Designation\",'||',1), a.\"Value\" from config.\"MonsterAttribute\" a "
     "join config.\"AttributeDefinition\" d on d.\"Id\"=a.\"AttributeDefinitionId\" join config.\"MonsterDefinition\" m "
     "on m.\"Id\"=a.\"MonsterDefinitionId\" where split_part(d.\"Designation\",'||',1) in ('Level','Maximum Health')")
r = subprocess.run(["psql", "-h", os.path.join(AQUI, "sock"), "-U", "postgres", "-d", "openmu", "-qAt", "-F", "\t", "-c", q],
                   capture_output=True, text=True, check=True, env=dict(os.environ, PGPASSWORD="local"))
d = {}
for l in r.stdout.splitlines():
    n, k, v = l.split("\t")
    d.setdefault(n, [0, 0])[0 if k == "Level" else 1] = int(float(v))
json.dump(d, open(os.path.join(AQUI, "godot", "dados", "monstros_vida.json"), "w"), separators=(",", ":"))
print(len(d), "monstros")
