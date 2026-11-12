#!/usr/bin/env bash
# Fala com a EC2 da demo via AWS SSM: sem SSH e sem expor a porta 6443.
# Usado igualmente pelo `make` e pelo GitHub Actions.
#
#   scripts/ssm-deploy.sh info              # imprime instance_id e api_url
#   scripts/ssm-deploy.sh wait              # espera o k3s ficar pronto
#   scripts/ssm-deploy.sh deploy <tag>      # helm upgrade com a imagem <tag>
#   scripts/ssm-deploy.sh rollback          # volta para a versão anterior
#   scripts/ssm-deploy.sh status            # kubectl get nodes,pods,svc na EC2
#
# Precisa de AWS_REGION e credenciais AWS. A instância é encontrada pela tag
# Name=fake-news-k3s (criada pelo Terraform).
set -euo pipefail

ACTION=${1:?uso: $0 info | wait | deploy <tag> | rollback | status}
TAG=${2:-}
: "${AWS_REGION:?defina AWS_REGION}"
cd "$(dirname "$0")/.."

read -r INSTANCE_ID PUBLIC_IP < <(aws ec2 describe-instances --region "$AWS_REGION" \
  --filters Name=tag:Name,Values=fake-news-k3s Name=instance-state-name,Values=pending,running \
  --query 'Reservations[0].Instances[0].[InstanceId,PublicIpAddress]' --output text)
if [ "$INSTANCE_ID" = "None" ]; then
  echo "Nenhuma EC2 da demo ligada (suba a infra com terraform apply, ver PROCEDIMENTO.md)." >&2
  exit 3
fi

if [ "$ACTION" = info ]; then
  echo "instance_id=$INSTANCE_ID"
  echo "api_url=http://$PUBLIC_IP:30080"
  exit 0
fi

# O SSM executa com /bin/sh (no Ubuntu é o dash): nada de recursos só do bash
PRE='set -eu; export KUBECONFIG=/etc/rancher/k3s/k3s.yaml'
POS='kubectl get pods -l app.kubernetes.io/name=fake-news -o wide'

case "$ACTION" in
  wait)
    # 1) o agente do SSM da EC2 precisa estar "Online" para receber comandos
    echo "Esperando o agente do SSM em $INSTANCE_ID ..."
    for _ in $(seq 60); do
      PING=$(aws ssm describe-instance-information --region "$AWS_REGION" \
        --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
        --query 'InstanceInformationList[0].PingStatus' --output text)
      [ "$PING" = Online ] && break
      sleep 10
    done
    [ "$PING" = Online ] || { echo "SSM não ficou Online" >&2; exit 1; }
    # 2) o user_data (instalação do k3s e do Helm) precisa ter terminado
    SCRIPT="cloud-init status --wait || true
k3s kubectl get nodes -o wide
helm version --short" ;;
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
if [ \$(helm history fake-news --max 2 -o yaml 2>/dev/null | grep -c 'revision:') -lt 2 ]; then
  echo 'Não há versão anterior para voltar (primeiro deploy).'; exit 0
fi
helm rollback fake-news --wait --timeout 5m
helm history fake-news --max 3
$POS" ;;
  status)
    SCRIPT="$PRE
kubectl get nodes,pods,svc -o wide
helm list" ;;
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
