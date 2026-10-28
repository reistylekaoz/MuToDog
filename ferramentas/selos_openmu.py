#!/usr/bin/env python3
"""Selos, scrolls, elixires e o Gold Channel Ticket (VIP) no banco do OpenMU daqui (rodada 23).

O OpenMU S6 lista esses produtos na loja de cash sem item por tras. Este script cria a ItemDefinition de cada um,
o efeito (MagicEffectDefinition com o numero do buff do cliente) e liga os produtos da loja ao item.
Precisa do patch ferramentas/openmu-selos.patch (TimedEffectStore, Stats.ItemDropRate, entrega com dias).

Efeito com SubType de 100 a 199 = dura dias: a durabilidade do item guarda os dias comprados (1 no drop e no /item)
e o tempo do efeito e Duracao x durabilidade. Itens do mesmo SubType nao somam (o novo troca o velho).
O valor do servidor e o texto do cliente (ferramentas/dados_buff.py, TEXTOS) mudam juntos.

Uso: python3 ferramentas/selos_openmu.py            grava (backup em backup/selos-antes-<data>.json)
     python3 ferramentas/selos_openmu.py --voltar backup/selos-antes-<data>.json
Depois: reinicie o OpenMU (a configuracao so e lida na partida).
"""
import json
import os
import subprocess
import sys
import time
import uuid

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOCK = os.path.join(RAIZ, "sock")
CONFIG = "00000001-0001-0000-0000-000000000000"
DIA = 86400
NS = uuid.UUID("5e1a0000-0000-4000-8000-000000000023")

# atributos (Stats.cs); ItemDropRate e novo, vem do patch
A = {
    "xp": "1ad454d4-bef9-416e-bc49-82a5b0277fc7",
    "xp_master": "e367a231-c8a4-4f92-b553-c665f98db1fc",
    "drop": "6e3b1f0a-4c2d-4e8b-9a51-2f7c8d9e0b13",
    "vip": "195474d6-59a2-4033-9c30-8628ecc0097e",
    "velocidade": "da08473f-df5b-444d-8651-9edb65797922",
    "defesa": "0888ad48-0cc8-47ca-b6a3-99f3771aa5fc",
    "fis_min": "3e8d6a02-e973-4ae4-9df3-cddc3d3183b3",
    "fis_max": "8a918ea2-893a-48b2-a684-3e71526ca71f",
    "mag_min": "65583a02-ab94-4a17-9b79-86ecc82dc835",
    "mag_max": "44b8236a-bf5b-4082-ba8b-5deda1458d33",
    "hp": "a6c39a5c-295f-415e-a314-5e9f9a748d27",
    "mana": "17cb8826-0677-4c93-a0c9-c0e3d2da7d73",
    "critico": "ade8092e-870f-4968-b707-8bfd6cbf8ffc",
    "excelente": "577ae8d4-d9e5-4a1f-9a69-45d1a2519eee",
    "hp_rec": "0a427a13-3708-4125-ba83-a2df7c0753b8",
    "mana_rec": "e4ec7913-5004-48fc-acb1-e1764237a251",
    "forca": "f59709a3-44b0-4147-aaeb-e90cec251641",
    "agilidade": "364f1207-00f8-485b-9f2c-74e04cb78c73",
    "vitalidade": "6a0076e4-69dc-42e7-a92b-c8711392ef82",
    "energia": "12956b45-007c-453a-ae1f-36475b8cebbf",
    "comando": "35e04272-63f3-4ebb-8fb5-ef2128ddb9f6",
}
SOMA, VEZES, FINAL = 0, 1, 2

VIP_XP, VIP_DROP = 0.5, 0.2  # VIP: +50% de XP (normal e master) e +20% de drop

