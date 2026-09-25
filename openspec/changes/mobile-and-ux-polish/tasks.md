# Tasks

## 1. Tokens y tema

- [ ] 1.1 Definir en `styles.scss` las variables `--synap-*` (fondo del sidebar, burbuja del usuario, texto de navegación…) para `:root` y `.app-dark`, y sustituir los colores fijos en `src/app`. Verificar que `grep -rnE '#[0-9a-fA-F]{3,6}\b|rgba\(' src/app` solo devuelve usos justificados, como el SVG del logo.
- [ ] 1.2 Configurar `darkModeSelector: '.app-dark'` en `app.config.ts`. Verificar que al añadir la clase `app-dark` a mano en DevTools los componentes de PrimeNG pasan a oscuro.
- [ ] 1.3 Crear `ThemeService` (light, dark o system, guardado en `localStorage` y escuchando `matchMedia`) con tests unitarios de cada modo. Verificar que los tests pasan.
- [ ] 1.4 Añadir a `index.html` el script inline que aplica `.app-dark` antes del arranque. Verificar que al recargar en oscuro no hay destello del tema claro.
- [ ] 1.5 Añadir la sección "Apariencia" en `SettingsPage` con `p-selectbutton` (Claro / Oscuro / Sistema). Verificar a mano el cambio inmediato y que persiste tras recargar.

## 2. Layout responsive

- [ ] 2.1 Refactorizar `app-shell`: sidebar solo a partir de 768px, y en móvil cabecera compacta más `nav.bottom-nav` con Notas, Asistente y Configuración y estado activo. Verificar en DevTools a 360px y a 1280px.
- [ ] 2.2 Añadir `viewport-fit=cover` en `index.html`, safe areas en la cabecera y la barra inferior, y padding inferior en `.content`. Verificar en el simulador responsive con el perfil de iPhone que nada queda tapado.
- [ ] 2.3 Añadir "Cerrar sesión" a Configuración > Cuenta para que sea accesible en móvil. Verificar a mano a 360px.
- [ ] 2.4 Revisar las páginas de lista, detalle, asistente, auth y configuración a 360px (fila de búsqueda en columna, botones a ancho completo, inputs a 16px). Verificar que ninguna página tiene scroll horizontal.

## 3. Feedback y confirmaciones

- [ ] 3.1 Crear `NotificationService` sobre `MessageService`. Verificar con un test unitario que delega con la severidad y la duración correctas.
- [ ] 3.2 Añadir toasts de éxito o error en `NotesStore` para crear, editar, borrar y etiquetar. Verificar a mano cada operación.
- [ ] 3.3 Añadir confirmación antes de borrar una nota en `note-detail.page.ts`. Verificar a mano que cancelar no borra y confirmar borra y redirige.
- [ ] 3.4 Añadir al `errorInterceptor` el toast global para `status 0` y `>= 500`. Verificar con un test del interceptor y a mano parando la API.

## 4. Asistente

- [ ] 4.1 En Python, añadir `sources: [{id, title}]` a `AskResponse`, con fragmento del contenido si falta el título. Verificar con un test de `/ask`.
- [ ] 4.2 En .NET, crear el record `AssistantSource` en `AssistantAnswer.Sources` y mapearlo en `AiServiceClient`, manteniendo `SourceNoteIds`. Verificar ampliando `AiServiceClientTests`.
- [ ] 4.3 En el front, pintar las fuentes como `p-chip` enlazados a la nota. Verificar a mano que un clic abre la nota fuente.
- [ ] 4.4 En `AssistantStore`, persistir en `localStorage` por usuario (máximo 50 interacciones, sin mensajes pendientes) y borrar al cerrar sesión. Verificar con tests del store: recarga, límite y logout.
- [ ] 4.5 Añadir el botón "Nueva conversación", el botón de copiar por respuesta (con toast "Copiado") y sugerencias de preguntas clicables en el estado vacío. Verificar a mano.

## 5. Navegación y detalles

- [ ] 5.1 Crear `NotFoundPage` y la ruta `**`. Verificar que `/cualquier-cosa` muestra la 404 con enlace a Notas.
- [ ] 5.2 Crear estados vacíos con icono y llamada a la acción en la lista de notas (sin notas y sin resultados, este último con botón para limpiar filtros). Verificar a mano con un usuario nuevo y con una búsqueda sin resultados.
- [ ] 5.3 Añadir atajos: `/` enfoca la búsqueda (salvo si el foco ya está en un input) y `Ctrl/⌘+Enter` guarda en captura y edición. Verificar a mano.
- [ ] 5.4 Hacer un barrido de idioma: `grep` de cadenas en inglés visibles en `src/app` y en los mensajes del ai-service y de .NET, y traducirlas. Verificar que no quedan textos visibles en inglés recorriendo todas las pantallas.

## 6. Verificación

- [ ] 6.1 Hacer una pasada completa en móvil (360px) y escritorio, en claro y oscuro, por login, notas (crear, editar, borrar), asistente (preguntar, abrir fuente, recargar, nueva conversación) y configuración. Verificar además con `ng build` sin errores ni avisos de presupuesto nuevos.
