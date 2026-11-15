"""Servicio de avisos de CampusFlow. Solo usa la libreria estandar."""
import json
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

VARIABLES_OBLIGATORIAS = ["APP_PORT", "APP_VERSION", "APP_ENTORNO", "ARCHIVO_AVISOS"]
INICIO = time.time()


def leer_config(entorno=None):
    entorno = os.environ if entorno is None else entorno
    faltan = [v for v in VARIABLES_OBLIGATORIAS if not entorno.get(v)]
    if faltan:
        raise ValueError("Faltan variables de entorno: " + ", ".join(faltan))
    try:
        puerto = int(entorno["APP_PORT"])
    except ValueError:
        raise ValueError("APP_PORT debe ser un numero")
    return {
        "puerto": puerto,
        "version": entorno["APP_VERSION"],
        "entorno": entorno["APP_ENTORNO"],
        "archivo": entorno["ARCHIVO_AVISOS"],
    }


def cargar_avisos(archivo):
    if not os.path.exists(archivo):
        return []
    with open(archivo, encoding="utf-8") as f:
        return json.load(f)


def guardar_avisos(archivo, avisos):
    carpeta = os.path.dirname(archivo)
    if carpeta:
        os.makedirs(carpeta, exist_ok=True)
    with open(archivo, "w", encoding="utf-8") as f:
        json.dump(avisos, f, ensure_ascii=False)


def crear_manejador(config):
    class Manejador(BaseHTTPRequestHandler):
        def _responder(self, codigo, cuerpo):
            datos = json.dumps(cuerpo, ensure_ascii=False).encode("utf-8")
            self.send_response(codigo)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(datos)))
            self.end_headers()
            self.wfile.write(datos)

        def do_GET(self):
            if self.path == "/salud":
                self._responder(200, {
                    "estado": "ok",
                    "version": config["version"],
                    "entorno": config["entorno"],
                    "segundos_activo": round(time.time() - INICIO, 1),
                })
            elif self.path == "/avisos":
                self._responder(200, cargar_avisos(config["archivo"]))
            else:
                self._responder(404, {"error": "ruta no existe"})

        def do_POST(self):
            if self.path != "/avisos":
                return self._responder(404, {"error": "ruta no existe"})
            largo = int(self.headers.get("Content-Length", 0))
            try:
                dato = json.loads(self.rfile.read(largo))
                texto = dato["texto"].strip()
            except Exception:
                return self._responder(400, {"error": "mande un json con el campo texto"})
            if not texto:
                return self._responder(400, {"error": "el texto no puede ir vacio"})
            avisos = cargar_avisos(config["archivo"])
            avisos.append({"id": len(avisos) + 1, "texto": texto})
            guardar_avisos(config["archivo"], avisos)
            self._responder(201, avisos[-1])

        def log_message(self, formato, *args):
            sys.stdout.write("[%s] %s\n" % (config["version"], formato % args))
            sys.stdout.flush()

    return Manejador


def main():
    try:
        config = leer_config()
    except ValueError as error:
        print("ERROR DE CONFIGURACION: %s" % error, flush=True)
        sys.exit(1)
    print("Arrancando avisos version %s en entorno %s puerto %d" % (
        config["version"], config["entorno"], config["puerto"]), flush=True)
    HTTPServer(("0.0.0.0", config["puerto"]), crear_manejador(config)).serve_forever()


if __name__ == "__main__":
    main()
