# HR Assistant — Asistente de RRHH con IA Generativa

Asistente conversacional de línea de comandos que responde preguntas de empleados sobre
políticas internas de Recursos Humanos, usando **Amazon Bedrock** (Converse API) con
**Claude Sonnet 4.6**.

---

## Qué hace

- Responde preguntas sobre vacaciones, beneficios, onboarding, licencias y código de conducta.
- Mantiene el contexto de la conversación dentro de la sesión (multi-turno).
- Ante preguntas fuera del dominio RRHH, deriva al equipo de Recursos Humanos.
- Hace fallback automático a Claude Haiku 4.5 si Sonnet 4.6 no está disponible.
- Reintenta con backoff exponencial ante throttling de la API.

## Requisitos

- Python 3.10+
- `uv` (gestor de paquetes, preinstalado en el Codespace)
- Token de Amazon Bedrock (`AWS_BEARER_TOKEN_BEDROCK`) — lo entrega tu facilitador

## Instalación

```bash
# Desde la raíz del repositorio
uv pip install -r requirements.txt --system
```

Verificar conectividad con Bedrock:

```bash
python src/check_bedrock.py
# Salida esperada: Bedrock OK — modelo: us.anthropic.claude-sonnet-4-6
```

## Variables de entorno requeridas

| Variable | Descripción |
|----------|-------------|
| `AWS_BEARER_TOKEN_BEDROCK` | Token de acceso a Amazon Bedrock (empieza con `ABSK...`). **Nunca** lo pongas en el código. |

Configúrala antes de ejecutar:

```bash
export AWS_BEARER_TOKEN_BEDROCK=<tu-token>
```

En GitHub Codespaces se configura como **Codespaces Secret** — ver `docs/CODESPACES-BEDROCK.md`.

## Ejecución

```bash
python src/hr_assistant.py
```

Ejemplo de sesión:

```
============================================================
Asistente de Recursos Humanos — HR Assistant
Este asistente es orientativo. Para decisiones formales,
consulta directamente con el equipo de RRHH.
Escribe 'salir' o 'exit' para terminar.
============================================================

Tú: ¿Cuántos días de vacaciones tengo?

Asistente: Tienes derecho a 15 días hábiles de vacaciones al año, que se acumulan
a razón de 1.25 días por mes trabajado...

Tú: ¿Y si llevo 3 años en la empresa?

Asistente: Con 3 años (36 meses), habrías acumulado 45 días hábiles (36 × 1.25)...

Tú: salir
Hasta luego.
```

## Arquitectura

```
CLI (src/hr_assistant.py)
    │
    │  boto3 Converse API
    ▼
Amazon Bedrock Runtime (us-east-1)
    └── us.anthropic.claude-sonnet-4-6   (primario)
    └── us.anthropic.claude-haiku-4-5    (respaldo)
```

- Sin base de datos, sin Lambda, sin API Gateway.
- Historial en memoria RAM; desaparece al terminar el proceso.
- System prompt con políticas de RRHH inyectado en cada llamada.

## Estructura del proyecto

```
specs/
  00-capstone-brief.md   — idea y caso de uso
  01-requirements.md     — requisitos EARS
  02-design.md           — arquitectura + decisiones + costo
  03-tasks.md            — plan de tareas (estado actual)
src/
  hr_assistant.py        — asistente principal (ejecutable)
  check_bedrock.py       — verificador de conectividad
requirements.txt         — dependencias Python
```

## Cobertura AIF-C01

| Dominio | Evidencia |
|---------|-----------|
| 1 — Fundamentos IA/ML | Justificación de FM vs. FAQ estático en `specs/00-capstone-brief.md` §4 |
| 2 — IA Generativa | Bedrock Converse API con Claude Sonnet 4.6 |
| 3 — Foundation Models | Prompt engineering zero-shot, historial multi-turno |
| 4 — IA Responsable | System prompt con guardrails, disclaimer de sesión, no persistencia de datos |
| 5 — Seguridad y Gobernanza | IAM mínimo privilegio, token en env vars, costo medido $0.000042/sesión |
