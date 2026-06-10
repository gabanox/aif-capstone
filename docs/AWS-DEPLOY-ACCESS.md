# Acceso a AWS para desplegar tu capstone

Tu Codespace tiene **dos** vías de AWS, separadas a propósito:

| Para… | Mecanismo | Variable |
|---|---|---|
| **Claude Code sobre Bedrock** (asistente IA) | bearer token de Bedrock | `AWS_BEARER_TOKEN_BEDROCK` |
| **Desplegar** (S3, Lambda, API Gateway, CloudFront, DynamoDB…) y los **MCP servers de AWS** | credenciales temporales SigV4 (rol scoped, 3h) | `CAPSTONE_ROLE_ARN` + key/endpoint |

> ⚠️ El bearer token de Bedrock **solo** sirve para invocar modelos. **No** firma `aws s3 ls`, `aws lambda`, ni ningún deploy. Si solo tienes el bearer token, `aws s3 ls` falla con `Unable to locate credentials` — eso es esperado hasta configurar lo de abajo.

## Qué puedes desplegar (alcance del rol `capstone-student`)
- **100% serverless**: Lambda, API Gateway, Step Functions, EventBridge, S3, DynamoDB, SQS, SNS, CloudFront, CloudFormation.
- **IA**: modelos **pre-entrenados** de Amazon Bedrock (invoke/converse, Knowledge Bases).
- **Prohibido por diseño** (Deny explícito): EC2/instancias, SageMaker, ECS/EKS/EMR, RDS/ElastiCache/Redshift, training/fine-tuning, IAM fuera del prefijo `capstone-*`, billing/Organizations.
- **Región**: `us-east-1`. **Sesión**: 3 horas (luego se renueva sola).
- **Namespace**: trabaja con recursos/roles con prefijo `capstone-` (es cuenta compartida del bootcamp; respeta el prefijo para no chocar con otros alumnos y para que los costos se atribuyan).

## Configura el acceso (una vez)
En GitHub → tu repo → **Settings → Secrets and variables → Codespaces**, agrega:

1. `CAPSTONE_ROLE_ARN` — te lo da tu instructor (output del Terraform `capstone_student_role_arn`).
2. Credencial base — una de las dos:
   - **Arranque rápido**: `CAPSTONE_AWS_ACCESS_KEY_ID` + `CAPSTONE_AWS_SECRET_ACCESS_KEY` (las da el instructor).
   - **Recomendado** (sin key estática): `CAPSTONE_CREDS_ENDPOINT` (endpoint del Hub que entrega las credenciales temporales contra tu identidad de GitHub).

Luego **reinicia el Codespace** (para que `post-create.sh` configure el perfil) o ejecuta:
```bash
bash .devcontainer/post-create.sh
exec bash
```

## Verifica
```bash
AWS_PROFILE=capstone aws sts get-caller-identity   # debe mostrar .../capstone-<tu-usuario>
AWS_PROFILE=capstone aws s3 ls                      # ya NO falla
```
El `post-create.sh` deja `AWS_PROFILE=capstone` por defecto, así que normalmente basta `aws s3 ls`.

## Cómo funciona (para tu spec de Seguridad del capstone)
`credential_process` en `~/.aws/config` llama a `scripts/aws-credential-process.sh`, que hace `sts:AssumeRole` al rol `capstone-student` con `RoleSessionName=capstone-<tu-usuario>`. **CloudTrail registra quién desplegó qué.** Las credenciales son temporales (3h) y se renuevan solas. Nunca hay una key de larga vida en tu shell.
