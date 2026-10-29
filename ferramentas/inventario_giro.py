# Rotacao de cada item no inventario (o "inventory.rotation" dos JSON do MuMain, padrao 270,-10,0) e os
# itens que giram sozinhos (renderStyle gambleItem): godot/dados/modelos/inventario.json, lido pela Vitrine3D.
# Uso: python3 ferramentas/inventario_giro.py
import glob, json, os
raiz = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rot, giram = {}, []
for f in sorted(glob.glob(os.path.join(raiz, 'ref/Items/Models/Group*.json'))):
    j = json.load(open(f))
    for m in j['models']:
        k = '%d,%d' % (j['group'], m['number'])
        r = m.get('inventory', {}).get('rotation')
        if r and list(r) != [270, -10, 0]:
            rot[k] = r
        if m.get('renderStyle') == 'gambleItem':
            giram.append(k)
saida = os.path.join(raiz, 'godot/dados/modelos/inventario.json')
json.dump({'rot': rot, 'giram': giram}, open(saida, 'w'), separators=(',', ':'))
print('%d rotacoes, %d giram -> %s' % (len(rot), len(giram), saida))
