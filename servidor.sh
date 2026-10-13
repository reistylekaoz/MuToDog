#!/bin/bash
# OpenMU do estudo: ./servidor.sh ligar | desligar | status
# Postgres so por socket (sem porta), banco openmu em pg/. Log em openmu.log.
cd "$(dirname "$0")"
P=$HOME/.local/opt/pgsql17/usr/pgsql-17
export LD_LIBRARY_PATH=$P/lib PATH=$HOME/.dotnet:$PATH DOTNET_ROOT=$HOME/.dotnet
export DB_HOST=$PWD/sock DB_ADMIN_USER=postgres DB_ADMIN_PW=local
# ligar-teste: o OpenMU escuta em sockmu/<porta> (socket Unix) em vez de TCP, pros testes do cliente
[ "$1" = ligar-teste ] && { export OPENMU_SOCKET_DIR=$PWD/sockmu; mkdir -p sockmu; set -- ligar; }
case "$1" in
  ligar)
    $P/bin/pg_ctl -D pg status >/dev/null || $P/bin/pg_ctl -D pg -l pg.log start >/dev/null
    pgrep -u "$USER" -f "dotnet [M]Unique.OpenMU.Startup.dll" >/dev/null && { echo "ja esta ligado"; exit 0; }
    (cd openmu/src/Startup/bin/Release && OPENMU_SOCKET_DIR=${OPENMU_SOCKET_DIR:-} nohup dotnet MUnique.OpenMU.Startup.dll -autostart -adminpanel:disabled -resolveIP:loopback > ../../../../../openmu.log 2>&1 &)
    echo "ligando, veja openmu.log" ;;
  desligar)
    pkill -u "$USER" -f "dotnet [M]Unique.OpenMU.Startup.dll"
    for i in $(seq 30); do pgrep -u "$USER" -f "dotnet [M]Unique.OpenMU.Startup.dll" >/dev/null || break; sleep 1; done
    pkill -9 -u "$USER" -f "dotnet [M]Unique.OpenMU.Startup.dll"
    $P/bin/pg_ctl -D pg stop >/dev/null; echo "desligado" ;;
  *)
    pgrep -u "$USER" -f "dotnet [M]Unique.OpenMU.Startup.dll" >/dev/null && echo "OpenMU ligado" || echo "OpenMU desligado"
    $P/bin/pg_ctl -D pg status | head -1 ;;
esac
