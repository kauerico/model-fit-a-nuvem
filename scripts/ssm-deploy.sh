#!/usr/bin/env bash
# Implanta (ou desfaz) o chart Helm na EC2 via AWS SSM, sem SSH e sem expor
# a porta 6443. Usado igualmente pelo `make` e pelo GitHub Actions.
#
#   scripts/ssm-deploy.sh deploy <tag-da-imagem>
#   scripts/ssm-deploy.sh rollback
#
# Precisa de: INSTANCE_ID e AWS_REGION (e credenciais AWS válidas).
set -euo pipefail

ACTION=${1:?uso: $0 deploy <tag> | rollback}
TAG=${2:-}
: "${INSTANCE_ID:?defina INSTANCE_ID}" "${AWS_REGION:?defina AWS_REGION}"
cd "$(dirname "$0")/.."

PRE='set -euo pipefail; export KUBECONFIG=/etc/rancher/k3s/k3s.yaml'
POS='kubectl get pods -l app.kubernetes.io/name=fake-news -o wide'

case "$ACTION" in
  deploy)
    : "${TAG:?informe a tag da imagem}"
    # O chart viaja dentro do próprio comando (tar + base64, poucos KB)
    CHART=$(tar czf - -C helm fake-news | base64 -w0)
    SCRIPT="$PRE
rm -rf /tmp/chart && mkdir -p /tmp/chart
echo '$CHART' | base64 -d | tar xz -C /tmp/chart
helm upgrade --install fake-news /tmp/chart/fake-news \\
  -f /tmp/chart/fake-news/values-aws.yaml --set image.tag=$TAG \\
  --wait --timeout 5m
$POS" ;;
  rollback)
    SCRIPT="$PRE
helm rollback fake-news --wait --timeout 5m
helm history fake-news --max 3
$POS" ;;
  *) echo "ação desconhecida: $ACTION" >&2; exit 2 ;;
esac

PARAMS=$(python3 -c 'import json,sys; print(json.dumps({"commands": [sys.argv[1]]}))' "$SCRIPT")
CMD_ID=$(aws ssm send-command --region "$AWS_REGION" --instance-ids "$INSTANCE_ID" \
  --document-name AWS-RunShellScript --comment "fake-news $ACTION $TAG" \
  --parameters "$PARAMS" --query Command.CommandId --output text)
echo "SSM: comando $CMD_ID enviado ($ACTION $TAG)"

# Espera terminar; o waiter falha se o comando falhar, mas mostramos a saída antes
aws ssm wait command-executed --region "$AWS_REGION" --command-id "$CMD_ID" --instance-id "$INSTANCE_ID" || true
inv() { aws ssm get-command-invocation --region "$AWS_REGION" --command-id "$CMD_ID" \
  --instance-id "$INSTANCE_ID" --query "$1" --output text; }
echo "--- saída na EC2 ---"; inv StandardOutputContent
ERR=$(inv StandardErrorContent); [ -n "$ERR" ] && printf -- '--- stderr ---\n%s\n' "$ERR"
STATUS=$(inv Status); echo "status: $STATUS"
[ "$STATUS" = "Success" ]
