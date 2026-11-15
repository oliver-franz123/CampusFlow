import json
import os
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from http.server import HTTPServer

from app import servicio

BASE = {"APP_PORT": "8080", "APP_VERSION": "t", "APP_ENTORNO": "test", "ARCHIVO_AVISOS": "x.json"}


class PruebasConfig(unittest.TestCase):
    def test_config_completa(self):
        self.assertEqual(servicio.leer_config(BASE)["puerto"], 8080)

    def test_falta_variable(self):
        malo = dict(BASE)
        del malo["APP_VERSION"]
        with self.assertRaises(ValueError):
            servicio.leer_config(malo)

    def test_puerto_no_numerico(self):
        malo = dict(BASE, APP_PORT="abc")
        with self.assertRaises(ValueError):
            servicio.leer_config(malo)


class PruebasHttp(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        config = {"puerto": 0, "version": "t", "entorno": "test",
                  "archivo": os.path.join(self.tmp.name, "avisos.json")}
        self.srv = HTTPServer(("127.0.0.1", 0), servicio.crear_manejador(config))
        self.url = "http://127.0.0.1:%d" % self.srv.server_address[1]
        threading.Thread(target=self.srv.serve_forever, daemon=True).start()

    def tearDown(self):
        self.srv.shutdown()
        self.srv.server_close()
        self.tmp.cleanup()

    def pedir(self, ruta, cuerpo=None):
        datos = None if cuerpo is None else json.dumps(cuerpo).encode()
        req = urllib.request.Request(self.url + ruta, data=datos)
        try:
            with urllib.request.urlopen(req) as r:
                return r.status, json.loads(r.read())
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read())

    def test_salud(self):
        codigo, cuerpo = self.pedir("/salud")
        self.assertEqual(codigo, 200)
        self.assertEqual(cuerpo["estado"], "ok")

    def test_crear_y_listar(self):
        self.assertEqual(self.pedir("/avisos", {"texto": "Hola"})[0], 201)
        self.assertEqual(self.pedir("/avisos")[1][0]["texto"], "Hola")

    def test_texto_vacio(self):
        self.assertEqual(self.pedir("/avisos", {"texto": "  "})[0], 400)

    def test_ruta_inexistente(self):
        self.assertEqual(self.pedir("/nada")[0], 404)


if __name__ == "__main__":
    unittest.main()
