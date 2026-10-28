"""Buffs do cliente S6 pra janela de buffs: godot/dados/buffs.json e os icones em godot/dados/hud/buff1.png e buff2.png.
BuffEffect_eng.bmd: u32 quantidade, registros de 158 bytes com a cifra BuxConvert (^ FC CF AB) cada um, u32 de conferencia.
Registro: id u16, tipo u8, grupo u8, numero u8 (item que da o buff, 255 = nenhum), nome[50], classe u8 (0 buff, 1 debuff),
aviso u8, limpa u8, descricao[100] ('/' quebra a linha).
Icone (CNewUIBuffWindow::RenderBuffIcon): id < 81 em newui_statusicon, coluna (id-1)%10, linha (id-1)/10; id >= 81 em
newui_statusicon2 a partir de id-81; celula de 20x28.
Uso: python3 ferramentas/dados_buff.py"""
import json, os, struct, subprocess, sys

AQUI = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(AQUI, "s6", "cliente", "MU Client 1.04d - Season 6E3", "Data")
SAIDA = os.path.join(AQUI, "godot", "dados")
CHAVE = (0xFC, 0xCF, 0xAB)

d = open(os.path.join(DATA, "Local", "Eng", "BuffEffect_eng.bmd"), "rb").read()
n = struct.unpack_from("<I", d)[0]
buffs = {}
for i in range(n):
    r = bytes(x ^ CHAVE[j % 3] for j, x in enumerate(d[4 + i * 158:4 + (i + 1) * 158]))
    bid, tipo, grupo, numero = struct.unpack_from("<HBBB", r)
    buffs[bid] = {"nome": r[5:55].split(b"\0")[0].decode("latin1"), "debuff": r[55] == 1,
                  "descricao": r[58:158].split(b"\0")[0].decode("latin1").replace("%%", "%"),
                  "item": [grupo, numero] if grupo != 255 else None, "tipo": tipo}
# Textos mais claros pro jogador: o original mistura taxa final ("EXP 150%") com bonus ("+30"); aqui tudo e o que soma,
# com os valores do IGCN (IGCN.md). Mudou o valor no servidor (rodada 23)? Mude aqui junto.
TEXTOS = {
    29: "EXP +50%", 40: "EXP +50%",
    30: "EXP +100%/Item drop +50%", 41: "EXP +100%/Item drop +50%",
    31: "No EXP gain while active", 42: "No EXP gain while active",
    43: "Free warp from the M menu",
    44: "Attack speed +15", 45: "Defense +60", 46: "Attack power +30", 47: "Wizardry +30",
    48: "Max HP +200", 49: "Max mana +300",
    50: "Strength +50", 51: "Agility +50", 52: "Vitality +50", 53: "Energy +50", 54: "Command +50",
    87: "EXP +50%/Recovers 5% HP automatically", 88: "Item drop +50%/Recovers 5% mana automatically",
    89: "Critical damage +20%", 90: "Excellent damage +20%",
    99: "No EXP or item loss when you die", 100: "Items do not lose durability",
    101: "Master EXP +50%", 102: "Master EXP +100%/Item drop +50%",
    104: "Damage +50/Defense +60", 112: "Party EXP bonus/More members, more EXP",
    119: "Item drop +50%", 121: "Recovers 3% HP automatically/Max HP +100",
}
for bid, t in TEXTOS.items():
    buffs[bid]["descricao"] = t
# VIP do Gold Channel Ticket (13,124): o cliente S6 nao tem buff de VIP; o 180 vem do servidor daqui
# (ferramentas/selos_openmu.py, VIP_XP e VIP_DROP) e usa o icone do Seal of Wealth com "VIP" por cima (janela_buffs.gd).
buffs[180] = {"nome": "VIP (Gold Channel)", "debuff": False, "descricao": "EXP +50%/Master EXP +50%/Item drop +20%",
              "item": [13, 124], "tipo": 180}
json.dump(buffs, open(os.path.join(SAIDA, "buffs.json"), "w"), ensure_ascii=False, indent=0)
subprocess.run([sys.executable, os.path.join(AQUI, "ferramentas", "interface.py"), os.path.join(DATA, "Interface"),
                os.path.join(SAIDA, "hud"), "newui_statusicon=buff1", "newui_statusicon2=buff2"], check=True)
print(len(buffs), "buffs")
