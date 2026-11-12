"""Formato de entrada e saída da API (validado pelo Pydantic)."""

from typing import Annotated

from pydantic import BaseModel, Field, StringConstraints

MAX_CHARS = 10_000

AVISO = (
    "Modelo de demonstração: ele reconhece padrões de escrita do corpus de "
    "treino e não verifica se os fatos são verdadeiros."
)


class PredictRequest(BaseModel):
    # strip_whitespace: um texto só com espaços vira "" e é recusado por min_length
    texto: Annotated[
        str, StringConstraints(strip_whitespace=True, min_length=1, max_length=MAX_CHARS)
    ] = Field(examples=["URGENTE: compartilhe antes que apaguem!"])


class PredictResponse(BaseModel):
    classe: str = Field(examples=["falsa"])
    confianca: float = Field(ge=0, le=1, examples=[0.87])
    probabilidades: dict[str, float]
    versao_modelo: str
    aviso: str = AVISO


class HealthResponse(BaseModel):
    status: str
    versao_modelo: str
