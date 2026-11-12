"""API do detector de notícias falsas.

Rodar local: make run   (ou: uvicorn app.main:app --reload)
Documentação interativa: http://localhost:8000/docs
"""

import os
from contextlib import asynccontextmanager
from pathlib import Path

import joblib
from fastapi import FastAPI

from app.schemas import HealthResponse, PredictRequest, PredictResponse

DEFAULT_MODEL = Path(__file__).parent.parent / "model" / "artifacts" / "fake_news.joblib"
MODEL_PATH = Path(os.getenv("MODEL_PATH", DEFAULT_MODEL))

# Preenchido uma única vez na inicialização (não a cada requisição)
state: dict = {}


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Se o arquivo não existir, a API nem sobe: melhor falhar cedo do que
    # responder errado. No Kubernetes, o pod não fica "pronto".
    bundle = joblib.load(MODEL_PATH)
    state["pipeline"] = bundle["pipeline"]
    state["metadata"] = bundle["metadata"]
    yield
    state.clear()


app = FastAPI(title="Detector de notícias falsas (demo)", version="1.0.0", lifespan=lifespan)


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(status="ok", versao_modelo=state["metadata"]["model_version"])


@app.post("/predict", response_model=PredictResponse)
def predict(req: PredictRequest) -> PredictResponse:
    pipeline = state["pipeline"]
    # predict_proba devolve uma coluna por classe, na ordem de pipeline.classes_
    probs = pipeline.predict_proba([req.texto])[0]
    por_classe = {c: round(float(p), 4) for c, p in zip(pipeline.classes_, probs)}
    classe = max(por_classe, key=por_classe.get)
    return PredictResponse(
        classe=classe,
        confianca=por_classe[classe],
        probabilidades=por_classe,
        versao_modelo=state["metadata"]["model_version"],
    )
