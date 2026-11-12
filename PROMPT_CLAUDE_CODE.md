# Prompt para o Claude Code: demo "Do model.fit() à Nuvem"

Cole o texto abaixo na primeira mensagem do Claude Code, em uma pasta vazia (repositório novo).

---

Você vai construir, do zero e em fases, o repositório de demonstração de uma palestra de 30 a 50 minutos para alunos de Ciência da Computação: "Do model.fit() à Nuvem". Eu vou abrir o código ao vivo durante a palestra, então o repositório precisa ser pequeno, legível e fácil de navegar. Nada de código em slide.

## Objetivo
Pegar um modelo de texto simples (detector de notícias falsas em português) e colocá-lo em produção como microserviço, num Kubernetes real na AWS, com infraestrutura como código, CI/CD e observabilidade.

## Restrições (importante)
- Custo mínimo. Tenho conta AWS com US$ 100 em créditos. Use UMA instância EC2 com k3s (Kubernetes leve). EKS fica só na teoria (cerca de US$ 73/mês pelo plano de controle), não crie EKS.
- Modelo leve: scikit-learn, TF-IDF + regressão logística dentro de um `Pipeline`, salvo com joblib. Sem deep learning.
- É um modelo de demonstração: ele aprende padrões de escrita, não verifica fatos. Deixe isso explícito no README e na resposta da API.
- Corpus público em português (por exemplo o Fake.br Corpus). Confirme fonte e licença antes de usar e registre no README. Sem dados reais de alunos (LGPD).
- Segredos nunca no código: use GitHub Secrets e variáveis do Terraform.
- Tudo reproduzível: quem clonar o repositório deve conseguir rodar localmente com `make` e subir na AWS com Terraform.

## Stack
Python 3.11, scikit-learn, FastAPI, Pydantic, Docker, k3s (e k3d para rodar local), Helm, Terraform (AWS), GitHub Actions, GHCR, Prometheus e rota `/metrics`.

## Estrutura sugerida
```
.
├── README.md              # problema, arquitetura, como rodar, decisões
├── Makefile               # train, test, run, build, k3d-up, deploy, destroy
├── model/                 # train.py, dados, métricas
├── app/                   # main.py (FastAPI), schemas, métricas
├── tests/
├── Dockerfile
├── helm/fake-news/        # Deployment, Service, probes, values-local e values-aws
├── terraform/             # EC2, security group, user_data que instala o k3s
├── .github/workflows/     # ci.yml (testar, construir, publicar, implantar, verificar)
└── docs/                  # diagrama da arquitetura e decisões (ADRs curtos)
```

## Fases (faça uma por vez; ao final de cada uma, rode os testes, resuma o que fez e espere meu "ok")
0. Repositório, README inicial, Makefile e estrutura de pastas.
1. Treino: baixar/preparar o corpus, treinar o Pipeline, avaliar (acurácia, F1), salvar `fake_news.joblib` com metadados (versão do modelo, ordem das classes, versão do scikit-learn, métricas). Fixar versões no `requirements.txt`.
2. API FastAPI: `POST /predict` (valida entrada: texto não vazio e com tamanho máximo; devolve classe e confiança), `GET /health`, carrega o modelo uma vez na inicialização. Testes com pytest.
3. Docker: imagem enxuta (`python:3.11-slim`), dependências antes do código para aproveitar cache, usuário não root. Build multi-arquitetura (amd64 e arm64) com `buildx`. Testar com `docker run` e `curl`.
4. Kubernetes local: Helm chart (Deployment com 2 réplicas, Service, readiness/liveness em `/health`, requests/limits pequenos). Subir em k3d e validar.
5. Terraform: EC2 pequena (confirme na minha conta o tipo elegível ao free tier ou coberto pelos créditos, por exemplo t3.small ou t4g.small, e a região), security group (SSH só do meu IP, expor apenas a NodePort do serviço, nunca a 6443), `user_data` que instala o k3s. Outputs: IP público e comando para pegar o kubeconfig. Incluir AWS Budgets com alerta. `terraform plan` antes de qualquer `apply`; peça minha confirmação antes de aplicar.
6. Deploy na EC2 com Helm usando a imagem do GHCR. Validar com `curl` pelo IP público.
7. CI/CD no GitHub Actions: testar, construir a imagem, publicar no GHCR, `helm upgrade` na EC2, verificar health e fazer rollback se falhar. Segredos em GitHub Secrets.
8. Observabilidade: métricas em `/metrics` (latência, contagem de requisições e erros, distribuição da confiança das previsões), Prometheus simples no cluster, sem Grafana pesado. Documentar CloudWatch como o equivalente na AWS.
9. Fechamento: README polido com diagrama, roteiro de demonstração ao vivo (comandos na ordem em que vou mostrar), checklist de custos e `make destroy` que apaga tudo na AWS.

## Regras de trabalho
- Antes de cada fase, diga em poucas linhas o que vai fazer. Commits pequenos, com mensagens claras.
- Qualquer ação que gere custo ou apague algo (`terraform apply`, `terraform destroy`) precisa da minha confirmação explícita.
- Código simples e comentado só onde ajuda; é para ser lido por alunos.
- Se uma decisão for minha (tipo de instância, região, nome do repositório, corpus), pergunte em vez de assumir.

## Roteiro de demonstração (a palestra vai abrir estes arquivos, nesta ordem)
1. `model/train.py` e o arquivo `.joblib` gerado.
2. `app/main.py` e uma chamada `curl` ao vivo (peço uma frase à plateia).
3. `Dockerfile`, `docker build` e `docker run`.
4. `helm/fake-news/` e `kubectl get pods`.
5. `terraform/` com `plan` e a instância na AWS.
6. `.github/workflows/ci.yml` e um commit disparando o pipeline.
7. `/metrics` e o Prometheus.

Comece pela fase 0.
