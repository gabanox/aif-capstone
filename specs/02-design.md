# Diseño — HR Assistant

## 1. Arquitectura

El usuario interactúa con un script Python que corre en línea de comandos. Cada mensaje del
usuario se agrega al historial de conversación (lista de dicts `role`/`content`) y se envía
completo a Amazon Bedrock vía Converse API. La respuesta del modelo se agrega también al
historial antes del siguiente turno.

No hay servidor intermedio, base de datos ni almacenamiento externo. El único servicio AWS
consumido en tiempo de ejecución es `bedrock-runtime`.

### Diagrama

```
┌──────────────────────────────────────────────────────────┐
│                     GitHub Codespace                     │
│                                                          │
│  ┌─────────────┐    boto3 Converse API    ┌───────────┐ │
│  │  hr_assistant│ ─────────────────────►  │  Amazon   │ │
│  │   .py (CLI)  │ ◄─────────────────────  │  Bedrock  │ │
│  └─────────────┘    JSON response         │  Runtime  │ │
│         │                                 │(us-east-1)│ │
│         │  env var                        └───────────┘ │
│  AWS_BEARER_TOKEN_BEDROCK                        │       │
│                                          us.anthropic.   │
│                                          claude-sonnet-  │
│                                          4-6             │
└──────────────────────────────────────────────────────────┘
```

