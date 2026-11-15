#!/usr/bin/env bash
# Vuelve a la version anterior guardada en despliegues/previa. Solo cambia de version, no reconstruye.
set -u
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
DESP="$RAIZ/despliegues"
[ -f "$DESP/previa" ] || { echo "No hay version previa registrada"; exit 1; }
destino="$(cat "$DESP/previa")"
actual="$(cat "$DESP/actual")"
echo "Revirtiendo manualmente de $actual a $destino"
"$RAIZ/scripts/desplegar.sh" "$destino" && echo "$actual" > "$DESP/previa"
