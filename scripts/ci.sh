#!/usr/bin/env bash
# La misma secuencia que corre la canalizacion en GitHub. Se puede correr en cualquier maquina.
set -eu
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"; cd "$RAIZ"
echo "== 1. Pruebas automaticas =="
python3 -m unittest discover -s tests -v
echo "== 2. Revision de que exista la guia de variables =="
grep -q APP_PORT .env.example && echo ".env.example documenta las variables"
if [ "${MODO:-local}" = "docker" ]; then
  echo "== 3. Construccion de imagen =="
  docker build -t "campusflow-avisos:${APP_VERSION:-ci}" .
fi
echo "CI OK"
