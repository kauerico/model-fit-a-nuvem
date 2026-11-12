# Observabilidade

## O que a API mede (`GET /metrics`)

| Métrica | Tipo | Para quê |
|---|---|---|
| `http_requests_total{method, path, status}` | Counter | volume de requisições; erros são os status 4xx e 5xx |
| `http_request_duration_seconds{method, path}` | Histogram | latência (p50, p95, p99) |
| `fake_news_prediction_confidence{classe}` | Histogram | distribuição da confiança das previsões |

O rótulo `path` usa o modelo da rota (`/predict`), nunca a URL crua. Com a
URL crua, cada endereço inventado criaria uma série nova no Prometheus.

A confiança é a métrica de **ML**. Se, com o tempo, mais previsões
caírem perto de 0,5, os textos que chegam podem estar diferentes dos de
treino (*data drift*), e o modelo merece ser reavaliado.

## Prometheus no cluster

O Prometheus é um Deployment só, definido em
[`helm/fake-news/templates/prometheus.yaml`](../helm/fake-news/templates/prometheus.yaml)
e ligado em `values-aws.yaml`, sem Grafana. Ele descobre sozinho os pods com
a anotação `prometheus.io/scrape: "true"` e coleta o `/metrics` de cada
réplica a cada 15 s. Os dados ficam no próprio pod por 2 dias e somem ao
reiniciar; numa demo, isso basta.

A interface **não fica aberta na internet**: a NodePort 30090 está fechada
no security group. O acesso é por um túnel do SSM (veja o PROCEDIMENTO.md,
passo 9).

## Consultas para a demonstração

Requisições por segundo, por rota e status:

```promql
sum by (path, status) (rate(http_requests_total[1m]))
```

Taxa de erro, em fração das requisições que deram 5xx:

```promql
sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))
```

Latência p95 do `/predict`:

```promql
histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{path="/predict"}[5m])))
```

Previsões por classe:

```promql
sum by (classe) (increase(fake_news_prediction_confidence_count[10m]))
```

Fração das previsões com confiança abaixo de 0,7 (o sinal de drift):

```promql
sum(fake_news_prediction_confidence_bucket{le="0.7"}) / sum(fake_news_prediction_confidence_count)
```

## O equivalente gerenciado na AWS: CloudWatch

Aqui o Prometheus roda dentro do cluster porque é simples e gratuito. Em
produção na AWS, as opções gerenciadas são:

- **CloudWatch Container Insights:** coleta CPU, memória e reinícios dos
  pods sem nada no código. No EKS é um add-on.
- **CloudWatch Agent com scraping Prometheus:** o agente lê o mesmo
  `/metrics` da API e envia para o CloudWatch Metrics, sem mudar o código.
- **Amazon Managed Service for Prometheus (AMP):** um Prometheus gerenciado
  que aceita as mesmas consultas PromQL. Costuma vir acompanhado do Amazon
  Managed Grafana.
- **CloudWatch Alarms:** o equivalente das regras de alerta. Por exemplo,
  um alarme quando a taxa de erro passar de 1% em 5 minutos.

| Aqui (demo) | Na AWS gerenciada |
|---|---|
| Prometheus no pod | Amazon Managed Service for Prometheus ou CloudWatch Metrics |
| PromQL na interface do Prometheus | PromQL no AMP/Grafana ou CloudWatch Metrics Insights |
| Logs com `kubectl logs` | CloudWatch Logs (Fluent Bit) |
| (sem alertas) | CloudWatch Alarms + SNS |

Os serviços gerenciados cobram por métrica, ingestão e consulta. Para uma
demo de uma hora, o Prometheus no cluster custa zero.
