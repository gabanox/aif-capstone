# Requisitos — HR Assistant

## Requisitos funcionales

### RF-1 — Respuesta conversacional multi-turno
- **Requisito (EARS):** CUANDO el usuario escribe una pregunta sobre políticas de RRHH en el CLI, el sistema DEBE invocar la Converse API de Amazon Bedrock y mostrar la respuesta en texto plano.
- **Criterio de aceptación:** Dado un prompt de usuario (ej. "¿Cuántos días de vacaciones tengo?"), el CLI imprime una respuesta coherente en menos de 30 segundos sin lanzar excepción.
- **Dominio AIF-C01:** 2, 3

### RF-2 — Historial de conversación en sesión
- **Requisito (EARS):** MIENTRAS la sesión del CLI esté activa, el sistema DEBE mantener el historial de mensajes (user/assistant) y enviarlo en cada llamada a Bedrock para soportar preguntas de seguimiento.
- **Criterio de aceptación:** Una segunda pregunta que referencie la primera ("¿Y si tengo 3 años en la empresa?") obtiene una respuesta contextualizada, no una respuesta genérica sin contexto.
- **Dominio AIF-C01:** 3

### RF-3 — System prompt con políticas de RRHH
- **Requisito (EARS):** El sistema DEBE enviar un system prompt fijo que defina el rol del asistente y las políticas de RRHH en cada invocación de Bedrock.
- **Criterio de aceptación:** El system prompt está definido como constante en el código; una pregunta fuera del dominio RRHH recibe la respuesta "No tengo información sobre eso, consulta directamente con RRHH."
- **Dominio AIF-C01:** 3, 4

### RF-4 — Salida del CLI
- **Requisito (EARS):** CUANDO el usuario escribe `salir` o `exit`, el sistema DEBE terminar el proceso limpiamente con código de salida 0.
- **Criterio de aceptación:** `echo $?` imprime `0` tras escribir `salir` en el CLI.
- **Dominio AIF-C01:** 3

### RF-5 — Fallback a modelo alternativo
- **Requisito (EARS):** SI la invocación a `us.anthropic.claude-sonnet-4-6` retorna un error de modelo no disponible (`ValidationException` o `ResourceNotFoundException`), el sistema DEBE reintentar con `us.anthropic.claude-haiku-4-5-20251001` e informar al usuario del cambio.
- **Criterio de aceptación:** Forzando un `modelId` inválido en la constante primaria, el sistema intenta el modelo secundario y muestra el mensaje "Usando modelo alternativo: haiku-4-5".
- **Dominio AIF-C01:** 2, 3

---

## Requisitos no funcionales

| ID | Categoría | Requisito (EARS) | Criterio de aceptación |
|----|-----------|------------------|------------------------|
| RNF-1 | Rendimiento | CUANDO el usuario envía un mensaje, el sistema DEBE mostrar la primera línea de respuesta en < 30 s en condiciones normales de red | Medición manual en 5 invocaciones consecutivas |
| RNF-2 | IA Responsable | El sistema DEBE mostrar un disclaimer al inicio de cada sesión informando que las respuestas son orientativas | El disclaimer aparece antes del primer prompt de usuario en cada ejecución |
| RNF-3 | IA Responsable | El sistema DEBE instruir al modelo (vía system prompt) a no responder preguntas fuera del dominio RRHH y a derivar a RRHH cuando no tenga información | Preguntas off-topic reciben respuesta de derivación, no alucinaciones |
| RNF-4 | Seguridad | El sistema DEBE leer el token de Bedrock exclusivamente de la variable de entorno `AWS_BEARER_TOKEN_BEDROCK`; si no está presente, DEBE abortar con mensaje claro | Ejecutar sin la variable produce "Error: falta AWS_BEARER_TOKEN_BEDROCK" y código de salida 1 |
| RNF-5 | Seguridad | El repositorio NO DEBE contener credenciales, tokens ni secretos en ningún archivo o commit | `grep -r "ABSK\|aws_secret\|aws_access" .` no produce resultados en archivos rastreados |
| RNF-6 | Costo | El sistema DEBE usar `maxTokens=1024` para acotar el costo por respuesta | Parámetro visible en el código fuente |

---

## Fuera de alcance

- Interface web o API REST.
- RAG / Knowledge Bases de Amazon Bedrock.
- Persistencia de historial entre sesiones.
- Autenticación de usuarios (el CLI asume un entorno seguro).
- Integración con sistemas de RRHH reales (Workday, BambooHR, SAP SuccessFactors).
- Streaming de respuestas (`ConverseStream`).

---

## Trazabilidad
> Cada decisión de `02-design.md` y cada tarea de `03-tasks.md` referencia uno de estos IDs.
