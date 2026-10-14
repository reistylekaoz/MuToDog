# Cores do brilho dos itens +7 em diante, tiradas do MuMain (ref/Items/Models/Group*.json,
# campo "glow", e ref/GlowColors.json): grava godot/dados/brilho/cores.json com
# "grupo,numero" -> [cor do cromo, cor do brilho de +11, nivel fixo ou -1].
# Sem "glow" o item usa o padrao do cliente: cromo laranja, brilho branco.
import glob, json, os

raiz = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
cores = json.load(open(os.path.join(raiz, 'ref/GlowColors.json')))['colors']
saida = {}
for f in sorted(glob.glob(os.path.join(raiz, 'ref/Items/Models/Group*.json'))):
    j = json.load(open(f))
    for m in j['models']:
        g = m.get('glow') or {}
        brilho = [1, 1, 1] if g.get('shineWhite') else cores[g.get('shineColor', 'white')]
        saida['%d,%d' % (j['group'], m['number'])] = [cores[g.get('color', 'orange')], brilho, g.get('level', -1)]
destino = os.path.join(raiz, 'godot/dados/brilho/cores.json')
json.dump(saida, open(destino, 'w'), separators=(',', ':'))
print(len(saida), 'itens em', destino)
