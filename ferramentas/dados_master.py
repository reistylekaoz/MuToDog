"""Arvore de skills master do S6 (janela A, CNewUIMasterLevel do MuMain): godot/dados/master.json e as imagens
da janela em godot/dados/hud/master_*.png.
MasterSkillTreeData.bmd: 512 entradas de 24 bytes (indice u16, classes u16 em bits, grupo u8, pontos u8, maximo u8,
seta u8, 2 skills pedidas u32, skill u32, valor inicial float), cada uma com a cifra BuxConvert recomecando nela.
Eng/skill_eng.bmd: 650 skills de 88 bytes (nome 32; uso u8 em 55, marca u32 em 56, rank u8 em 71, icone u16 em 72).
Eng/MasterSkillTooltip_eng.bmd: 512 dicas de 616 bytes (skill i32, classes u16, 7 textos 64/256/32/64/64/64/64).
Saida: {"arvore": [[indice, classes, grupo, pontos, maximo, seta, [pedidas], skill, valor]],
        "skills": {"<n>": [nome, rank, icone, marca, uso]}, "dicas": [[skill, classes, [7 textos]]]}
Uso: python3 ferramentas/dados_master.py"""
import json, os, struct, subprocess, sys

AQUI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(AQUI, "s6", "cliente", "MU Client 1.04d - Season 6E3", "Data")
sys.path.insert(0, os.path.join(AQUI, "ferramentas"))
from mucrypt import bux

b = open(os.path.join(DATA, "Local", "MasterSkillTreeData.bmd"), "rb").read()
arvore = []
for i in range(512):
    v = struct.unpack("<HHBBBBIIIf", bux(b[i * 24:i * 24 + 24]))
    if v[0] == 0:
        break
    arvore.append([v[0], v[1], v[2], v[3], v[4], v[5], [v[6], v[7]], v[8], round(v[9], 2)])

sk = open(os.path.join(DATA, "Local", "Eng", "skill_eng.bmd"), "rb").read()
skills = {}
for n in sorted({e[7] for e in arvore} | {r for e in arvore for r in e[6] if r}):
    r = bux(sk[n * 88:n * 88 + 88])
    skills[str(n)] = [r[:32].split(b"\0")[0].decode("latin1"), r[71], struct.unpack_from("<H", r, 72)[0],
                      struct.unpack_from("<I", r, 56)[0], r[55]]
# a marca (skill base) aparece na dica e na regra "skill antes"; o nome dela tambem
for n in [str(s[3]) for s in list(skills.values()) if s[3] and str(s[3]) not in skills]:
    r = bux(sk[int(n) * 88:int(n) * 88 + 88])
    skills[n] = [r[:32].split(b"\0")[0].decode("latin1"), r[71], struct.unpack_from("<H", r, 72)[0],
                 struct.unpack_from("<I", r, 56)[0], r[55]]

t = open(os.path.join(DATA, "Local", "Eng", "MasterSkillTooltip_eng.bmd"), "rb").read()
dicas = []
for i in range(512):
    r = bux(t[i * 616:i * 616 + 616])
    n, c = struct.unpack_from("<iH", r)
    if n == 0:
        break
    textos, o = [], 6
    for tam in (64, 256, 32, 64, 64, 64, 64):
        textos.append(r[o:o + tam].split(b"\0")[0].decode("utf-8", "replace"))
        o += tam
    dicas.append([n, c, textos])

json.dump({"arvore": arvore, "skills": skills, "dicas": dicas},
          open(os.path.join(AQUI, "godot", "dados", "master.json"), "w"), ensure_ascii=False, separators=(",", ":"))

imagens = ["new_Master_back01=master_fundo1", "new_Master_back02=master_fundo2", "new_Master_Icon=master_icones",
           "new_Master_non_Icon=master_icones_apagados", "new_Master_box=master_caixa", "new_Master_exit=master_fechar"]
imagens += ["new_Master_arrow%02d=master_seta%d" % (i, i) for i in range(1, 9)]
subprocess.run([sys.executable, os.path.join(AQUI, "ferramentas", "interface.py"), os.path.join(DATA, "Interface"),
                os.path.join(AQUI, "godot", "dados", "hud")] + imagens, check=True)
print(len(arvore), "entradas na arvore,", len(skills), "skills,", len(dicas), "dicas")
