# Plan de tareas — HR Assistant

> Tareas pequeñas, ordenadas y verificables. Cada una se implementa con `/epcc-code` y se
> commitea con `/epcc-commit`. Marca `- [x]` al terminar.

## Fase A — Cimientos

- [x] **A1.** Crear estructura del proyecto: directorio `src/`, archivo `src/hr_assistant.py` vacío y `requirements.txt` con `boto3` · _(ref: setup)_
  - Criterio: `python -c "import boto3"` no lanza error; estructura de archivos presente.

- [x] **A2.** Verificar acceso a Bedrock: script mínimo `src/check_bedrock.py` que llama `converse` con un mensaje de prueba y confirma respuesta · _(ref: RF-1, diseño §2)_
  - Criterio: `python src/check_bedrock.py` imprime la respuesta del modelo sin excepción.

- [x] **A3.** Definir constantes: `MODEL_PRIMARY`, `MODEL_FALLBACK`, `SYSTEM_PROMPT`, `MAX_TOKENS`, `TEMPERATURE` en `src/hr_assistant.py` · _(ref: RF-3, RF-5, RNF-6, diseño §2, §3)_
  - Criterio: constantes presentes en el código; system prompt contiene las cinco secciones de políticas.

## Fase B — Funcionalidad central

- [x] **B1.** Implementar función `invoke_bedrock(messages)` que llama Converse API con el system prompt, historial y manejo de fallback a modelo secundario · _(ref: RF-1, RF-5, diseño §4)_
  - Criterio: la función retorna el texto de respuesta; ante `modelId` inválido, reintenta con haiku y avisa al usuario.

- [x] **B2.** Implementar loop principal del CLI: mostrar disclaimer, leer input, acumular historial, imprimir respuesta; detectar `salir`/`exit` · _(ref: RF-1, RF-2, RF-4, RNF-2, diseño §4)_
  - Criterio: sesión multi-turno funciona; `echo "salir" | python src/hr_assistant.py` termina con código 0; una pregunta de seguimiento obtiene respuesta contextualizada.

- [x] **B3.** Implementar manejo de errores: credencial ausente (abortar con código 1), throttling (retry con backoff), `ClientError` genérico (imprimir y continuar), entrada vacía (ignorar) · _(ref: RNF-4, diseño §5)_
  - Criterio: `AWS_BEARER_TOKEN_BEDROCK= python src/hr_assistant.py` sale con código 1 y mensaje claro.

## Fase C — IA responsable y seguridad

- [x] **C1.** Verificar comportamiento de IA responsable: probar pregunta off-topic y confirmar derivación; verificar que el disclaimer aparece al inicio · _(ref: RNF-2, RNF-3, diseño §6)_
  - Criterio: pregunta "¿Cuál es la capital de Francia?" produce la respuesta de derivación, no información geográfica.
  - Resultado (2026-07-22): PASS — disclaimer visible al inicio; pregunta off-topic produce exactamente "No tengo información sobre eso. Para dudas adicionales, contacta directamente al equipo de Recursos Humanos en rrhh@empresa.com."; pregunta RRHH posterior responde correctamente (historial no contaminado).

- [x] **C2.** Auditoría de seguridad: `grep -r "ABSK\|aws_secret\|aws_access_key" .` no produce resultados en archivos rastreados por git; confirmar que el token solo se lee de `os.environ` · _(ref: RNF-5, diseño §7)_
  - Criterio: grep vacío; revisión de código confirma `os.environ["AWS_BEARER_TOKEN_BEDROCK"]` como única fuente del token.
  - Resultado (2026-07-22): PASS — hits de grep son solo menciones documentales (README, specs); cero valores reales de credencial. Token leído exclusivamente vía `os.environ.get()` en `src/`. Sin archivos `.env`/`.pem`/`.key` rastreados. `.gitignore` cubre `.env`, `.aws/`, `*bearer*token*`.

## Fase D — Validación y entrega

- [x] **D1.** Probar los criterios de aceptación de todos los requisitos RF-1 a RF-5 y RNF-1 a RNF-6; documentar resultado en esta tarea · _(ref: 01-requirements.md)_
  - Criterio: cada criterio de aceptación marcado como PASS o FAIL con evidencia.
  - Resultados (2026-07-22):
    - RF-1 PASS — respuesta a pregunta RRHH en 2.8–3.6s, sin excepción
    - RF-2 PASS — pregunta de seguimiento ("3 años → 45 días") contextualizada correctamente
    - RF-3 PASS — system prompt presente como constante; off-topic deriva a rrhh@empresa.com
    - RF-4 PASS — `salir` y `exit` terminan con código 0
    - RF-5 PASS — modelo inválido primario cae a haiku con aviso "[Aviso] Usando modelo alternativo"
    - RNF-1 PASS — 5/5 invocaciones bajo 30s (promedio 3.1s, máximo 3.6s)
    - RNF-2 PASS — disclaimer visible antes del primer prompt en cada sesión
    - RNF-3 PASS — preguntas off-topic reciben derivación exacta, sin alucinaciones
    - RNF-4 PASS — sin token → mensaje claro + código de salida 1
    - RNF-5 PASS — grep en archivos rastreados: solo menciones documentales, cero valores reales
    - RNF-6 PASS — `MAX_TOKENS = 1024` visible en `src/hr_assistant.py:13`

- [x] **D2.** Documentar costo real observado (tokens usados en las pruebas) y comparar con la estimación de diseño §8 · _(ref: diseño §8)_
  - Criterio: tabla de costo real en `specs/02-design.md` actualizada.
  - Resultado (2026-07-22): sesión de 8 turnos = 8 850 input + 1 027 output tokens → $0.000042 USD. Estimación inicial < $0.01 USD confirmada; costo real es ~240× menor que el tope estimado.

- [ ] **D3.** Escribir `README.md` del proyecto con: qué hace, cómo instalarlo (`uv pip install -r requirements.txt`), cómo ejecutarlo, variables de entorno requeridas · _(ref: entregables)_
  - Criterio: un colaborador nuevo puede correr el proyecto siguiendo solo el README.

- [ ] **D4.** Revisión final del historial de commits: verificar que cada commit corresponde a una tarea y sigue el formato convencional · _(ref: proceso EPCC)_
  - Criterio: `git log --oneline` muestra al menos un commit por tarea completada; ningún commit contiene secretos.

---

### Registro de desviaciones

> Si al implementar descubres que el diseño estaba mal, anótalo aquí y corrige la spec antes de seguir.

| Fecha | Tarea | Qué cambió respecto al plan | Spec actualizada |
|-------|-------|------------------------------|------------------|
| 2026-07-22 | B1 | `MODEL_FALLBACK` necesita sufijo `-v1:0` (`us.anthropic.claude-haiku-4-5-20251001-v1:0`); sin él, Bedrock retorna `ValidationException` | `specs/02-design.md` §2, `specs/00-capstone-brief.md` §6 |
