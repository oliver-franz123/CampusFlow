#!/usr/bin/env bash
# Recorre toda la simulacion: despliegue bueno, despliegue malo, reversion automatica y reversion manual.
set -u
cd "$(dirname "$0")/.."
export MODO="${MODO:-local}"
rm -rf despliegues
P=8080
mostrar() { echo "\$ curl /salud"; curl -s http://127.0.0.1:$P/salud; echo; }
echo "##### PASO 1: pipeline de validacion"
scripts/ci.sh || exit 1
echo; echo "##### PASO 2: desplegar 1.0.0"
scripts/desplegar.sh 1.0.0; mostrar
echo; echo "##### PASO 3: guardar un aviso para comprobar que el estado persiste"
curl -s -X POST -H 'Content-Type: application/json' -d '{"texto":"Examen de redes el lunes"}' http://127.0.0.1:$P/avisos; echo
echo; echo "##### PASO 4: desplegar 2.0.0 con la configuracion rota a proposito"
ROMPER=1 scripts/desplegar.sh 2.0.0; mostrar
echo; echo "##### PASO 5: los avisos siguen ahi despues del fallo"
curl -s http://127.0.0.1:$P/avisos; echo
echo; echo "##### PASO 6: desplegar 2.0.0 corregida"
scripts/desplegar.sh 2.0.0; mostrar
echo; echo "##### PASO 7: reversion manual a la anterior"
scripts/revertir.sh; mostrar
echo; echo "##### PASO 8: avisos al final"
curl -s http://127.0.0.1:$P/avisos; echo
echo; echo "##### Registro del servicio"
cat despliegues/avisos.log
kill "$(cat despliegues/pid)" 2>/dev/null
