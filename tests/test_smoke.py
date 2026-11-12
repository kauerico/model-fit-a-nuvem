"""Teste mínimo da fase 0: garante que o pytest roda e o pacote `app` importa."""


def test_app_package_imports():
    import app  # noqa: F401
