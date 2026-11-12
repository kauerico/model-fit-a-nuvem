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
.PHONY: help venv train test run build docker-run buildx k3d-up deploy \
        tf-init tf-plan tf-apply aws-info aws-deploy aws-rollback destroy clean

help: ## Lista os alvos disponíveis
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-13s\033[0m %s\n", $$1, $$2}'

venv: $(VENV)/.ok ## Cria o ambiente virtual com Python 3.11

# Usa uv se estiver instalado (baixa o Python 3.11 sozinho); senão, python3.11.
$(VENV)/.ok: requirements.txt requirements-dev.txt
	@if command -v uv >/dev/null; then \
		[ -x $(PY) ] || uv venv -q -p $(PYTHON_VERSION) $(VENV); \
		uv pip install -q -p $(PY) -r requirements-dev.txt; \
	else \
		[ -x $(PY) ] || python$(PYTHON_VERSION) -m venv $(VENV); \
		$(PY) -m pip install -q -r requirements-dev.txt; \
	fi
	@touch $@

train: venv ## Fase 1: treina o modelo e salva o .joblib
	$(PY) -m model.train

test: venv ## Roda os testes com pytest
	$(PY) -m pytest -q

run: venv ## Sobe a API em http://localhost:8000 (docs em /docs)
	$(PY) -m uvicorn app.main:app --reload --port 8000

PLATFORMS ?= linux/amd64,linux/arm64

build: ## Constrói a imagem para a arquitetura desta máquina
	docker build -t $(IMAGE):$(TAG) .

docker-run: ## Roda a imagem em http://localhost:8000
	docker run --rm -p 8000:8000 $(IMAGE):$(TAG)

# Multi-arquitetura (amd64 + arm64). PUSH=1 publica no GHCR (precisa de login).
buildx: ## Constrói para amd64 e arm64 (PUSH=1 publica no GHCR)
	docker buildx build --platform $(PLATFORMS) -t $(IMAGE):$(TAG) \
		$(if $(filter 1,$(PUSH)),--push,) .

k3d-up: ## Fase 4: cria o cluster Kubernetes local (k3d)
	@echo "TODO (fase 4): k3d cluster create"

deploy: ## Fase 4/6: instala o chart Helm no cluster atual
	@echo "TODO (fase 4/6): helm upgrade --install"

# ---------- AWS ----------
TF          := terraform -chdir=terraform
AWS_PROFILE ?= default
AWS_REGION  ?= us-east-2
export AWS_PROFILE AWS_REGION

# O caminho principal é o GitHub Actions (workflow "infra": up/down).
# Estes alvos fazem o mesmo da sua máquina, com as credenciais do `aws login`.
TF_STATE_BUCKET ?= $(error defina TF_STATE_BUCKET=<bucket S3 do estado>)

# Tag da imagem no GHCR = SHA do commit (é o que o CI publica)
DEPLOY_TAG ?= $(shell git rev-parse HEAD)

tf-init: ## Inicializa o Terraform com o estado no S3 (TF_STATE_BUCKET=...)
	$(TF) init -backend-config="bucket=$(TF_STATE_BUCKET)"

tf-plan: ## Mostra o que o Terraform vai criar/mudar (não gasta nada)
	$(TF) plan -out=tfplan

tf-apply: ## Aplica o último plano (cria recursos que custam dinheiro)
	$(TF) apply tfplan

aws-info: ## Mostra o ID e a URL da EC2 da demo
	scripts/ssm-deploy.sh info

aws-deploy: ## Implanta DEPLOY_TAG (padrão: commit atual) na EC2 via SSM
	scripts/ssm-deploy.sh deploy $(DEPLOY_TAG)

aws-rollback: ## Volta para a versão anterior do Helm na EC2
	scripts/ssm-deploy.sh rollback

destroy: ## Apaga TUDO na AWS (o Terraform pede confirmação)
	$(TF) destroy

clean: ## Remove ambiente virtual e caches locais
	rm -rf $(VENV) .pytest_cache
	find . -name __pycache__ -type d -prune -exec rm -rf {} +
