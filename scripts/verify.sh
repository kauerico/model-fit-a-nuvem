#!/usr/bin/env bash
# Confere a API pelo IP público: /health e uma previsão.
#   scripts/verify.sh http://IP:30080
set -euo pipefail
URL=${1:?uso: $0 <api_url>}

for _ in $(seq 24); do
  if curl -sf "$URL/health"; then
    echo
    curl -sf "$URL/predict" -H 'Content-Type: application/json' \
      -d '{"texto": "Teste automático do pipeline de CI/CD."}'
    echo
    exit 0
  fi
  sleep 5
done
echo "API não respondeu em $URL" >&2
exit 1
