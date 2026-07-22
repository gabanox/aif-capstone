# Capstone AIF-C01 — Brief del proyecto

## 1. Identificación

- **Alumno:** tcdazaparra
- **Cohorte:** Bootcamp Institute — AIF-C01
- **Fecha:** 2026-07-22
- **Título del proyecto:** HR Assistant — Asistente de RRHH con IA Generativa

## 2. El problema

Los empleados de una empresa pierden tiempo buscando respuestas a preguntas frecuentes sobre
políticas internas (vacaciones, beneficios, onboarding, procedimientos de RRHH). El equipo
de Recursos Humanos dedica esfuerzo repetitivo a responder las mismas consultas, lo que reduce
su disponibilidad para tareas estratégicas.

## 3. La solución propuesta

Un asistente conversacional de línea de comandos (CLI) que responde preguntas de empleados
sobre políticas y procedimientos de RRHH, usando prompts estructurados sobre Amazon Bedrock
(Converse API + Claude Sonnet 4.6).

## 4. Por qué IA Generativa (dominio 1 y 2)

Un FAQ estático requiere mantenimiento constante y no puede responder variaciones de lenguaje
natural. Un modelo de reglas tampoco gestiona preguntas ambiguas o combinadas. Un foundation
model como Claude puede:
- Comprender la intención del usuario aunque la pregunta sea imprecisa.
- Generar respuestas coherentes y en tono corporativo dado un system prompt.
- Mantener contexto de conversación multi-turno sin estado explícito en el servidor.

No se requiere RAG (Knowledge Bases) en el MVP: las políticas se inyectan directamente en el
system prompt, lo que simplifica el alcance y evita costos adicionales de vectorización.

## 5. Alcance

**Incluye (MVP):**
- CLI interactiva multi-turno: el usuario hace preguntas en lenguaje natural y el asistente responde.
- System prompt configurable con las políticas de RRHH (texto plano incluido en el código).
- Manejo de errores claro: modelo no disponible, throttling, credenciales ausentes.
- Historial de conversación en memoria (dentro de la sesión) para preguntas de seguimiento.

**No incluye (fuera de alcance):**
- Interface web o API REST (se puede extender en una fase posterior).
- RAG / Knowledge Bases (las políticas son estáticas y caben en el system prompt).
- Persistencia de historial entre sesiones.
- Integración con sistemas de RRHH reales (Workday, BambooHR, etc.).

## 6. Servicios AWS previstos

| Servicio | Para qué |
|---|---|
| Amazon Bedrock (modelo `us.anthropic.claude-sonnet-4-6`) | Inferencia conversacional vía Converse API |
| AWS IAM | Rol con permisos mínimos: solo `bedrock:InvokeModel` |

> Modelo de respaldo si claude-sonnet-4-6 no está disponible: `us.anthropic.claude-haiku-4-5-20251001`

## 7. Consideraciones de IA Responsable (dominio 4)

- **Riesgos:**
  - Alucinaciones: el modelo puede inventar políticas inexistentes si la pregunta sale del scope del system prompt.
  - Sesgo de respuesta: puede reflejar un tono o perspectiva no neutral sobre temas sensibles (despidos, discriminación).
  - Datos sensibles: el usuario podría compartir información personal en el chat (número de empleado, salario).

- **Mitigaciones:**
  - System prompt con instrucción explícita: "Solo responde con la información provista. Si no tienes la información, di que no la tienes y sugiere contactar a RRHH directamente."
  - Disclaimer en el inicio del CLI: "Este asistente es orientativo. Para decisiones formales consulta a tu área de RRHH."
  - No almacenar el historial de conversación en logs (evitar persistencia de datos personales).

## 8. Seguridad y costo (dominio 5)

- **Seguridad:**
  - El token de Bedrock se lee exclusivamente de la variable de entorno `AWS_BEARER_TOKEN_BEDROCK`.
  - IAM de mínimo privilegio: solo `bedrock:InvokeModel` sobre el modelo específico.
  - Sin secretos en código ni en commits (verificado antes de cada commit con `/epcc-commit`).

- **Costo estimado:**
  - Claude Sonnet 4.6 vía cross-region inference (us-east-1): ~$3/M tokens de entrada, ~$15/M tokens de salida.
  - Uso esperado en demo/desarrollo: ~50 turnos de conversación × ~500 tokens/turno ≈ 25k tokens totales.
  - Costo estimado total del desarrollo: **< $1 USD**.
  - Referencia: [AWS Pricing MCP confirmará antes del despliegue].

---

## Rúbrica de evaluación

| Criterio | Peso | Qué se evalúa |
|---|---:|---|
| Specs completas y claras | 20% | requirements + design + tasks bien escritos (EARS, diseño justificado) |
| Funcionalidad | 25% | la solución invoca Bedrock y resuelve el problema |
| Cobertura AIF-C01 | 20% | evidencia de los 5 dominios |
| IA responsable | 15% | riesgos identificados y mitigados |
| Seguridad y costo | 10% | IAM mínimo, sin secretos, costo estimado |
| Proceso (EPCC) | 10% | historial de commits limpio que evidencia el flujo |

> **Para aprobar:** specs aprobadas + demo funcional + repo con los entregables del README.