# grupo, numero, nome, buff, SubType, segundos por unidade, [(atributo, valor, tipo)], pacotes da loja
ITENS = [
    (13, 43, "Seal of Ascension", 29, 124, DIA, [("xp", 0.5, SOMA)], ["Seal of Ascension"]),
    (13, 44, "Seal of Wealth", 30, 124, DIA, [("xp", 1.0, SOMA), ("drop", 0.5, SOMA)], ["Seal of Wealth"]),
    (13, 45, "Seal of Sustenance", 31, 124, DIA, [("xp", 0, VEZES), ("xp_master", 0, VEZES)], ["Seal of Sustenance"]),
    (13, 93, "Master Seal of Ascension", 101, 124, DIA, [("xp_master", 0.5, SOMA)], ["Master Seal of Ascension"]),
    (13, 94, "Master Seal of Wealth", 102, 124, DIA, [("xp_master", 1.0, SOMA), ("drop", 0.5, SOMA)], ["Master Seal of Wealth"]),
    (13, 62, "Seal of Healing", 87, 113, DIA, [("xp", 0.5, SOMA), ("hp_rec", 0.05, SOMA)], ["Seal of Healing"]),
    (13, 63, "Seal of Divinity", 88, 113, DIA, [("drop", 0.5, SOMA), ("mana_rec", 0.05, SOMA)], ["Seal of Divinity"]),
    (14, 72, "Scroll of Quickness", 44, 167, DIA, [("velocidade", 15, SOMA)], ["Scroll of Quickness"]),
    (14, 73, "Scroll of Defense", 45, 168, DIA, [("defesa", 60, FINAL)], ["Scroll of Protection"]),
    (14, 74, "Scroll of Wrath", 46, 169, DIA, [("fis_min", 30, SOMA), ("fis_max", 30, SOMA)], ["Scroll of Wrath"]),
    (14, 75, "Scroll of Wizardry", 47, 170, DIA, [("mag_min", 30, SOMA), ("mag_max", 30, SOMA)], ["Scroll of Wizardry"]),
    (14, 76, "Scroll of Health", 48, 171, DIA, [("hp", 200, SOMA)], ["Scroll of Health"]),
    (14, 77, "Scroll of Mana", 49, 172, DIA, [("mana", 300, SOMA)], ["Scroll of Mana"]),
    (14, 97, "Scroll of Battle", 89, 114, DIA, [("critico", 0.2, SOMA)], ["Scroll of Battle"]),
    (14, 98, "Scroll of Strength", 90, 114, DIA, [("excelente", 0.2, SOMA)], ["Scroll of Strengthener"]),
    (14, 78, "Elixir of Strength", 50, 126, 10 * DIA, [("forca", 50, SOMA)], []),
    (14, 79, "Elixir of Agility", 51, 126, 10 * DIA, [("agilidade", 50, SOMA)], []),
    (14, 80, "Elixir of Health", 52, 126, 10 * DIA, [("vitalidade", 50, SOMA)], []),
    (14, 81, "Elixir of Energy", 53, 126, 10 * DIA, [("energia", 50, SOMA)], []),
    (14, 82, "Elixir of Control", 54, 126, 10 * DIA, [("comando", 50, SOMA)], []),
    (13, 124, "Gold Channel Ticket", 180, 180, DIA,
     [("vip", 1, SOMA), ("xp", VIP_XP, SOMA), ("xp_master", VIP_XP, SOMA), ("drop", VIP_DROP, SOMA)], ["Gold Channel Ticket"]),
]


def psql(sql, linhas=True):
    r = subprocess.run(["psql", "-h", SOCK, "-U", "postgres", "-d", "openmu", "-At", "-v", "ON_ERROR_STOP=1", "-c", sql],
                       capture_output=True, text=True)
    if r.returncode:
        sys.exit(r.stderr)
    return [l.split("|") for l in r.stdout.splitlines() if l] if linhas else r.stdout


def q(v):
    return "NULL" if v is None else "'" + str(v).replace("'", "''") + "'"


def ids(g, n):
    item = "00000080-%04x-%04x-0000-000000000023" % (g, n)
    efeito = "00000410-%04x-%04x-0000-000000000023" % (g, n)
    return item, efeito


def produtos(nomes):
    if not nomes:
        return []
    filtro = " or ".join("pk.\"Name\" in (%s, %s) or pk.\"Name\" like %s" % (q(x), q("[" + x + "]"), q(x + "\\_%")) for x in nomes)
    return psql('select p."Id", coalesce(p."ItemDefinitionId"::text, \'\') from config."CashShopProduct" p '
                'join config."CashShopPackage" pk on pk."Id" = p."CashShopPackageId" where ' + filtro)


