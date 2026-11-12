# Do model.fit() à Nuvem — atalhos da demo.
# Rode `make` (ou `make help`) para ver os alvos.

PYTHON_VERSION := 3.11
VENV   := .venv
PY     := $(VENV)/bin/python

# Imagem no GitHub Container Registry (mesmo nome do repositório).
IMAGE_OWNER ?= kauerico
IMAGE       ?= ghcr.io/$(IMAGE_OWNER)/model-fit-a-nuvem
TAG         ?= dev

.DEFAULT_GOAL := help
.PHONY: help venv train test run build k3d-up deploy destroy clean

help: ## Lista os alvos disponíveis
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

venv: $(VENV)/.ok ## Cria o ambiente virtual com Python 3.11

# Usa uv se estiver instalado (baixa o Python 3.11 sozinho); senão, python3.11.
$(VENV)/.ok: requirements.txt
	@if command -v uv >/dev/null; then \
		[ -x $(PY) ] || uv venv -q -p $(PYTHON_VERSION) $(VENV); \
		uv pip install -q -p $(PY) -r requirements.txt; \
	else \
		[ -x $(PY) ] || python$(PYTHON_VERSION) -m venv $(VENV); \
		$(PY) -m pip install -q -r requirements.txt; \
	fi
	@touch $@

train: venv ## Fase 1: treina o modelo e salva o .joblib
	$(PY) -m model.train

test: venv ## Roda os testes com pytest
	$(PY) -m pytest -q

run: venv ## Sobe a API em http://localhost:8000 (docs em /docs)
	$(PY) -m uvicorn app.main:app --reload --port 8000

build: ## Fase 3: constrói a imagem Docker
	@echo "TODO (fase 3): docker build -t $(IMAGE):$(TAG) ."

k3d-up: ## Fase 4: cria o cluster Kubernetes local (k3d)
	@echo "TODO (fase 4): k3d cluster create"

deploy: ## Fase 4/6: instala o chart Helm no cluster atual
	@echo "TODO (fase 4/6): helm upgrade --install"

destroy: ## Fase 9: apaga TUDO na AWS (pede confirmação)
	@echo "TODO (fase 9): terraform destroy"

clean: ## Remove ambiente virtual e caches locais
	rm -rf $(VENV) .pytest_cache
	find . -name __pycache__ -type d -prune -exec rm -rf {} +