Fuente: arquitectura derivada de la [documentación oficial de Converse API](https://docs.aws.amazon.com/bedrock/latest/userguide/getting-started-api-ex-python.html).

---

## 2. Modelo de Amazon Bedrock

- **Modelo primario:** `us.anthropic.claude-sonnet-4-6`
- **Modelo de respaldo:** `us.anthropic.claude-haiku-4-5-20251001-v1:0`
- **API:** Converse API (`bedrock-runtime.converse`)
- **Justificación:** Claude Sonnet 4.6 ofrece la mejor relación calidad/costo para conversación en español sobre un dominio acotado. Haiku 4.5 como respaldo garantiza disponibilidad si Sonnet no está habilitado en la cuenta compartida. Ambos son modelos de la familia Anthropic disponibles vía cross-region inference profile con prefijo `us.`.
- **Parámetros de inferencia:**
  - `maxTokens=1024` — respuestas concisas, acota costo (ref: RNF-6)
  - `temperature=0.3` — respuestas consistentes y poco creativas; adecuado para FAQ corporativo

---

## 3. Prompt engineering (dominio 3)

- **Estrategia:** Zero-shot con system prompt rico. No se usa RAG porque las políticas son estáticas y caben en el contexto del modelo.

- **System prompt:**

```
Eres el asistente virtual de Recursos Humanos de la empresa. Respondes preguntas de los
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
--- FIN DE POLÍTICAS ---
```

---

## 4. Flujo de datos

| Paso | Entrada | Proceso | Salida |
|------|---------|---------|--------|
| 0 | Inicio del script | Verificar `AWS_BEARER_TOKEN_BEDROCK`; mostrar disclaimer | CLI lista para recibir input |
| 1 | Texto del usuario | Agregar `{role: "user", content: [{text: input}]}` al historial | Historial actualizado |
| 2 | Historial + system prompt | Llamar `bedrock_runtime.converse(modelId, messages, system, inferenceConfig)` | `response["output"]["message"]` |
| 3 | Respuesta del modelo | Extraer `content[0]["text"]`; agregar al historial como `role: "assistant"` | Texto impreso en consola |
| 4 | Usuario escribe `salir`/`exit` | Romper el loop | Proceso termina con código 0 |

---

## 5. Manejo de errores

| Escenario | Respuesta del sistema |
|-----------|----------------------|
| `AWS_BEARER_TOKEN_BEDROCK` no definida | Imprime error explicativo y sale con código 1 antes de crear el cliente |
| Modelo primario no disponible (`ValidationException`, `ResourceNotFoundException`) | Intenta con modelo de respaldo; informa al usuario "Usando modelo alternativo: haiku-4-5" (ref: RF-5) |
| Throttling (`ThrottlingException`) | Reintenta hasta 3 veces con backoff exponencial (1s, 2s, 4s); si persiste, imprime mensaje y continúa al siguiente turno |
| `ClientError` genérico | Imprime el código de error y el mensaje de AWS; el CLI no termina (el usuario puede seguir) |
| Entrada vacía del usuario | Ignorar (no invocar Bedrock); imprimir "Por favor escribe una pregunta." |

---

## 6. IA Responsable (dominio 4)

- **Riesgos identificados:**
  1. **Alucinaciones:** el modelo podría inventar políticas si la pregunta es ambigua.
  2. **Sesgo de tono:** respuestas sobre temas sensibles (despidos, discriminación) podrían ser percibidas como parciales.
  3. **PII en conversación:** el usuario podría incluir datos personales (número de empleado, salario) en su pregunta.

- **Mitigaciones de diseño:**
  1. System prompt incluye instrucción explícita de no inventar información (regla 4 del system prompt).
  2. System prompt delimita el dominio y fuerza una respuesta de derivación para preguntas fuera de scope (regla 2).
  3. El historial de conversación se mantiene solo en memoria RAM; no se persiste en disco ni logs.
  4. Disclaimer visible al inicio de cada sesión: *"Este asistente es orientativo. Para decisiones formales, consulta directamente con el equipo de RRHH."*

---

## 7. Seguridad (dominio 5)

- **IAM:** el token `AWS_BEARER_TOKEN_BEDROCK` otorga acceso con permisos acotados a `bedrock:InvokeModel` sobre los modelos claude-sonnet-4-6 y claude-haiku-4-5. No se necesitan permisos adicionales (sin S3, sin DynamoDB, sin Lambda).
- **Secretos:** el token se lee únicamente de `os.environ["AWS_BEARER_TOKEN_BEDROCK"]`; el script aborta si no está presente. Ninguna credencial en código ni en git.
- **Datos:** el historial de conversación vive solo en memoria de proceso. Al terminar el script, desaparece. No hay retención ni transmisión a terceros.
- **Verificación pre-commit:** antes de cada `git commit` se revisa el diff buscando patrones de secretos (`ABSK`, `aws_secret_access_key`, `aws_access_key_id`).

---

## 8. Costo — gate de FinOps

Precios de referencia para Claude Sonnet 4.6 vía Amazon Bedrock cross-region inference (us-east-1),
según [documentación de precios de Amazon Bedrock](https://aws.amazon.com/bedrock/pricing/):

### Estimación inicial (fase Plan)

| Componente | Supuesto de volumen | Precio unitario | Costo estimado |
|------------|---------------------|-----------------|----------------|
| Input tokens (Sonnet 4.6) | 50 turnos × 800 tokens sistema+historial | ~$3.00 / 1M tokens | ~$0.00012 |
| Output tokens (Sonnet 4.6) | 50 turnos × 300 tokens respuesta | ~$15.00 / 1M tokens | ~$0.00023 |
| **Total estimado (desarrollo + demo)** | 50 turnos totales | | **< $0.01 USD** |

### Medición real (fase D2 — 2026-07-22)

Sesión representativa de 8 turnos medida con `response["usage"]` de la Converse API:

| Turno | Input tokens | Output tokens | Observación |
|-------|-------------|---------------|-------------|
| 1 | 524 | 129 | Primera pregunta (sin historial previo) |
| 2 | 680 | 174 | Follow-up contextualizado (historial acumula) |
| 3 | 872 | 146 | — |
| 4 | 1 041 | 184 | — |
| 5 | 1 246 | 101 | — |
| 6 | 1 367 | 150 | — |
| 7 | 1 532 | 39 | Pregunta off-topic → respuesta corta de derivación |
| 8 | 1 588 | 104 | — |
| **Total** | **8 850** | **1 027** | |

| Componente | Tokens reales | Precio unitario | Costo real |
|------------|---------------|-----------------|------------|
| Input tokens | 8 850 | $3.00 / 1M | $0.000027 |
| Output tokens | 1 027 | $15.00 / 1M | $0.000015 |
| **Total sesión de 8 turnos** | | | **$0.000042 USD** |

**Costo por turno promedio:** ~$0.0000053 USD  
**Extrapolando a 50 turnos:** ~$0.000264 USD — dentro del presupuesto estimado de < $0.01 USD.

> Nota: el input crece con cada turno porque se envía el historial completo. En sesiones muy
> largas (> 100 turnos) conviene implementar truncación del historial antiguo. Para el MVP
> de demo esto no aplica.

> `maxTokens=1024` (RNF-6) limita la salida por turno y es el principal control de costo.

---

## 9. Decisiones de diseño (rastreables)

| Decisión | Requisito que satisface | Alternativa descartada y por qué |
|----------|-------------------------|----------------------------------|
| Prompt engineering sin RAG | RF-3, brief §4 | Knowledge Bases: complejidad innecesaria cuando las políticas caben en el contexto; agrega costo de vectorización y latencia |
| Historial completo en cada llamada | RF-2 | Session state en DynamoDB: sobrecarga de infraestructura no justificada para un MVP CLI |
| CLI Python (`input()` loop) | RF-1, RF-4 | Streamlit/Flask: out of scope para el MVP; dificulta el flujo de prueba |
| `maxTokens=1024` | RNF-6 | Sin límite: riesgo de respuestas largas y costo impredecible |
| `temperature=0.3` | RF-1, RF-3 | `temperature=0.7`: mayor creatividad no deseada en respuestas de policy FAQ |
| Modelo de respaldo haiku-4-5 | RF-5 | Sin fallback: la cuenta compartida puede tener modelos deshabilitados |
