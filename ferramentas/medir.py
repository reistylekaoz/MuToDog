#!/usr/bin/env python3
# Quanto do cliente S6 ja existe: pacotes que o OpenMU manda (ServerToClientPackets.xml, sem as
# variantes de versao antiga) contra os que godot/scripts/rede/cliente.gd trata, e cenarios do
# cliente (Data/World<N> com terreno) contra godot/dados/mundo<N>. Conta aproximada: um codigo
# tratado no "match cod" conta todos os subcodigos dele.
# Uso: python3 ferramentas/medir.py [-v]   (-v lista o que falta)
import os, re, sys
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
xml = open(f'{R}/openmu/src/Network/Packets/ServerToClient/ServerToClientPackets.xml').read()
src = open(f'{R}/godot/scripts/rede/cliente.gd').read()
pares = {(a.upper(), b.upper()) for a, b in re.findall(r'\[0x([0-9A-Fa-f]{2}),\s*0x([0-9A-Fa-f]{2})\]', src)}
linhas = src.split('\n')
i = next(k for k, l in enumerate(linhas) if l.strip() == 'match cod:')
um = {m.group(1).upper() for l in linhas[i:] for m in [re.match(r'^\t\t0x([0-9A-Fa-f]{2}):', l)] if m}
um.discard('BF')   # do BF so o 51 (helper) e tratado; ele ja esta nos pares abaixo
pares.add(('BF', '51'))
velho = re.compile(r'(075|095|097|Extended|Legacy)$')
tot, falta = 0, []
for b in re.findall(r'<Packet>(.*?)</Packet>', xml, re.S):
    g = lambda t: (re.search(f'<{t}>(.*?)</{t}>', b, re.S) or [None, None])[1]
    n, c, sc = g('Name'), g('Code'), g('SubCode')
    if velho.search(n):
        continue
    tot += 1
    if not ((c, sc) in pares or c in um):
        falta.append(n)
print(f'pacotes do servidor: {tot - len(falta)} de {tot} tratados ({100 * (tot - len(falta)) // tot}%)')
D = f'{R}/s6/cliente/MU Client 1.04d - Season 6E3/Data'
cli = sorted(int(w[5:]) for w in os.listdir(D) if w.startswith('World') and any(a.endswith(('.map', '.att', '.obj')) for a in os.listdir(f'{D}/{w}')))
meus = [n for n in cli if os.path.exists(f'{R}/godot/dados/mundo{n}/altura.png')]
print(f'cenarios do cliente: {len(meus)} de {len(cli)} (faltam World {", ".join(str(n) for n in cli if n not in meus)})')
if '-v' in sys.argv:
    print('\n'.join(sorted(falta)))
