# Design

## Context

Ver `proposal.md — Why` para la motivación completa.

Puntos técnicos clave:
- `AbsEntity<TId>` (paquete NuGet `SergioIzq.Domain.Kernel`) inicializa `FechaCreacion` con `DateTime.Now`, que devuelve `Kind = DateTimeKind.Local`.
- Npgsql 6+ rechaza escribir `DateTime` con `Kind=Local` en columnas `timestamp with time zone` a menos que esté habilitado el switch de compatibilidad `Npgsql.EnableLegacyTimestampBehavior`.
- El switch no existe en ningún punto del codebase actual.
- Al no controlar el paquete del kernel, no podemos cambiar cómo se genera `FechaCreacion`.
- Todos los mensajes de error visibles al usuario están en inglés; la app está en español.

## Goals / Non-Goals

**Goals:**
- Hacer funcionar el registro sin errores 500.
- Todos los mensajes de error visibles al usuario en español, tanto los que llegan del backend vía `ApiResult.error.message` como los fallbacks del frontend.

**Non-Goals:**
- Migrar las columnas `timestamptz` a `timestamp without time zone`.
- Añadir una biblioteca de i18n completa.
- Traducir textos de la interfaz distintos de los mensajes de error (labels, placeholders, cabeceras).

## Decisions

### D1 — Usar `EnableLegacyTimestampBehavior` en lugar de migrar el tipo de columna

**Elegido:** `AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true)` al inicio de `Program.cs`.

**Alternativa descartada:** cambiar `created_at` a `timestamp without time zone` en una nueva migración.
- Requeriría una migración destructiva sobre datos existentes.
- El tipo `timestamptz` sigue siendo el correcto semánticamente para fechas UTC; el problema está solo en el `Kind` del `DateTime` de C#.

**Alternativa descartada:** crear una subclase de `AbsEntity` que sobreescriba `FechaCreacion` con `DateTime.UtcNow`.
- Requiere refactorizar todos los constructores de entidades.
- El switch es un cambio de una línea con el mismo efecto neto.

**Nota:** el switch es process-wide y afecta a todos los contextos EF de la aplicación, lo que es el comportamiento deseado.

### D2 — Traducir en los puntos de origen, no en un middleware

**Elegido:** editar cada mensaje directamente donde está definido (value objects, handlers, middleware, stores del frontend).

**Alternativa descartada:** un middleware de traducción de errores.
- Sobreingeniería innecesaria para este volumen de mensajes.
- Los mensajes de dominio son parte del contrato del sistema, no texto de UI variable.

### D3 — Alcance de la traducción: solo mensajes visibles al usuario

Los errores de IDs internos (`UserId`, `NoteId`, `TagId`) y `PasswordHash` nunca llegan al usuario final (son errores de infraestructura/desarrollo). Se traducen igualmente para consistencia, pero no son críticos.

## Risks / Trade-offs

- **Switch global de Npgsql** → afecta a todos los contextos futuros que se añadan al proyecto. Aceptable: la decisión es coherente para un proyecto que no controla `AbsEntity`.
- **`EnableLegacyTimestampBehavior` en Npgsql ≥8 puede quedar deprecated** → si el kernel se actualiza para usar `DateTime.UtcNow`, el switch se puede eliminar sin impacto funcional. No requiere acción inmediata.
- **Mensajes del backend son parte de `ApiResult.error.message`** → si el frontend muestra directamente ese campo en la UI (lo hace), un cambio de texto es un cambio visible. El frontend ya espera y muestra esos mensajes; traducirlos es exactamente lo que se quiere.
