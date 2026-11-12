"""Treina o detector de notícias falsas: TF-IDF + regressão logística.

Uso: python -m model.train

Gera:
  model/artifacts/fake_news.joblib  -> Pipeline treinado + metadados
  model/metrics.json                -> métricas no conjunto de teste (versionado)

Lembrete: o modelo aprende PADRÕES DE ESCRITA do corpus. Ele não verifica fatos.
"""

import json
from datetime import datetime, timezone
from pathlib import Path

import joblib
import sklearn
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, classification_report, f1_score
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline

from model.download import COMMIT, download

MODEL_VERSION = "1.0.0"
SEED = 42

HERE = Path(__file__).parent
ARTIFACT = HERE / "artifacts" / "fake_news.joblib"
METRICS = HERE / "metrics.json"

# Pastas do corpus -> rótulo que a API devolve
LABELS = {"fake": "falsa", "true": "verdadeira"}


def load_corpus(data_dir: Path) -> tuple[list[str], list[str]]:
    texts, labels = [], []
    for folder, label in LABELS.items():
        for path in sorted((data_dir / folder).glob("*.txt")):
            texts.append(path.read_text(encoding="utf-8"))
            labels.append(label)
    return texts, labels


def build_pipeline() -> Pipeline:
    return Pipeline([
        # Texto -> vetor de pesos por palavra e par de palavras
        ("tfidf", TfidfVectorizer(lowercase=True, ngram_range=(1, 2), min_df=2, sublinear_tf=True)),
        # Vetor -> probabilidade de cada classe
        ("clf", LogisticRegression(max_iter=1000, random_state=SEED)),
    ])


def main() -> None:
    texts, labels = load_corpus(download())
    print(f"{len(texts)} notícias carregadas")

    X_train, X_test, y_train, y_test = train_test_split(
        texts, labels, test_size=0.2, stratify=labels, random_state=SEED
    )

    pipeline = build_pipeline()
    pipeline.fit(X_train, y_train)  # o famoso model.fit()

    y_pred = pipeline.predict(X_test)
    metrics = {
        "accuracy": round(accuracy_score(y_test, y_pred), 4),
        "f1_macro": round(f1_score(y_test, y_pred, average="macro"), 4),
        "n_train": len(X_train),
        "n_test": len(X_test),
    }
    print(classification_report(y_test, y_pred, digits=3))

    metadata = {
        "model_version": MODEL_VERSION,
        "classes": list(pipeline.classes_),  # ordem das colunas de predict_proba
        "sklearn_version": sklearn.__version__,
        "metrics": metrics,
        "corpus": f"Fake.br Corpus (size_normalized_texts) @ {COMMIT[:7]}",
        "trained_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }

    ARTIFACT.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump({"pipeline": pipeline, "metadata": metadata}, ARTIFACT)
    METRICS.write_text(json.dumps(metadata, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Modelo salvo em {ARTIFACT}")
    print(json.dumps(metrics, indent=2))


if __name__ == "__main__":
    main()
