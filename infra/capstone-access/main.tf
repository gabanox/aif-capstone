# =============================================================================
# Capstone Student AWS Access — rol scoped (Opción A) en la cuenta
# plataforma-instructores (654654327431).
#
# Decisiones del owner (2026-06-10):
#   - Opción A: namespace acotado (recursos/roles `capstone-*`), cuenta compartida.
#   - 100% serverless: Lambda, API Gateway, Step Functions, S3, DynamoDB, SQS/SNS,
#     CloudFront, CloudFormation. NADA de EC2/SageMaker/instancias (Deny explícito).
#   - IA: solo modelos PRETRAINED de Bedrock (invoke/converse). NADA de training,
#     customization, provisioned throughput, ni SageMaker.
#   - Sesión de credenciales del alumno: 3 horas (MaxSessionDuration = 10800s).
#
# Aplica en la cuenta 654654327431 (perfil con permisos de IAM en esa cuenta):
#   cd infra/capstone-access
#   terraform init && terraform apply
#
# El rol lo asume el EMISOR de credenciales (ver var.issuer_principal_arns):
# típicamente el Lambda/identidad del Hub que entrega creds temporales al alumno
# (mismo patrón que bootcamp-lms lab-aws-console-get). RoleSessionName codifica
# al alumno → CloudTrail audita quién desplegó qué.
# =============================================================================

terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}

provider "aws" {
  region = "us-east-1"
  # profile = "plataforma-instructores"  # descomenta si usas perfil nombrado
}

variable "issuer_principal_arns" {
  description = "Principals autorizados a asumir el rol y emitir creds al alumno (Lambda issuer del Hub, o tu user de instructor para pruebas)."
  type        = list(string)
  # Ejemplo: el role del Lambda emisor en la cuenta de plataforma (281248178297) o un user de instructor.
  default = []
}

data "aws_caller_identity" "current" {}

locals {
  # Si no se pasa un issuer explícito, permite a la propia cuenta (root) — restríngelo en prod.
  trusted = length(var.issuer_principal_arns) > 0 ? var.issuer_principal_arns : ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
}

resource "aws_iam_role" "capstone_student" {
  name                 = "capstone-student"
  description          = "Acceso serverless+Bedrock acotado para alumnos del capstone AIF-C01. Sesión máx 3h."
  max_session_duration = 10800 # 3 horas

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = local.trusted }
      Action    = "sts:AssumeRole"
      Condition = {
        StringLike = { "sts:RoleSessionName" = "capstone-*" }
      }
    }]
  })

  tags = {
    Project = "aif-capstone"
    Purpose = "student-serverless-access"
    Managed = "terraform"
  }
}

resource "aws_iam_role_policy" "capstone_student" {
  name   = "capstone-student-serverless-bedrock"
  role   = aws_iam_role.capstone_student.id
  policy = file("${path.module}/capstone-student-policy.json")
}

# ── Guardrail FinOps: presupuesto + alarma para la cuenta compartida (gate del repo) ──
resource "aws_budgets_budget" "capstone_monthly" {
  name         = "capstone-students-monthly"
  budget_type  = "COST"
  limit_amount = "200"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["gabriel@bootcamp.institute"]
  }
}

output "capstone_student_role_arn" {
  value       = aws_iam_role.capstone_student.arn
  description = "Pásalo al emisor de credenciales / al credential_process del devcontainer."
}
