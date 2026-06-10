#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# post-create.sh — se ejecuta UNA vez al crear el Codespace.
# Instala Claude Code, uv (runtime de los MCP servers de AWS) y dependencias.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

echo "▶ [1/4] Instalando Claude Code…"
npm install -g @anthropic-ai/claude-code

echo "▶ [2/4] Instalando uv (gestor que ejecuta los MCP servers de AWS)…"
curl -LsSf https://astral.sh/uv/install.sh | sh
# Asegura que uv quede en el PATH de futuras shells
if ! grep -q 'astral.sh\|/.local/bin' "$HOME/.bashrc" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
fi
export PATH="$HOME/.local/bin:$PATH"

echo "▶ [3/4] Instalando dependencias del sistema (graphviz para diagramas de arquitectura)…"
sudo apt-get update -y >/dev/null 2>&1 && sudo apt-get install -y graphviz >/dev/null 2>&1 || \
  echo "  (graphviz no se pudo instalar automáticamente; el MCP de diagramas lo pedirá si lo usas)"

echo "▶ [4/5] Pre-descargando los MCP servers de AWS (cachea para el primer arranque)…"
uvx awslabs.aws-documentation-mcp-server@latest --help >/dev/null 2>&1 || true
uvx awslabs.aws-diagram-mcp-server@latest         --help >/dev/null 2>&1 || true

echo "▶ [5/5] Configurando acceso AWS para deploy (credential_process scoped, 3h)…"
# Hace que `aws`, los SDK y los MCP servers de AWS obtengan credenciales TEMPORALES
# (rol capstone-student, sesión 3h) automáticamente. El bearer token de Bedrock NO
# sirve para S3/Lambda/deploy — esto sí. Ver docs/AWS-DEPLOY-ACCESS.md.
REPO_DIR="${CONTAINERWORKSPACEFOLDER:-$(pwd)}"
CRED_SCRIPT="$REPO_DIR/scripts/aws-credential-process.sh"
chmod +x "$CRED_SCRIPT" 2>/dev/null || true
mkdir -p "$HOME/.aws"
if ! grep -q '\[profile capstone\]' "$HOME/.aws/config" 2>/dev/null; then
  cat >> "$HOME/.aws/config" <<CFG

[profile capstone]
credential_process = bash $CRED_SCRIPT
region = us-east-1
CFG
fi
# Default del entorno → perfil capstone (para que `aws s3 ls` funcione sin --profile).
if ! grep -q 'AWS_PROFILE=capstone' "$HOME/.bashrc" 2>/dev/null; then
  echo 'export AWS_PROFILE=capstone' >> "$HOME/.bashrc"
fi

cat <<'EOF'

✅ Entorno listo.

Acceso AWS para DEPLOY (serverless + Bedrock pretrained, sesión de 3h):
  Requiere estos GitHub Codespaces Secrets (ver docs/AWS-DEPLOY-ACCESS.md):
    - CAPSTONE_ROLE_ARN
    - CAPSTONE_AWS_ACCESS_KEY_ID  +  CAPSTONE_AWS_SECRET_ACCESS_KEY   (o CAPSTONE_CREDS_ENDPOINT)
  Verifica:   AWS_PROFILE=capstone aws sts get-caller-identity
              AWS_PROFILE=capstone aws s3 ls

Claude Code sobre Bedrock (asistente IA):
  - Configura el secret AWS_BEARER_TOKEN_BEDROCK.
  - Lanza:  claude    →    /epcc-explore   (ver docs/EPCC-WORKFLOW.md)

EOF
