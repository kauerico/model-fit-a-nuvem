"""Testes do treino (fase 1)."""

import joblib
import pytest
import sklearn

from model.train import ARTIFACT, build_pipeline


def test_pipeline_learns_toy_data():
    # Dados minúsculos só para garantir que o Pipeline treina e prevê
    texts = ["urgente compartilhe antes que apaguem"] * 3 + ["ministério divulgou relatório nesta terça"] * 3
    labels = ["falsa"] * 3 + ["verdadeira"] * 3
    pipe = build_pipeline().fit(texts, labels)
    assert pipe.predict(["compartilhe urgente"])[0] == "falsa"


@pytest.mark.skipif(not ARTIFACT.exists(), reason="rode `make train` antes")
def test_artifact_has_metadata():
    bundle = joblib.load(ARTIFACT)
    meta = bundle["metadata"]
    assert meta["classes"] == list(bundle["pipeline"].classes_)
    assert meta["sklearn_version"] == sklearn.__version__
    assert meta["metrics"]["accuracy"] > 0.8
