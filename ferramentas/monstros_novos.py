#!/usr/bin/env python3
# Monstros do servidor que o cliente Godot ainda nao desenha: le o CreateMonster do MuMain
# (ZzzCharacter.cpp e GM*.cpp) pra cada numero, com modelo, escala e armas na mao
# (c->Weapon[0/1].Type, osso do LinkBone por modelo), e grava:
#   ref/monstros_novos.json  numero -> {modelo, glb, escala, armas, corpo do case}
# e imprime as entradas novas do conversor/personagens.json (com --gravar, junta la).
# Uso: python3 ferramentas/monstros_novos.py <numeros...> [--gravar]
import json, os, re, sys
AQUI = os.path.dirname(os.path.abspath(__file__))
R = os.path.join(AQUI, '..', 'ref', 'mumain')
CONV = os.path.join(AQUI, '..', 'conversor', 'personagens.json')
MODELOS = os.path.join(AQUI, '..', 'godot', 'dados', 'modelos', 'modelos.json')

enum = {}
for h in ['Core/Globals/_enum.h', 'Core/Globals/_define.h']:
    txt = open(os.path.join(R, h), encoding='utf-8', errors='ignore').read()
    for nome, expr in re.findall(r'^\s*(?:constexpr int\s+)?([A-Z][A-Z0-9_]+)\s*=\s*([^,;\n/]+)', txt, re.M):
        enum.setdefault(nome, expr.strip())
    for nome, expr in re.findall(r'^#define\s+([A-Z][A-Z0-9_]+)\s+([^\n/]+)', txt, re.M):
        enum.setdefault(nome, expr.strip())


# valor simbolico: (raiz, deslocamento). O enum do MuMain conta sozinho (sem "="), entao a
# conta para no nome sem valor (MODEL_ITEM, MODEL_SKILL_END...) e soma o resto
def sym(e, d=0):
    toks = re.findall(r'[A-Za-z_]\w*|0x[0-9a-fA-F]+|\d+|[-+*()]', e)
    pos = [0]

    def prox():
        return toks[pos[0]] if pos[0] < len(toks) else None

    def soma():
        r = mult()
        while prox() in ('+', '-'):
            op = toks[pos[0]]; pos[0] += 1
            b = mult()
            if r is None or b is None or (r[0] and b[0]):
                return None
            r = (r[0] or b[0], r[1] + b[1] if op == '+' else r[1] - b[1])
        return r

    def mult():
        r = atomo()
        while prox() == '*':
            pos[0] += 1
            b = atomo()
            if r is None or b is None or r[0] or b[0]:
                return None
            r = (None, r[1] * b[1])
        return r

    def atomo():
        t = prox()
        if t is None:
            return None
        pos[0] += 1
        if t == '(':
            r = soma()
            pos[0] += 1
            return r
        if t == '-':
            a = atomo()
            return None if a is None or a[0] else (None, -a[1])
        if re.fullmatch(r'\d+', t):
            return (None, int(t))
        if t.startswith('0x'):
            return (None, int(t, 16))
        if t in enum and d < 40:
            return sym(enum[t], d + 1)
        return (t, 0)
    try:
        return soma()
    except Exception:
        return None


def val(e):
    r = sym(e)
    return r if r is None else (r[1] if r[0] is None else r)


fontes = {}
for raiz, _, fs in os.walk(R):
    for f in fs:
        if f.endswith('.cpp'):
            fontes[os.path.join(raiz, f)] = open(os.path.join(raiz, f), encoding='utf-8', errors='ignore').read()

# MODEL_X -> arquivo BMD (AccessModel com nome fixo; MONSTER01 + n -> Monster/Monster{n+1})
acesso = {}
for src in fontes.values():
    for mod, d, nome, i in re.findall(r'AccessModel\(\s*(MODEL_\w+(?:\s*\+\s*\d+)?)\s*,\s*L"Data\\\\([\w]+)\\\\"\s*,\s*L"([^"]+)"\s*(?:,\s*(\d+))?', src):
        v = sym(mod)
        if v is not None:
            acesso.setdefault(v, f'{d}/{nome}{"" if not i else str(int(i)).zfill(2)}.bmd')
M1 = sym('MODEL_MONSTER01')


def arquivo(mod):
    v = sym(mod)
    if v is None:
        return None
    if v in acesso:
        return acesso[v]
    if v[0] == M1[0] and 0 <= v[1] - M1[1] < 300:
        return f'Monster/Monster{v[1] - M1[1] + 1:02d}.bmd'
    return None


