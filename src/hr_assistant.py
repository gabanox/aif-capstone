# HR Assistant — Asistente conversacional de RRHH sobre Amazon Bedrock

import boto3
from botocore.exceptions import ClientError

MODEL_PRIMARY = "us.anthropic.claude-sonnet-4-6"
MODEL_FALLBACK = "us.anthropic.claude-haiku-4-5-20251001-v1:0"

MAX_TOKENS = 1024
TEMPERATURE = 0.3

SYSTEM_PROMPT = """Eres el asistente virtual de Recursos Humanos de la empresa. Respondes preguntas de los
empleados sobre políticas internas: vacaciones, beneficios, onboarding, licencias, código
de conducta y procedimientos internos.

Reglas:
1. Responde SOLO con información de las políticas proporcionadas a continuación.
2. Si la pregunta no está relacionada con RRHH, responde exactamente:
   "No tengo información sobre eso. Para dudas adicionales, contacta directamente al equipo
   de Recursos Humanos en rrhh@empresa.com."
3. Sé claro, cordial y conciso. Máximo 3 párrafos por respuesta.
4. No inventes políticas ni datos que no estén en la lista de abajo.

--- POLÍTICAS DE LA EMPRESA ---
[Vacaciones] Los empleados tienen derecho a 15 días hábiles de vacaciones al año, que se
acumulan a razón de 1.25 días por mes trabajado. Se deben solicitar con al menos 5 días de
anticipación a través del sistema interno.

[Beneficios] La empresa ofrece: seguro médico (empleado y familia directa), bono de
transporte mensual de $50, y acceso a plataforma de capacitación online.

[Onboarding] Los nuevos empleados completan un proceso de inducción de 5 días que incluye:
presentación con el equipo, configuración de herramientas, lectura del código de conducta y
reunión con RRHH.

[Licencias] Licencia por maternidad/paternidad: 12 semanas para madres, 2 semanas para
padres. Licencia por enfermedad: ilimitada con certificado médico.

[Código de conducta] Todo empleado debe mantener un trato respetuoso. El incumplimiento se
reporta al correo etica@empresa.com y puede derivar en proceso disciplinario.
--- FIN DE POLÍTICAS ---"""

# Cliente Bedrock compartido por la sesión (se crea una sola vez en main)
_client = None


def invoke_bedrock(messages: list) -> str:
    """Invoca la Converse API con el historial completo.

    Intenta MODEL_PRIMARY; si no está disponible, reintenta con MODEL_FALLBACK.
    Retorna el texto de respuesta del modelo.
    Propaga ClientError para que el caller lo maneje (throttling, errores genéricos).
    """
    system = [{"text": SYSTEM_PROMPT}]
    inference_cfg = {"maxTokens": MAX_TOKENS, "temperature": TEMPERATURE}

    for attempt, model_id in enumerate((MODEL_PRIMARY, MODEL_FALLBACK)):
        try:
            response = _client.converse(
                modelId=model_id,
                messages=messages,
                system=system,
                inferenceConfig=inference_cfg,
            )
            if attempt > 0:
                print(f"[Aviso] Usando modelo alternativo: {model_id}")
            return response["output"]["message"]["content"][0]["text"]

        except ClientError as e:
            code = e.response["Error"]["Code"]
            # Solo hace fallback si el modelo no está disponible en la cuenta
            if code in ("ValidationException", "ResourceNotFoundException") and attempt == 0:
                continue
            raise


DISCLAIMER = (
    "=" * 60 + "\n"
    "Asistente de Recursos Humanos — HR Assistant\n"
    "Este asistente es orientativo. Para decisiones formales,\n"
    "consulta directamente con el equipo de RRHH.\n"
    "Escribe 'salir' o 'exit' para terminar.\n"
    + "=" * 60
)


def main():
    import os
    import sys

    # Verificar credencial antes de crear el cliente (manejo completo en B3)
    if not os.environ.get("AWS_BEARER_TOKEN_BEDROCK"):
        print("Error: falta la variable de entorno AWS_BEARER_TOKEN_BEDROCK", file=sys.stderr)
        sys.exit(1)

    global _client
    _client = boto3.client("bedrock-runtime", region_name="us-east-1")

    print(DISCLAIMER)

    history = []  # historial de la sesión: lista de {role, content}

    while True:
        try:
            user_input = input("\nTú: ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nHasta luego.")
            sys.exit(0)

        if user_input.lower() in ("salir", "exit"):
            print("Hasta luego.")
            sys.exit(0)

        if not user_input:
            print("Por favor escribe una pregunta.")
            continue

        history.append({"role": "user", "content": [{"text": user_input}]})

        try:
            answer = invoke_bedrock(history)
        except ClientError as e:
            code = e.response["Error"]["Code"]
            msg = e.response["Error"]["Message"]
            print(f"[Error Bedrock] {code}: {msg}")
            # Revertir el mensaje del usuario para no contaminar el historial
            history.pop()
            continue

        history.append({"role": "assistant", "content": [{"text": answer}]})
        print(f"\nAsistente: {answer}")


if __name__ == "__main__":
    main()
