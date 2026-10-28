"""Skills de monstro do cliente S6 (C1 69, CheckMonsterSkill): godot/dados/monstro_skills.json.
MonsterSkill.bmd: u32 quantidade, registros de 48 bytes com a cifra BuxConvert (^ FC CF AB) cada um:
indice do monstro (i32), Skill_Num[10] (i32, -1 = vazio), Slot (i32). A posicao da skill na lista escolhe a animacao:
0 MONSTER01_ATTACK1, 1 ATTACK2, 2 ATTACK3, 3 ATTACK4, 4 a 9 ATTACK5.
Uso: python3 ferramentas/dados_monstro_skill.py"""
import json, os, struct

AQUI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(AQUI, "s6", "cliente", "MU Client 1.04d - Season 6E3", "Data")
CHAVE = (0xFC, 0xCF, 0xAB)

d = open(os.path.join(DATA, "Local", "MonsterSkill.bmd"), "rb").read()
n = struct.unpack_from("<I", d)[0]
saida = {}
for i in range(n):
    r = bytes(x ^ CHAVE[j % 3] for j, x in enumerate(d[4 + i * 48:4 + (i + 1) * 48]))
    v = struct.unpack_from("<12i", r)
    saida[str(v[0])] = [s for s in v[1:11]]
open(os.path.join(AQUI, "godot", "dados", "monstro_skills.json"), "w").write(json.dumps(saida, separators=(",", ":")))
print(n, "monstros;", "Selupan (459):", saida.get("459"), "Maya mao (362):", saida.get("362"))
