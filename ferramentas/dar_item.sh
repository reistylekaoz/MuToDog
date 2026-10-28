#!/bin/bash
# Poe item direto no inventario de um personagem do OpenMU daqui, quando a conta estiver fora do jogo
# (com ela dentro, o servidor guarda o inventario em memoria e regrava por cima ao sair).
# Tenta entrar na conta a cada 20 s (o cliente headless: "conta ja conectada" = ainda jogando); quando entra,
# sai na hora e grava os itens 1x1 ou maiores nos primeiros espacos livres da mochila (8 x 8, slots 12 a 75).
# Uso: ferramentas/dar_item.sh <conta> <senha> <personagem> <grupo> <numero> <nivel> <quantidade> [minutos, padrao 120]
# Ex.: ferramentas/dar_item.sh test0 test0 test0Dl 14 11 8 10     (10 Box of Kundun +1: 14,11 nivel 8 a 12 = +1 a +5)
set -e
cd "$(dirname "$0")/.."
CONTA=$1 SENHA=$2 PERS=$3 GR=$4 NU=$5 NV=$6 QT=$7 MIN=${8:-120}
P=$HOME/.local/opt/pgsql17/usr/pgsql-17
G=$HOME/casa/trabalho/.ferramentas/godot/Godot_v4.7.2-stable_linux.x86_64
q() { LD_LIBRARY_PATH=$P/lib $P/bin/psql -h $PWD/sock -U postgres -d openmu -Atc "$1"; }
fim=$(( $(date +%s) + MIN * 60 ))
while :; do
  r=$(cd godot && MU_PONTE=$PWD/testes/ponte_unix.py MU_SOCKETS=$PWD/../sockmu timeout 40 $G --headless --path . -- \
      --auto "$CONTA,$SENHA,_ninguem_" --sair 5 2>&1 | grep -oE "REDE (personagens|erro_login.*)" | head -1)
  echo "$(date +%H:%M:%S) $r"
  [ "$r" = "REDE personagens" ] && break
  [ "$(date +%s)" -ge "$fim" ] && { echo "desisti: a conta ficou conectada $MIN min"; exit 1; }
  sleep 20
done
sleep 3   # o servidor salva a conta ao desconectar
q "select i.\"ItemSlot\", d.\"Width\", d.\"Height\" from data.\"Item\" i join config.\"ItemDefinition\" d on d.\"Id\"=i.\"DefinitionId\"
   join data.\"Character\" c on c.\"InventoryId\"=i.\"ItemStorageId\" where c.\"Name\"='$PERS' and i.\"ItemSlot\" between 12 and 75" > /tmp/dar_item_$$.txt
DEF=$(q "select \"Id\"||'|'||\"Width\"||'|'||\"Height\"||'|'||\"Durability\" from config.\"ItemDefinition\" where \"Group\"=$GR and \"Number\"=$NU")
SLOTS=$(python3 - "$DEF" "$QT" /tmp/dar_item_$$.txt <<'PY'
import sys
_, w, h, _d = sys.argv[1].split('|'); w, h, qt = int(w), int(h), int(sys.argv[2])
ocup = set()
for l in open(sys.argv[3]):
    s, iw, ih = map(int, l.strip().split('|'))
    x, y = (s - 12) % 8, (s - 12) // 8
    ocup |= {(x + a, y + b) for a in range(iw) for b in range(ih)}
r = []
for y in range(8):
    for x in range(8):
        cel = {(x + a, y + b) for a in range(w) for b in range(h)}
        if x + w <= 8 and y + h <= 8 and not cel & ocup and len(r) < qt:
            r.append(12 + y * 8 + x); ocup |= cel
print(' '.join(map(str, r)))
PY
)
rm -f /tmp/dar_item_$$.txt
[ -z "$SLOTS" ] && { echo "mochila sem espaco"; exit 1; }
ID=${DEF%%|*}; DUR=${DEF##*|}
for s in $SLOTS; do
  q "insert into data.\"Item\" (\"Id\",\"ItemStorageId\",\"DefinitionId\",\"ItemSlot\",\"Durability\",\"Level\",\"HasSkill\",\"SocketCount\",\"StorePrice\",\"PetExperience\")
     select gen_random_uuid(), \"InventoryId\", '$ID', $s, $DUR, $NV, false, 0, 0, 0 from data.\"Character\" where \"Name\"='$PERS'" >/dev/null
done
echo "gravado: $(echo $SLOTS | wc -w) de $QT nos slots $SLOTS"
