#!/bin/bash
# Pacotes do PC pro launcher (mu-online/launcher): exporta o Windows (testes/exportar_windows.sh)
# em build/pc_novo, troca openmu.pck por jogo.pck e poe em build/web/pc/ (o site serve em /jogo/pc/,
# so com sessao do console ou a chave do launcher) com o versao.json gravado por ultimo.
# Rode depois de cada export que foi pro ar: o launcher baixa so o que mudou na proxima abertura.
# Uso: bash testes/publicar_pc.sh
set -e
cd "$(dirname "$0")/.."
N=build/pc_novo
P=build/web/pc
bash testes/exportar_windows.sh $N >/dev/null
mv $N/openmu.pck $N/jogo.pck
rm -f $N/openmu.exe
mkdir -p $P/mapas
python3 - $N $P "$(git -C .. log -1 --format=%h)" <<'PY'
import hashlib, json, os, shutil, sys, time
n, p, commit = sys.argv[1:]
arqs = []
for nome in ['jogo.pck'] + sorted('mapas/' + a for a in os.listdir(f'{n}/mapas')):
    h = hashlib.sha256(open(f'{n}/{nome}', 'rb').read()).hexdigest()
    arqs.append({'nome': nome, 'tam': os.path.getsize(f'{n}/{nome}'), 'sha256': h})
    if not os.path.exists(f'{p}/{nome}') or hashlib.sha256(open(f'{p}/{nome}', 'rb').read()).hexdigest() != h:
        shutil.copyfile(f'{n}/{nome}', f'{p}/{nome}.tmp')
        os.replace(f'{p}/{nome}.tmp', f'{p}/{nome}')
        print('novo', nome)
versao = time.strftime('%d/%m %H:%M') + ' ' + commit
json.dump({'versao': versao, 'launcher': 1, 'arquivos': arqs}, open(f'{p}/versao.json.tmp', 'w'), indent=1)
os.replace(f'{p}/versao.json.tmp', f'{p}/versao.json')
# o que saiu do ar sai da pasta (depois do versao.json, quem esta baixando ainda acha)
nomes = {a['nome'] for a in arqs}
for a in os.listdir(f'{p}/mapas'):
    if 'mapas/' + a not in nomes:
        os.remove(f'{p}/mapas/{a}')
print('versao', versao, '·', len(arqs), 'arquivos ·', round(sum(a['tam'] for a in arqs) / 1048576), 'MB')
PY
