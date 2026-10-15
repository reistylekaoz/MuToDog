"""Tira do banco do OpenMU o que o cliente precisa saber de itens, skills e mapas.
Grava godot/dados/itens_info.json ("grupo,numero" -> [largura, altura, slots, durabilidade, consome, skill,
valor, nivel de drop], os dois ultimos pro preco da loja),
godot/dados/skills.json (numero -> [nome, alcance, tipo, alvo, mana, ag, move_ate_alvo])
e godot/dados/movimento.json: "lista" = a janela Move (M) [indice, nome, zen, nivel, mapa],
"portais" = mapa -> [[numero, x1, y1, x2, y2, nivel, mapa de destino]] (EnterGate: pisou, entra),
"reducao" = classe -> % a menos no nivel pedido (o Magic Gladiator e o Dark Lord pedem 2/3).
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
    d."Durability" dur, d."ConsumeEffectId" is not null or d."Group" = 14 consome, coalesce(s."Number", -1) skill,
    d."Value" valor, d."DropLevel" drop
    from config."ItemDefinition" d left join config."ItemSlotType" t on t."Id" = d."ItemSlotId"
    left join config."Skill" s on s."Id" = d."SkillId"'''):
    slots = [int(x) for x in i["slots"].split(";") if x != ""]
    itens[f'{i["g"]},{i["n"]}'] = [i["w"], i["h"], slots, i["dur"], i["consome"], i["skill"], i["valor"], i["drop"]]

skills = {}
for s in consulta('''select s."Number" n, split_part(s."Name", '||', 1) nome, s."Range" alcance, s."SkillType" tipo,
    s."Target" alvo, s."MovesToTarget" move,
    coalesce((select r."MinimumValue" from config."AttributeRequirement" r join config."AttributeDefinition" a on a."Id" = r."AttributeId"
      where r."SkillId" = s."Id" and a."Designation" like 'Current Mana%'), 0) mana,
    coalesce((select r."MinimumValue" from config."AttributeRequirement" r join config."AttributeDefinition" a on a."Id" = r."AttributeId"
      where r."SkillId" = s."Id" and a."Designation" like 'Current Ability%'), 0) ag
    from config."Skill" s'''):
    skills[str(s["n"])] = [s["nome"], s["alcance"], s["tipo"], s["alvo"], s["mana"], s["ag"], s["move"]]

lista = [[w["i"], w["nome"], w["zen"], w["nivel"], w["mapa"]] for w in consulta('''select w."Index" i,
    split_part(w."Name", '||', 1) nome, w."Costs" zen, w."LevelRequirement" nivel, m."Number" mapa
    from config."WarpInfo" w join config."ExitGate" x on x."Id" = w."GateId"
    join config."GameMapDefinition" m on m."Id" = x."MapId" order by w."Index"''')]
portais = {}
for g in consulta('''select m."Number" mapa, e."Number" n, e."X1" x1, e."Y1" y1, e."X2" x2, e."Y2" y2,
    e."LevelRequirement" nivel, tm."Number" destino
    from config."EnterGate" e join config."GameMapDefinition" m on m."Id" = e."GameMapDefinitionId"
    join config."ExitGate" t on t."Id" = e."TargetGateId" join config."GameMapDefinition" tm on tm."Id" = t."MapId"
    order by 1, 2'''):
    portais.setdefault(str(g["mapa"]), []).append([g["n"], g["x1"], g["y1"], g["x2"], g["y2"], g["nivel"], g["destino"]])
reducao = {str(c["n"]): c["r"] for c in consulta('''select "Number" n, "LevelWarpRequirementReductionPercent" r
    from config."CharacterClass" where "LevelWarpRequirementReductionPercent" > 0''')}

dados = os.path.join(AQUI, "godot", "dados")
json.dump({"lista": lista, "portais": portais, "reducao": reducao}, open(os.path.join(dados, "movimento.json"), "w"),
          separators=(",", ":"), ensure_ascii=False)
json.dump(itens, open(os.path.join(dados, "itens_info.json"), "w"), separators=(",", ":"), sort_keys=True)
json.dump(skills, open(os.path.join(dados, "skills.json"), "w"), separators=(",", ":"), sort_keys=True)
print(f"{len(itens)} itens, {len(skills)} skills, {len(lista)} destinos no Move, {sum(len(v) for v in portais.values())} portais")
