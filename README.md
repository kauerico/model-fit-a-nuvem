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

O passo a passo completo, do treino à AWS, está em
**[PROCEDIMENTO.md](PROCEDIMENTO.md)**. O resumo local:

```bash
uv venv -p 3.11 .venv && source .venv/bin/activate
uv pip install -r requirements-dev.txt
python -m model.train            # baixa o corpus e treina (~10 s)
pytest -q                        # testes
uvicorn app.main:app --reload    # API em http://localhost:8000 (docs em /docs)
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
| `GET /metrics`  | métricas Prometheus: requisições, erros, latência e confiança ([detalhes](docs/observabilidade.md)) |
| `GET /docs`     | documentação interativa gerada pelo FastAPI                      |

Entrada inválida (texto ausente, vazio, só espaços ou longo demais)
recebe HTTP 422. O modelo é carregado uma única vez, quando a API sobe.
Se o arquivo não existir, a API não inicia.

## Docker

```bash
docker build -t fake-news:dev .
docker run --rm -p 8000:8000 fake-news:dev
```

O [`Dockerfile`](Dockerfile) tem dois estágios:

1. **treino:** instala as dependências e roda `model/train.py`, gerando o
   `.joblib` dentro do build. A imagem é reproduzível a partir do código e
   não depende de nenhum arquivo da sua máquina. O estágio roda na
   arquitetura de quem faz o build, porque o modelo não depende de CPU:
   treinamos uma vez e copiamos para as duas imagens.
2. **final:** usa `python:3.11-slim`, copia as dependências **antes** do
   código (para aproveitar o cache de camadas), depois a API e o modelo, e
   roda como usuário sem privilégios (uid 10001).

O CI constrói a imagem para amd64 e arm64 e a publica no GHCR. Para
construir as duas localmente numa máquina x86, instale o emulador QEMU
(`docker run --privileged --rm tonistiigi/binfmt --install arm64`) e rode
`docker buildx build --platform linux/amd64,linux/arm64 .`.

## Na AWS

- **Infraestrutura** ([`terraform/`](terraform/)), aplicada à mão: uma EC2
  t4g.small (arm64) com k3s em us-east-2, um security group que libera só a
  NodePort 30080 da API (a 6443 nunca fica exposta), o papel IAM do SSM e um
  alerta do AWS Budgets. O estado fica num bucket S3.
- **App** ([`helm/fake-news/`](helm/fake-news/)): Deployment com 2 réplicas,
  probes em `/health`, requests/limits pequenos e Service NodePort.
- **Observabilidade:** um Prometheus mínimo no cluster coleta o `/metrics`
  de cada réplica. Ele não fica exposto na internet; o acesso é por túnel do
  SSM. O equivalente gerenciado na AWS (CloudWatch) está descrito em
  [docs/observabilidade.md](docs/observabilidade.md).
- **CI/CD** ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)): a cada
  push na `main`, testa, constrói a imagem (amd64 e arm64), publica no GHCR
  e, se a EC2 estiver no ar, roda o `helm upgrade` via AWS SSM (sem SSH e
  sem porta extra). Depois verifica a API e faz rollback se ela falhar. As
  credenciais ficam em GitHub Secrets.

## Dados

Usamos o **[Fake.br Corpus](https://github.com/roneysco/Fake.br-Corpus)**
(NILC/USP): 7.200 notícias em português, sendo 3.600 falsas e 3.600
verdadeiras, na versão `size_normalized_texts`. Nessa versão, em cada par o
texto maior é cortado para o tamanho do menor, então o modelo não acerta só
porque notícias falsas costumam ser mais curtas.

- **Licença:** o repositório do corpus não declara licença; os autores pedem
  apenas citação. Por isso **não redistribuímos os dados**: `python -m model.train`
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

Uma única EC2 t4g.small com k3s custa cerca de US$ 0,55 por dia ligada
(instância, disco e IP público), coberta pelos créditos da conta. Não usamos
EKS: só o plano de controle dele custaria cerca de US$ 73 por mês. O AWS
Budgets avisa por e-mail se o gasto do mês passar de US$ 5. Para apagar tudo,
rode `terraform destroy` (veja o checklist no PROCEDIMENTO.md).

## Andamento

- [x] Fase 0: estrutura e README
- [x] Fase 1: treino do modelo
- [x] Fase 2: API FastAPI
- [x] Fase 3: Docker
- [ ] Fase 4: Kubernetes local (k3d), pulada: fomos direto para a AWS
- [x] Fase 5: Terraform (EC2 + k3s), escrito, falta aplicar
- [ ] Fase 6: deploy na EC2
- [x] Fase 7: CI/CD (teste, build e publicação validados; deploy pendente da EC2)
- [x] Fase 8: observabilidade (`/metrics` + Prometheus)
- [ ] Fase 9: fechamento
