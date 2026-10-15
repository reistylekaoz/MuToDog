#!/usr/bin/env python3
# Le o CreateMonster do cliente (MuMain: ZzzCharacter.cpp e os GM*.cpp de cada mapa) e grava,
# pra cada numero de monstro do servidor: modelo (MODEL_...), arquivo BMD provavel e escala.
# Uso: python3 ferramentas/monstros_cliente.py [numeros...]  -> ref/monstros_cliente.json
import json, os, re, sys
R = os.path.join(os.path.dirname(__file__), '..', 'ref', 'mumain')
enum = {}
txt = open(os.path.join(R, 'Core/Globals/_enum.h'), encoding='utf-8', errors='ignore').read()
for nome, expr in re.findall(r'^\s*([A-Z][A-Z0-9_]+)\s*=\s*([^,\n/]+)', txt, re.M):
    enum[nome] = expr.strip()
def val(e, d=0):
    e = e.strip()
    if d > 20: return None
    if re.fullmatch(r'-?\d+', e): return int(e)
    if re.fullmatch(r'0x[0-9a-fA-F]+', e): return int(e, 16)
    m = re.fullmatch(r'([A-Z][A-Z0-9_]*)\s*([+-])\s*(\d+)', e)
    if m:
        b = val(enum.get(m[1], m[1]), d + 1)
        return None if b is None else b + (int(m[3]) if m[2] == '+' else -int(m[3]))
    if e in enum: return val(enum[e], d + 1)
    return None
# MODEL_xxx -> (base, indice) pro nome do arquivo
def modelo(e):
    e = e.strip()
    m = re.fullmatch(r'MODEL_MONSTER01\s*\+\s*(\d+)', e)
    if m: return ('Monster', int(m[1]) + 1)
    if e in enum: return modelo(enum[e])
    if re.sub(r'\s+', '', e) in acesso: return ('arq', acesso[re.sub(r'\s+', '', e)])
    return ('?', e)
# MODEL_X -> arquivo, pelo AccessModel(MODEL_X, L"Data\\Npc\\", L"Storage", 1) -> Npc/Storage01.bmd
acesso = {}
for raiz, _, fs in os.walk(R):
    for f in fs:
        if f.endswith('.cpp'):
            for mod, d, nome, i in re.findall(r'AccessModel\(\s*(MODEL_\w+(?:\s*\+\s*\d+)?)\s*,\s*L"Data\\\\([\w]+)\\\\"\s*,\s*L"([^"]+)"\s*(?:,\s*(\d+))?', open(os.path.join(raiz, f), encoding='utf-8', errors='ignore').read()):
                acesso.setdefault(re.sub(r'\s+', '', mod), f'{d}/{nome}{"" if not i else str(int(i)).zfill(2)}.bmd')
casos = {}
for raiz, _, fs in os.walk(R):
    for f in fs:
        if not f.endswith('.cpp'): continue
        src = open(os.path.join(raiz, f), encoding='utf-8', errors='ignore').read()
        # tabela {MONSTER_X, MONSTER_MODEL_X, MODEL_X, escala, ...} (GM_PK_Field)
        for mon, mod, esc in re.findall(r'\{\s*(MONSTER_\w+)\s*,\s*[\w:]+\s*,\s*(MODEL_\w+(?:\s*\+\s*\d+)?)\s*,\s*([\d.]+)f', src):
            n = val(mon)
            if n is not None:
                casos.setdefault(n, {'modelo': mod, 'arquivo': modelo(mod), 'escala': float(esc), 'em': f})
        # case A: case B: ... corpo com CreateCharacter (rotulos empilhados caem no mesmo corpo)
        pend = []
        for bloco in re.split(r'\n\s*case\s+', src)[1:]:
            rot, _, corpo = bloco.partition(':')
            n = val(rot.strip())
            if n is not None:
                pend.append(n)
            if not corpo.strip(' \t\r\n{'):
                continue
            ate = re.split(r'\n\s*(?:break;|default\s*:)', corpo)[0]
            cc = re.search(r'CreateCharacter\(\s*Key\s*,\s*([^,]+),', ate)
            if cc:
                esc = re.search(r'Scale\s*=\s*([\d.]+)f?', ate)
                for k in pend:
                    casos.setdefault(k, {'modelo': cc[1].strip(), 'arquivo': modelo(cc[1]), 'escala': float(esc[1]) if esc else 1.0, 'em': f})
            pend = []
alvo = [int(a) for a in sys.argv[1:]] or sorted(casos)
out = {n: casos.get(n) for n in alvo}
json.dump(out, open(os.path.join(R, '..', 'monstros_cliente.json'), 'w'), indent=1)
for n in alvo: print(n, out[n])
