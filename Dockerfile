# Version fija de la imagen base. Nada de latest.
FROM python:3.12.7-slim

# Usuario normal para no correr como root
RUN useradd --create-home appuser
WORKDIR /srv
COPY app ./app

# Valores por defecto inofensivos. Los reales llegan por variables de entorno.
ENV APP_PORT=8080
USER appuser
EXPOSE 8080

# El contenedor se marca sano solo si /salud responde
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request,os; urllib.request.urlopen('http://127.0.0.1:'+os.environ['APP_PORT']+'/salud')"

CMD python -m app.servicio
