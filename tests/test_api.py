"""Testes da API (fase 2).

Usam um modelo de brinquedo salvo num diretório temporário, então rodam
sem treinar o modelo de verdade e sem baixar o corpus.
"""

import importlib

import joblib
import pytest
from fastapi.testclient import TestClient

from app.schemas import MAX_CHARS
from model.train import build_pipeline


@pytest.fixture(scope="module")
def client(tmp_path_factory):
    texts = ["urgente compartilhe antes que apaguem"] * 3 + ["ministério divulgou relatório nesta terça"] * 3
    labels = ["falsa"] * 3 + ["verdadeira"] * 3
    path = tmp_path_factory.mktemp("model") / "toy.joblib"
    joblib.dump(
        {"pipeline": build_pipeline().fit(texts, labels), "metadata": {"model_version": "test"}},
        path,
    )

    mp = pytest.MonkeyPatch()
    mp.setenv("MODEL_PATH", str(path))
    import app.main

    importlib.reload(app.main)  # relê MODEL_PATH
    with TestClient(app.main.app) as c:  # o "with" dispara o lifespan (carrega o modelo)
        yield c
    mp.undo()


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok", "versao_modelo": "test"}


def test_predict_returns_class_and_confidence(client):
    r = client.post("/predict", json={"texto": "urgente, compartilhe!"})
    assert r.status_code == 200
    body = r.json()
    assert body["classe"] == "falsa"
    assert 0.5 <= body["confianca"] <= 1
    assert set(body["probabilidades"]) == {"falsa", "verdadeira"}
    assert "não verifica" in body["aviso"]


@pytest.mark.parametrize(
    "payload",
    [{}, {"texto": ""}, {"texto": "   "}, {"texto": "a" * (MAX_CHARS + 1)}, {"texto": 123}],
)
def test_predict_rejects_invalid_input(client, payload):
    assert client.post("/predict", json=payload).status_code == 422


def test_metrics_counts_requests_and_confidence(client):
    client.post("/predict", json={"texto": "urgente, compartilhe!"})
    client.post("/predict", json={"texto": ""})  # 422 também é contado
    r = client.get("/metrics")
    assert r.status_code == 200
    body = r.text
    assert 'http_requests_total{method="POST",path="/predict",status="200"}' in body
    assert 'http_requests_total{method="POST",path="/predict",status="422"}' in body
    assert "http_request_duration_seconds_bucket" in body
    assert 'fake_news_prediction_confidence_count{classe="falsa"}' in body
    assert 'path="/metrics"' not in body  # o próprio scrape não entra na conta