def gravar():
    antes = {"produtos": {}, "data": time.strftime("%Y%m%d-%H%M")}
    sql = ["begin;"]
    if not psql("select 1 from config.\"AttributeDefinition\" where \"Id\" = %s" % q(A["drop"])):
        sql.append('insert into config."AttributeDefinition" ("Id", "GameConfigurationId", "Designation", "Description") values '
                   "(%s, %s, 'Item Drop Rate', 'The bonus item drop rate which is added to the base drop chance multiplier of 1.0.');"
                   % (q(A["drop"]), q(CONFIG)))
        antes["atributo"] = A["drop"]
    for g, n, nome, buff, sub, seg, efeitos, pacotes in ITENS:
        item, efeito = ids(g, n)
        if psql('select 1 from config."ItemDefinition" where "Group" = %d and "Number" = %d' % (g, n)):
            print("ja existe %d,%d %s: pulo" % (g, n, nome))
            continue
        dur = str(uuid.uuid5(NS, efeito + "dur"))
        sql.append('insert into config."PowerUpDefinitionValue" ("Id", "Value", "AggregateType") values (%s, %d, 0);' % (q(dur), seg))
        sql.append('insert into config."MagicEffectDefinition" ("Id", "DurationId", "GameConfigurationId", "Number", "Name", "SubType", '
                   '"InformObservers", "StopByDeath", "SendDuration", "DurationDependsOnTargetLevel", "MonsterTargetLevelDivisor", '
                   '"PlayerTargetLevelDivisor") values (%s, %s, %s, %d, %s, %d, false, false, true, false, 1, 1);'
                   % (q(efeito), q(dur), q(CONFIG), buff, q(nome), sub))
        for i, (atributo, valor, tipo) in enumerate(efeitos):
            boost = str(uuid.uuid5(NS, "%s boost %d" % (efeito, i)))
            pu = str(uuid.uuid5(NS, "%s pu %d" % (efeito, i)))
            sql.append('insert into config."PowerUpDefinitionValue" ("Id", "Value", "AggregateType") values (%s, %s, %d);'
                       % (q(boost), valor, tipo))
            sql.append('insert into config."PowerUpDefinition" ("Id", "TargetAttributeId", "BoostId", "MagicEffectDefinitionId") '
                       'values (%s, %s, %s, %s);' % (q(pu), q(A[atributo]), q(boost), q(efeito)))
        sql.append('insert into config."ItemDefinition" ("Id", "ConsumeEffectId", "GameConfigurationId", "Number", "Width", "Height", '
                   '"DropsFromMonsters", "IsAmmunition", "IsBoundToCharacter", "Name", "DropLevel", "MaximumItemLevel", "Durability", '
                   '"Group", "Value", "MaximumSockets", "StorageLimitPerCharacter", "IsQuestItem", "IsDroppable", '
                   '"IsPersonalStoreSellable", "IsRepairable", "IsSellableToNpc", "IsStorable", "IsTradable") values '
                   "(%s, %s, %s, %d, 1, 1, false, false, false, %s, 0, %d, 1, %d, 0, 0, 0, false, true, true, false, true, true, true);"
                   % (q(item), q(efeito), q(CONFIG), n, q(nome), 4 if n == 124 else 0, g))
        for pid, velho in produtos(pacotes):
            antes["produtos"][pid] = velho or None
            sql.append('update config."CashShopProduct" set "ItemDefinitionId" = %s where "Id" = %s;' % (q(item), q(pid)))
        antes.setdefault("itens", []).append([g, n])
    # pacotes a venda: so os que tem todos os produtos com item (o OpenMU recusa o resto na compra)
    nomes = [x for it in ITENS for x in it[7]]
    filtro = " or ".join("pk.\"Name\" in (%s, %s) or pk.\"Name\" like %s" % (q(x), q("[" + x + "]"), q(x + "\\_%")) for x in nomes)
    sql_pk = ('select pk."Id" from config."CashShopPackage" pk where not pk."IsForSale" and (' + filtro + ') and not exists '
              '(select 1 from config."CashShopProduct" p where p."CashShopPackageId" = pk."Id" and p."ItemDefinitionId" is null '
              'and p."Id"::text not in (%s))' % (",".join(q(x) for x in antes["produtos"]) or "''"))
    for (pid,) in psql(sql_pk):
        antes.setdefault("pacotes", []).append(pid)
        sql.append('update config."CashShopPackage" set "IsForSale" = true where "Id" = %s;' % q(pid))
    sql.append("commit;")
    os.makedirs(os.path.join(RAIZ, "backup"), exist_ok=True)
    arq = os.path.join(RAIZ, "backup", "selos-antes-%s.json" % antes["data"])
    json.dump(antes, open(arq, "w"), indent=1)
    psql("\n".join(sql), False)
    print("gravado: %d itens, %d produtos da loja ligados, %d pacotes a venda. Volta: --voltar %s"
          % (len(antes.get("itens", [])), len(antes["produtos"]), len(antes.get("pacotes", [])), arq))


def voltar(arq):
    antes = json.load(open(arq))
    sql = ["begin;"]
    for pid in antes.get("pacotes", []):
        sql.append('update config."CashShopPackage" set "IsForSale" = false where "Id" = %s;' % q(pid))
    for pid, velho in antes["produtos"].items():
        sql.append('update config."CashShopProduct" set "ItemDefinitionId" = %s where "Id" = %s;' % (q(velho), q(pid)))
    for g, n in antes.get("itens", []):
        item, efeito = ids(g, n)
        sql.append('delete from data."Item" where "DefinitionId" = %s;' % q(item))
        sql.append('delete from config."ItemDefinition" where "Id" = %s;' % q(item))
        sql.append('delete from config."PowerUpDefinitionValue" where "Id" in (select "BoostId" from config."PowerUpDefinition" '
                   'where "MagicEffectDefinitionId" = %s);' % q(efeito))
        sql.append('delete from config."PowerUpDefinition" where "MagicEffectDefinitionId" = %s;' % q(efeito))
        sql.append('delete from config."PowerUpDefinitionValue" where "Id" = (select "DurationId" from config."MagicEffectDefinition" '
                   'where "Id" = %s);' % q(efeito))
        sql.append('delete from config."MagicEffectDefinition" where "Id" = %s;' % q(efeito))
    if antes.get("atributo"):
        sql.append('delete from config."AttributeDefinition" where "Id" = %s;' % q(antes["atributo"]))
    sql.append("commit;")
    psql("\n".join(sql), False)
    print("voltou:", arq)


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "--voltar":
        voltar(sys.argv[2])
    else:
        gravar()
