#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# aws-credential-process.sh — emite credenciales TEMPORALES (3h) scoped al rol
# `capstone-student` y las imprime en el formato que el AWS CLI/SDK esperan de un
# `credential_process`. Así `aws s3 ls`, los SDK y los MCP servers de AWS obtienen
# credenciales automáticamente (y se refrescan al expirar) — sin copy-paste.
#
# Cómo se conecta (configurado por .devcontainer/post-create.sh en ~/.aws/config):
#   [profile capstone]
#   credential_process = bash /workspaces/<repo>/scripts/aws-credential-process.sh
#   region = us-east-1
#
# Requiere (inyectado como GitHub Codespaces Secret, NO se commitea):
#   CAPSTONE_ROLE_ARN   — ARN del rol capstone-student (output del terraform).
#   Una credencial base para AssumeRole. Soporta dos modos:
#     A) CAPSTONE_AWS_ACCESS_KEY_ID / CAPSTONE_AWS_SECRET_ACCESS_KEY  (key del emisor)
#     B) CAPSTONE_CREDS_ENDPOINT + GITHUB_TOKEN  (endpoint del Hub que entrega STS;
#        recomendado en prod — el alumno nunca toca una key estática)
#
# Identidad: RoleSessionName = capstone-<github_user> → CloudTrail audita quién despliega.
# Duración: 3 horas (10800s) — alineado con la decisión del owner.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

DURATION=10800   # 3h
REGION="${AWS_REGION:-us-east-1}"
USER_TAG="${GITHUB_USER:-$(whoami)}"
SESSION="capstone-$(echo "$USER_TAG" | tr -c 'a-zA-Z0-9-' '-' | cut -c1-50)"

# ── Modo B: endpoint del Hub que ya devuelve STS JSON (preferido) ──────────────
if [[ -n "${CAPSTONE_CREDS_ENDPOINT:-}" ]]; then
  curl -fsS -X POST "$CAPSTONE_CREDS_ENDPOINT" \
    -H "Authorization: Bearer ${GITHUB_TOKEN:-${CODESPACE_TOKEN:-}}" \
    -H "Content-Type: application/json" \
    -d "{\"sessionName\":\"$SESSION\",\"durationSeconds\":$DURATION}"
  exit 0
fi

# ── Modo A: AssumeRole local con la key del emisor (para arranque rápido del lab) ─
: "${CAPSTONE_ROLE_ARN:?Falta CAPSTONE_ROLE_ARN (Codespaces Secret)}"
export AWS_ACCESS_KEY_ID="${CAPSTONE_AWS_ACCESS_KEY_ID:?Falta CAPSTONE_AWS_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${CAPSTONE_AWS_SECRET_ACCESS_KEY:?Falta CAPSTONE_AWS_SECRET_ACCESS_KEY}"
unset AWS_SESSION_TOKEN AWS_PROFILE

aws sts assume-role \
  --role-arn "$CAPSTONE_ROLE_ARN" \
  --role-session-name "$SESSION" \
  --duration-seconds "$DURATION" \
  --region "$REGION" \
  --query 'Credentials' --output json \
| python3 -c 'import sys,json; c=json.load(sys.stdin); print(json.dumps({"Version":1,"AccessKeyId":c["AccessKeyId"],"SecretAccessKey":c["SecretAccessKey"],"SessionToken":c["SessionToken"],"Expiration":c["Expiration"]}))'
