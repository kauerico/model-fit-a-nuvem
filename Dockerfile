# syntax=docker/dockerfile:1
# Imagem da API em dois estágios:
#   1. "treino": baixa o corpus e gera o fake_news.joblib
#   2. "final":  só o Python, as dependências, o código da API e o modelo

# ---------- Estágio 1: treino ----------
# Roda na arquitetura de quem faz o build ($BUILDPLATFORM): o .joblib não
# depende de CPU, então treinamos uma vez e copiamos para amd64 e arm64.
FROM --platform=$BUILDPLATFORM python:3.11-slim AS treino
WORKDIR /src
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY model/ model/
RUN python -m model.train

# ---------- Estágio 2: final ----------
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    MODEL_PATH=/app/model/fake_news.joblib

WORKDIR /app

# Dependências ANTES do código: se só o código mudar, o Docker reaproveita
# esta camada do cache e o build fica muito mais rápido.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ app/
COPY --from=treino /src/model/artifacts/fake_news.joblib /app/model/fake_news.joblib

# Nunca rodar como root dentro do contêiner
RUN useradd --uid 10001 --no-create-home appuser
USER 10001

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
