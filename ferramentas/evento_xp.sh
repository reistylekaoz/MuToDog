#!/bin/bash
# Evento de XP sem religar o OpenMU (patch ferramentas/openmu-evento-xp.patch):
#   ferramentas/evento_xp.sh 100 2     -> 100x por 2 horas a partir de agora
#   ferramentas/evento_xp.sh parar     -> volta pro normal na hora
#   ferramentas/evento_xp.sh           -> mostra o que vale agora
# O servidor relê openmu/src/Startup/bin/Release/taxa_xp.json a cada 5 s e
# volta sozinho pro 1x quando passa do "ate".
F="$(dirname "$0")/../openmu/src/Startup/bin/Release/taxa_xp.json"
case "$1" in
  parar) rm -f "$F"; echo "evento parado (1x)" ;;
  "") [ -f "$F" ] && cat "$F" || echo "sem evento (1x)" ;;
  *) ATE=$(date -d "+${2:-2} hours" +%Y-%m-%dT%H:%M:%S%:z)
     printf '{"taxa": %s, "ate": "%s"}\n' "$1" "$ATE" > "$F"; cat "$F" ;;
esac
