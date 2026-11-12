"""Métricas Prometheus da API, expostas em GET /metrics.

Cada pod expõe as SUAS métricas; o Prometheus coleta de todos e soma.
"""

import time

from prometheus_client import Counter, Histogram
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request

# Contagem de requisições. Os erros saem do status (4xx, 5xx).
REQUESTS = Counter(
    "http_requests_total", "Requisições HTTP recebidas", ["method", "path", "status"]
)

# Latência em segundos. Os buckets são os "degraus" do histograma.
LATENCY = Histogram(
    "http_request_duration_seconds",
    "Tempo de resposta das requisições HTTP",
    ["method", "path"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5),
)

# Confiança das previsões. Se a distribuição mudar com o tempo (mais previsões
# perto de 0,5), os textos de hoje podem estar diferentes dos de treino.
CONFIDENCE = Histogram(
    "fake_news_prediction_confidence",
    "Confiança da classe prevista",
    ["classe"],
    buckets=(0.5, 0.6, 0.7, 0.8, 0.9, 0.95, 0.99, 1.0),
)


class MetricsMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        start = time.perf_counter()
        status = 500  # se a rota estourar uma exceção, conta como erro
        try:
            response = await call_next(request)
            status = response.status_code
            return response
        finally:
            # Usa o MODELO da rota ("/predict"), nunca a URL crua: URLs
            # inventadas criariam séries infinitas no Prometheus.
            route = request.scope.get("route")
            path = route.path if route else "desconhecida"
            if path != "/metrics":
                LATENCY.labels(request.method, path).observe(time.perf_counter() - start)
                REQUESTS.labels(request.method, path, str(status)).inc()
