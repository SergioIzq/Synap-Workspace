# Capturar en Synap desde el share sheet de iOS

iOS Safari no soporta la Web Share Target API, así que una PWA no puede registrarse como
destino nativo del menú "Compartir" (ver `openspec/changes/synap-mvp/design.md`, Decisión 3).
El sustituto es un **Atajo de iOS** que sí aparece en ese menú y llama directamente al endpoint
de captura rápida de Synap (`POST /api/notes/quick-capture`).

No se puede distribuir un fichero `.shortcut` binario desde aquí (el formato de Atajos es
propio de Apple y se crea/comparte desde la app Shortcuts o un enlace de iCloud) — esta guía son
los pasos exactos para montarlo tú mismo, una vez, en un par de minutos.

## Requisito previo: tu token de API personal

1. Entra en Synap desde el navegador y haz login.
2. Ve a tu perfil → "Generar token de API" (`POST /api/auth/api-token`, ver `AuthController`).
3. Copia el token que se muestra — **solo se ve una vez**. Si lo regeneras, el anterior deja de
   funcionar de inmediato.

## Crear el Atajo

1. Abre la app **Atajos** (Shortcuts) en tu iPhone.
2. Toca **+** para crear un atajo nuevo.
3. Añade la acción **"Obtener contenido de URL"** (Get Contents of URL):
   - **URL**: `https://<tu-dominio>/api/notes/quick-capture`
   - **Método**: `POST`
   - **Cabeceras**:
     - `Authorization`: `Bearer <tu-token-de-api>`
     - `Content-Type`: `application/json`
   - **Cuerpo de la petición** (JSON):
     ```json
     { "content": "Entrada del Atajo", "type": null }
     ```
     Sustituye `"Entrada del Atajo"` por la variable mágica **Shortcut Input** (el texto/URL que
     compartiste) — en la app de Atajos, toca ese campo y selecciona la variable en vez de
     escribir texto literal.
4. Nombra el atajo, por ejemplo **"Guardar en Synap"**.
5. Entra en los ajustes del atajo (icono ⓘ) y activa **"Mostrar en hoja para compartir"** (Show
   in Share Sheet). En "Tipos de contenido aceptados", marca al menos **Texto** y **URLs**.

## Usarlo

Desde Safari, Notas, YouTube o cualquier app con botón de compartir: toca **Compartir** → busca
**"Guardar en Synap"** en la lista. El contenido llega directamente a tu bóveda sin abrir la app.

`type: null` deja que el backend infiera si es una nota de texto o un marcador a partir del
contenido (`NoteTypeInference` — si es una URL sin espacios, se guarda como marcador). No hace
falta que el Atajo decida el tipo.

## Si el token deja de funcionar

Si regeneraste el token desde la app, el Atajo seguirá usando el antiguo (guardado en el paso
3) hasta que edites la cabecera `Authorization` con el nuevo valor. No hay renovación automática
en la v1 — es un cambio manual de una línea en el Atajo.
