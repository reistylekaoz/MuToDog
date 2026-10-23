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
json.dump(buffs, open(os.path.join(SAIDA, "buffs.json"), "w"), ensure_ascii=False, indent=0)
subprocess.run([sys.executable, os.path.join(AQUI, "ferramentas", "interface.py"), os.path.join(DATA, "Interface"),
                os.path.join(SAIDA, "hud"), "newui_statusicon=buff1", "newui_statusicon2=buff2"], check=True)
print(len(buffs), "buffs")
