# CampusFlow Avisos

Servicio chico de avisos para CampusFlow, empaquetado para que se construya, pruebe y despliegue siempre igual.

## Reproducir rapido
1. `cp .env.example .env`
2. `scripts/demo.sh` corre todo: pruebas, despliegue, fallo, reversion automatica y reversion manual.
3. `MODO=docker scripts/demo.sh` hace lo mismo con Docker real. Necesita Docker instalado.

## Piezas
- `app/servicio.py` el servicio. `/salud` y `/avisos`.
- `Dockerfile` imagen con version fija.
- `.env.example` variables necesarias.
- `scripts/ci.sh` pruebas y construccion, lo mismo que corre GitHub.
- `scripts/desplegar.sh` y `scripts/revertir.sh`.
- `.github/workflows/ci.yml` canalizacion.
- `evidencia/ejecucion.txt` salida real de una corrida.
