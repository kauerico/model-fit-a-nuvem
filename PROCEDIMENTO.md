# Procedimento: do model.fit() à nuvem, comando por comando

Rode tudo a partir da raiz do repositório, salvo quando o passo disser outra
pasta.

## 0. Pré-requisitos (uma vez)

- Python 3.11 ou [uv](https://docs.astral.sh/uv/) (que baixa o 3.11 sozinho)
- Docker
- [Terraform](https://developer.hashicorp.com/terraform/install) e
  [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- Na AWS, criados pelo Console: o bucket S3 `fake-news-tfstate-kaue`
  (us-east-2, com versionamento)
- No GitHub (Settings → Secrets and variables → Actions): os Secrets
  `AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY`

## 1. Ambiente Python

```bash
uv venv -p 3.11 .venv
source .venv/bin/activate
uv pip install -r requirements-dev.txt
```

Sem uv: `python3.11 -m venv .venv && source .venv/bin/activate && pip install -r requirements-dev.txt`

## 2. Treinar o modelo

```bash
python -m model.train
```

O comando baixa o corpus, treina em cerca de 10 s, mostra as métricas e grava
`model/artifacts/fake_news.joblib`.

## 3. Testes

```bash
pytest -q
```

## 4. API local

```bash
uvicorn app.main:app --reload
```

Em outro terminal:

```bash
curl localhost:8000/health
curl localhost:8000/predict -H 'Content-Type: application/json' \
     -d '{"texto": "URGENTE: compartilhe antes que apaguem!"}'
```

A documentação interativa fica em http://localhost:8000/docs.

## 5. Docker

```bash
docker build -t fake-news:dev .
docker run --rm -p 8000:8000 fake-news:dev
```

Teste com os mesmos `curl` do passo 4.

## 6. Login na AWS

```bash
aws login
export AWS_REGION=us-east-2
aws sts get-caller-identity
```

Esta conta só libera EC2 em `us-east-2`, por isso o `export`.

## 7. Subir a infraestrutura (Terraform)

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # só na primeira vez: preencha o e-mail
terraform init
terraform plan -out=tfplan                     # revise: não gasta nada
terraform apply tfplan                         # a partir daqui custa (~US$ 0,55/dia)
terraform output
cd ..
```

O `apply` leva de 1 a 2 minutos. Depois, a EC2 ainda precisa de 2 a 4
minutos para instalar o k3s.

## 8. Implantar a app

**Pelo pipeline** (o jeito normal): faça um push na `main`, ou dispare o
workflow manualmente:

```bash
gh workflow run ci.yml
gh run watch
```

O pipeline testa, publica a imagem no GHCR, espera o k3s, roda o
`helm upgrade` na EC2 via SSM e testa a API. Se o teste falhar, ele faz
rollback.

**À mão**, se precisar:

```bash
scripts/ssm-deploy.sh wait                         # espera o k3s
scripts/ssm-deploy.sh deploy $(git rev-parse HEAD)  # imagem do último commit publicado
```

## 9. Ver e testar na AWS

```bash
scripts/ssm-deploy.sh info      # ID da EC2 e URL da API
scripts/ssm-deploy.sh status    # kubectl get nodes,pods,svc (via SSM)
scripts/verify.sh http://<IP>:30080
```

Com o `<IP>` mostrado pelo `info`, a plateia pode testar direto:

```bash
curl http://<IP>:30080/predict -H 'Content-Type: application/json' \
     -d '{"texto": "frase da plateia"}'
```

Se um deploy der problema: `scripts/ssm-deploy.sh rollback`.

### Métricas e Prometheus

As métricas da API ficam abertas na mesma porta:

```bash
curl http://<IP>:30080/metrics
```

A interface do Prometheus **não** fica exposta na internet. Para abri-la,
crie um túnel pelo SSM. É preciso o
[Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)
do AWS CLI.

```bash
aws ssm start-session --target <ID-DA-EC2> \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["30090"],"localPortNumber":["9090"]}'
```

Com o túnel aberto, acesse http://localhost:9090. As consultas para a
demonstração estão em [docs/observabilidade.md](docs/observabilidade.md).

Para gerar tráfego e ver os gráficos se mexerem:

```bash
for i in $(seq 50); do
  curl -s http://<IP>:30080/predict -H 'Content-Type: application/json' \
       -d '{"texto": "URGENTE: compartilhe antes que apaguem!"}' > /dev/null
done
```

## 10. Derrubar tudo (depois do seminário)

```bash
cd terraform
terraform destroy
cd ..
```

Checklist de custos:

- [ ] `terraform destroy` terminou sem erro
- [ ] Console EC2 (us-east-2): nenhuma instância `fake-news-k3s`
- [ ] IAM → Users → `usuario-servico-terraform`: chave de acesso apagada
- [ ] (Opcional) apagar o bucket `fake-news-tfstate-kaue`
