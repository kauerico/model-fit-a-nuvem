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
make train    # baixa o corpus e treina o modelo (~10 s)
make test     # cria o .venv com Python 3.11 e roda os testes
make run      # sobe a API em http://localhost:8000 (docs em /docs)
```

Em outro terminal:

```bash
curl localhost:8000/health
curl localhost:8000/predict -H 'Content-Type: application/json' \
     -d '{"texto": "URGENTE: compartilhe antes que apaguem!"}'
```

## API

| Rota            | O que faz                                                       |
|-----------------|-----------------------------------------------------------------|
| `POST /predict` | recebe `{"texto": "..."}` (de 1 a 10.000 caracteres) e devolve `classe`, `confianca`, `probabilidades`, `versao_modelo` e um `aviso` |
| `GET /health`   | `{"status": "ok", ...}` quando o modelo está carregado           |
| `GET /docs`     | documentação interativa gerada pelo FastAPI                      |

Entrada inválida (texto ausente, vazio, só espaços ou longo demais)
recebe HTTP 422. O modelo é carregado uma única vez, quando a API sobe.
Se o arquivo não existir, a API não inicia.

Os demais alvos (`build`, `k3d-up`, `deploy`, `destroy`)
serão preenchidos nas próximas fases.

## Dados

Usamos o **[Fake.br Corpus](https://github.com/roneysco/Fake.br-Corpus)**
(NILC/USP): 7.200 notícias em português, sendo 3.600 falsas e 3.600
verdadeiras, na versão `size_normalized_texts`. Nessa versão, em cada par o
texto maior é cortado para o tamanho do menor, então o modelo não acerta só
porque notícias falsas costumam ser mais curtas.

- **Licença:** o repositório do corpus não declara licença; os autores pedem
  apenas citação. Por isso **não redistribuímos os dados**: `make train`
  baixa o corpus da fonte, fixado no commit `780f551`, para `model/data/`,
  pasta ignorada pelo git.
- **Sem dados pessoais:** o corpus traz só notícias públicas, sem dados de
  alunos ou de terceiros (LGPD).
- **Citação:**
  - Monteiro R.A., Santos R.L.S., Pardo T.A.S., de Almeida T.A., Ruiz E.E.S.,
    Vale O.A. (2018). *Contributions to the Study of Fake News in Portuguese:
    New Corpus and Automatic Detection Results.* PROPOR 2018, LNCS 11122,
    p. 324–334.
  - Silva R.M., Santos R.L.S., Almeida T.A., Pardo T.A.S. (2020). *Towards
    automatically filtering fake news in Portuguese.* Expert Systems with
    Applications, 146, 113199.

## Modelo

`model/train.py` monta um `Pipeline` do scikit-learn (TF-IDF de palavras e
pares de palavras + regressão logística), treina com 80% dos dados e avalia
nos 20% restantes. Ele salva `model/artifacts/fake_news.joblib` com o
Pipeline e os metadados (versão do modelo, ordem das classes, versão do
scikit-learn e métricas). As métricas também ficam em
[`model/metrics.json`](model/metrics.json), que é versionado.

| Métrica (teste, 1.440 notícias) | Valor |
|---------------------------------|-------|
| Acurácia                        | 0,921 |
| F1 (macro)                      | 0,921 |

O modelo aprende **padrões de escrita** desse corpus (vocabulário, tom,
expressões típicas). Ele não sabe se um fato é verdadeiro e pode errar com
textos de outras épocas ou de outros estilos.

## Custos

Uma única instância EC2 pequena com k3s, coberta pelos créditos da conta.
Não usamos EKS. `make destroy` apagará tudo ao final (fase 9).

## Andamento

- [x] Fase 0: estrutura, README e Makefile
- [x] Fase 1: treino do modelo
- [x] Fase 2: API FastAPI
- [ ] Fase 3: Docker
- [ ] Fase 4: Kubernetes local (k3d + Helm)
- [ ] Fase 5: Terraform (EC2 + k3s)
- [ ] Fase 6: deploy na EC2
- [ ] Fase 7: CI/CD
- [ ] Fase 8: observabilidade
- [ ] Fase 9: fechamento
