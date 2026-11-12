"""Baixa o Fake.br Corpus direto da fonte (não redistribuímos os dados).

Fonte: https://github.com/roneysco/Fake.br-Corpus (NILC/USP).
Fixamos um commit para o treino ser reproduzível.
Usamos só `size_normalized_texts/`: em cada par falsa/verdadeira, o texto
maior é cortado para o tamanho do menor, então o tamanho não vira "pista".
"""

import io
import urllib.request
import zipfile
from pathlib import Path

COMMIT = "780f5516c4ae070761632d98ac3368f3ded09d35"
URL = f"https://codeload.github.com/roneysco/Fake.br-Corpus/zip/{COMMIT}"
SUBDIR = "size_normalized_texts/"

DATA_DIR = Path(__file__).parent / "data" / "fakebr"


def download(dest: Path = DATA_DIR) -> Path:
    if (dest / "fake").is_dir() and (dest / "true").is_dir():
        print(f"Corpus já está em {dest}")
        return dest

    print(f"Baixando {URL} ...")
    with urllib.request.urlopen(URL, timeout=120) as resp:
        archive = zipfile.ZipFile(io.BytesIO(resp.read()))

    # Dentro do zip os caminhos são "Fake.br-Corpus-<commit>/size_normalized_texts/fake/1.txt"
    for name in archive.namelist():
        _, _, rel = name.partition("/")
        if rel.startswith(SUBDIR) and rel.endswith(".txt"):
            target = dest / rel.removeprefix(SUBDIR)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(archive.read(name))

    print(f"Corpus salvo em {dest}")
    return dest


if __name__ == "__main__":
    download()