# osso das armas por modelo: case MODEL_X: c->Weapon[0].LinkBone = a; c->Weapon[1].LinkBone = b
ossos = {}
for src in fontes.values():
    for bloco in re.findall(r'((?:case\s+MODEL_\w+(?:\s*\+\s*\d+)?\s*:\s*)+)([^}]*?)break;', src):
        rots, corpo = bloco
        w0 = re.search(r'Weapon\[0\]\.LinkBone\s*=\s*(\d+)', corpo)
        w1 = re.search(r'Weapon\[1\]\.LinkBone\s*=\s*(\d+)', corpo)
        if not (w0 or w1):
            continue
        for rot in re.findall(r'case\s+(MODEL_\w+(?:\s*\+\s*\d+)?)', rots):
            v = sym(rot)
            if v is not None:
                ossos.setdefault(v, (int(w0[1]) if w0 else 33, int(w1[1]) if w1 else 42))

# item do jogo pela constante do modelo (MODEL_ITEM + grupo * 512 + indice) -> arquivo do item
modelos = json.load(open(MODELOS)) if os.path.exists(MODELOS) else {}
MI = sym('MODEL_ITEM')


def item(mod):
    v = sym(mod)
    if v is None or v[0] != MI[0] or v[1] < MI[1]:
        return None
    k = f'{(v[1] - MI[1]) // 512},{(v[1] - MI[1]) % 512}'
    return ('Item/' + modelos[k][0] + '.bmd', k) if k in modelos else None


# corpo de cada case do CreateMonster (rotulos empilhados caem no mesmo corpo)
casos = {}
for f, src in fontes.items():
    if 'CreateCharacter(' not in src:
        continue
    pend = []
    for bloco in re.split(r'\n\s*case\s+', src)[1:]:
        rot, _, corpo = bloco.partition(':')
        n = val(rot.strip())
        if isinstance(n, int) and rot.strip().startswith('MONSTER_'):
            pend.append(n)
        if not corpo.strip(' \t\r\n{'):
            continue
        ate = re.split(r'\n\s*(?:break;|default\s*:)', corpo)[0]
        cc = re.search(r'CreateCharacter\(\s*Key\s*,\s*([^,]+),', ate)
        if cc:
            for k in pend:
                casos.setdefault(k, (os.path.basename(f), cc[1].strip(), ate))
        pend = []


def nome_glb(arq, armas):
    d, b = arq[:-4].split('/')
    base = b.lower() if d.lower() == 'monster' else f'{d.lower()}_{b.lower()}'
    for a in armas:
        base += '_' + a['bmd'].split('/')[1][:-4].lower()
    return base


ACOES_MONSTRO = {"parado": 0, "parado2": 1, "anda": 2, "ataque": 3, "ataque2": 4, "golpe": 5, "morre": 6}
ACOES_NPC = {"parado": 0, "parado2": 1, "anda": 2}

if __name__ == '__main__':
    nums = [int(a) for a in sys.argv[1:] if a.isdigit()]
    conv = json.load(open(CONV))
    out, novos, sem = {}, {}, []
    # o mesmo modelo com as mesmas armas ja convertido (e com acoes de monstro): usa o que tem
    ja = {}
    for k, e in conv.items():
        if 'anda' in e.get('acoes', {}):
            ja.setdefault((e['esqueleto'].lower(), tuple(a['bmd'].lower() for a in e.get('armas', []))), k)
    for n in nums:
        if n not in casos:
            sem.append(n)
            continue
        f, mod, corpo = casos[n]
        arq = arquivo(mod)
        if arq is None:
            sem.append(n)
            continue
        esc = re.search(r'Object\.Scale\s*=\s*([\d.]+)f?', corpo)
        armas = []
        osso = ossos.get(sym(mod), (33, 42))
        for i, w in re.findall(r'Weapon\[([01])\]\.Type\s*=\s*([^;]+);', corpo):
            it = item(w)
            if it and w.strip() != '-1':
                armas.append({'bmd': it[0], 'osso': osso[int(i)], 'esquerda': i == '1', 'item': it[1]})
        g = ja.get((arq.lower(), tuple(a['bmd'].lower() for a in armas))) or nome_glb(arq, armas)
        out[n] = {'modelo': mod, 'arquivo': arq, 'glb': g, 'escala': float(esc[1]) if esc else 1.0,
                  'armas': armas, 'em': f, 'corpo': corpo.strip()[:1500]}
        if g not in conv and g not in novos:
            e = {'esqueleto': arq, 'acoes': ACOES_MONSTRO if arq.lower().startswith('monster/') else ACOES_NPC}
            if armas:
                e['armas'] = [{'bmd': a['bmd'], 'osso': a['osso'], 'esquerda': a['esquerda']} for a in armas]
            novos[g] = e
    json.dump(out, open(os.path.join(R, '..', 'monstros_novos.json'), 'w'), indent=1, ensure_ascii=False)
    for n, o in out.items():
        print(n, o['glb'], o['escala'], [a['item'] for a in o['armas']], o['em'])
    print('sem caso no cliente:', sem)
    print('glb novos:', len(novos), sorted(novos))
    if '--gravar' in sys.argv:
        conv.update(novos)
        json.dump(conv, open(CONV, 'w'), indent=1, ensure_ascii=False)
        print('gravado em', CONV)
