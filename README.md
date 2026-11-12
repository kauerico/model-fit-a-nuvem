# Do model.fit() à Nuvem

Repositório de demonstração da palestra para alunos de Ciência da Computação.
Pegamos um modelo de texto simples (um detector de notícias falsas em
português) e o colocamos em produção como microserviço, num Kubernetes real
na AWS, com infraestrutura como código, CI/CD e observabilidade.

> **Aviso:** este é um modelo de demonstração. Ele aprende **padrões de
> escrita** do corpus de treino e **não verifica fatos**. Não use as
> previsões dele para decidir se uma notícia é verdadeira.

## Arquitetura (resumo)

```
model/train.py ──► fake_news.joblib ──► app/ (FastAPI) ──► imagem Docker (GHCR)
                                                                │
                         GitHub Actions (testa, builda, publica, implanta)
                                                                │
                                                                ▼
                         EC2 (Terraform) ── k3s ── Helm chart ── /predict, /metrics
                                                                │
                                                           Prometheus
```

## Stack

Python 3.11, scikit-learn, FastAPI, Pydantic, Docker, k3s (k3d no local),
Helm, Terraform (AWS), GitHub Actions, GHCR e Prometheus.

## Estrutura

| Pasta                 | Conteúdo                                           |
|-----------------------|----------------------------------------------------|
| `model/`              | treino, dados e métricas do modelo                 |
| `app/`                | API FastAPI, schemas e métricas                    |
| `tests/`              | testes com pytest                                  |
| `Dockerfile`          | imagem da API                                      |
| `helm/fake-news/`     | chart Kubernetes (values-local e values-aws)       |
| `terraform/`          | EC2, security group e instalação do k3s            |
| `.github/workflows/`  | pipeline de CI/CD                                  |
| `docs/`               | diagrama e decisões de arquitetura (ADRs)          |

## Como rodar

Pré-requisitos locais: `make`, Docker e [uv](https://docs.astral.sh/uv/)
(ou Python 3.11 instalado).

```bash
make          # lista os alvos
make test     # cria o .venv com Python 3.11 e roda os testes
```

Os demais alvos (`train`, `run`, `build`, `k3d-up`, `deploy`, `destroy`)
serão preenchidos nas próximas fases.

## Dados

Corpus: _a definir na fase 1 (fonte e licença serão registradas aqui)._
Nenhum dado pessoal é usado.

## Custos

Uma única instância EC2 pequena com k3s, coberta pelos créditos da conta.
Não usamos EKS. `make destroy` apagará tudo ao final (fase 9).

## Andamento

- [x] Fase 0: estrutura, README e Makefile
- [ ] Fase 1: treino do modelo
- [ ] Fase 2: API FastAPI
- [ ] Fase 3: Docker
- [ ] Fase 4: Kubernetes local (k3d + Helm)
- [ ] Fase 5: Terraform (EC2 + k3s)
- [ ] Fase 6: deploy na EC2
- [ ] Fase 7: CI/CD
- [ ] Fase 8: observabilidade
- [ ] Fase 9: fechamento
