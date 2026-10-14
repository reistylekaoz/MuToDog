"""Tira do banco do OpenMU o que o cliente precisa saber de itens e skills.
Grava godot/dados/itens_info.json ("grupo,numero" -> [largura, altura, slots, durabilidade, consome, skill])
e godot/dados/skills.json (numero -> [nome, alcance, tipo, alvo, mana, ag, move_ate_alvo]).
Uso: python3 ferramentas/exportar_dados.py (com o Postgres do OpenMU ligado: ./servidor.sh ligar)"""
import json, os, subprocess

AQUI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def consulta(sql):
    r = subprocess.run(["psql", "-h", os.path.join(AQUI, "sock"), "-U", "postgres", "-d", "openmu", "-At", "-c",
                        f"select coalesce(json_agg(t), '[]') from ({sql}) t"],
                       env={**os.environ, "PGPASSWORD": "local"}, capture_output=True, text=True, check=True)
    return json.loads(r.stdout)

itens = {}
for i in consulta('''select d."Group" g, d."Number" n, d."Width" w, d."Height" h, coalesce(t."ItemSlots", '') slots,
    d."Durability" dur, d."ConsumeEffectId" is not null or d."Group" = 14 consome, coalesce(s."Number", -1) skill
    from config."ItemDefinition" d left join config."ItemSlotType" t on t."Id" = d."ItemSlotId"
    left join config."Skill" s on s."Id" = d."SkillId"'''):
    slots = [int(x) for x in i["slots"].split(";") if x != ""]
    itens[f'{i["g"]},{i["n"]}'] = [i["w"], i["h"], slots, i["dur"], i["consome"], i["skill"]]

skills = {}
for s in consulta('''select s."Number" n, split_part(s."Name", '||', 1) nome, s."Range" alcance, s."SkillType" tipo,
    s."Target" alvo, s."MovesToTarget" move,
    coalesce((select r."MinimumValue" from config."AttributeRequirement" r join config."AttributeDefinition" a on a."Id" = r."AttributeId"
      where r."SkillId" = s."Id" and a."Designation" like 'Current Mana%'), 0) mana,
    coalesce((select r."MinimumValue" from config."AttributeRequirement" r join config."AttributeDefinition" a on a."Id" = r."AttributeId"
      where r."SkillId" = s."Id" and a."Designation" like 'Current Ability%'), 0) ag
    from config."Skill" s'''):
    skills[str(s["n"])] = [s["nome"], s["alcance"], s["tipo"], s["alvo"], s["mana"], s["ag"], s["move"]]

dados = os.path.join(AQUI, "godot", "dados")
json.dump(itens, open(os.path.join(dados, "itens_info.json"), "w"), separators=(",", ":"), sort_keys=True)
json.dump(skills, open(os.path.join(dados, "skills.json"), "w"), separators=(",", ":"), sort_keys=True)
print(f"{len(itens)} itens, {len(skills)} skills")
