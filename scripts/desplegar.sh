#!/usr/bin/env bash
# Uso: scripts/desplegar.sh VERSION
# MODO=docker usa Docker de verdad. MODO=local simula el contenedor con carpetas y procesos.
# Variable ROMPER=1 borra una variable de configuracion a proposito para simular un fallo.
set -u
VERSION="${1:?Falta la version, por ejemplo 1.0.0}"
MODO="${MODO:-local}"
PUERTO="${APP_PORT:-8080}"
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
DESP="$RAIZ/despliegues"
mkdir -p "$DESP/versiones" "$DESP/datos"

esperar_salud() {   # espera hasta 15 segundos a que /salud responda con la version pedida
  for i in $(seq 1 15); do
    r=$(curl -s --max-time 2 "http://127.0.0.1:$PUERTO/salud" || true)
    if echo "$r" | grep -q "\"version\": \"$1\""; then return 0; fi
    sleep 1
  done
  return 1
}

parar() {
  if [ "$MODO" = "docker" ]; then docker rm -f avisos >/dev/null 2>&1 || true
  elif [ -f "$DESP/pid" ]; then kill "$(cat "$DESP/pid")" 2>/dev/null || true; rm -f "$DESP/pid"; sleep 1; fi
}

arrancar() {   # arrancar VERSION
  local v="$1"
  local archivo="$DESP/datos/avisos.json"
  [ "$MODO" = "docker" ] && archivo="/data/avisos.json"
  local -a entorno=(APP_PORT="$PUERTO" APP_VERSION="$v" APP_ENTORNO="${APP_ENTORNO:-local}")
  if [ "${ROMPER:-0}" != "1" ] || [ "$v" != "${VERSION_ROTA:-$VERSION}" ]; then
    entorno+=(ARCHIVO_AVISOS="$archivo")
  fi
  if [ "$MODO" = "docker" ]; then
    local -a e=(); for kv in "${entorno[@]}"; do e+=(-e "$kv"); done
    docker run -d --name avisos -p "$PUERTO:$PUERTO" -v avisos-datos:/data "${e[@]}" "campusflow-avisos:$v" >/dev/null
  else
    # exec hace que el pid guardado sea el de python y no el de una subshell
    ( cd "$DESP/versiones/$v" && exec env "${entorno[@]}" python3 -m app.servicio >>"$DESP/avisos.log" 2>&1 ) &
    echo $! > "$DESP/pid"
  fi
}

# 1. construir la version solo si no existe. Una version ya construida no se toca nunca mas,
#    asi revertir significa reusar exactamente lo que ya funcionaba.
if [ "$MODO" = "docker" ]; then
  if docker image inspect "campusflow-avisos:$VERSION" >/dev/null 2>&1; then
    echo "Imagen $VERSION ya existe, se reutiliza sin reconstruir"
  else
    docker build -t "campusflow-avisos:$VERSION" "$RAIZ" || exit 1
  fi
else
  if [ -d "$DESP/versiones/$VERSION" ]; then
    echo "Version $VERSION ya construida, se reutiliza sin reconstruir"
  else
    mkdir -p "$DESP/versiones/$VERSION"
    cp -r "$RAIZ/app" "$DESP/versiones/$VERSION/app"
    echo "Version $VERSION construida en despliegues/versiones/$VERSION"
  fi
fi

# 2. recordar cual era la version anterior
anterior=""; [ -f "$DESP/actual" ] && anterior="$(cat "$DESP/actual")"

# 3. cambiar de version
parar
arrancar "$VERSION"
if esperar_salud "$VERSION"; then
  echo "$VERSION" > "$DESP/actual"
  [ -n "$anterior" ] && echo "$anterior" > "$DESP/previa"
  echo "DESPLIEGUE OK: $VERSION esta sana y atendiendo"
  exit 0
fi

# 4. si no respondio sana, volver sola a la anterior
echo "DESPLIEGUE FALLO: $VERSION no paso la verificacion de salud"
parar
if [ -n "$anterior" ]; then
  echo "Volviendo automaticamente a $anterior"
  ROMPER=0 arrancar "$anterior"
  if esperar_salud "$anterior"; then echo "REVERSION OK: $anterior esta sana otra vez"; else echo "REVERSION FALLO"; fi
else
  echo "No hay version anterior a la cual volver"
fi
exit 1
