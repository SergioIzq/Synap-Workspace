# Smoke test de extremo a extremo (tarea 5.5)

Ejecútalo tú, a mano, contra el despliegue real una vez completado
`docs/deployment-runbook.md`. No es algo que se pueda automatizar ni verificar desde este
entorno de desarrollo (no hay VPS, iPhone ni navegador real aquí) — es una lista de
comprobación, no un resultado ya confirmado.

- [ ] **Registro**: entra en `https://synap.sergioizq.com`, crea una cuenta con tu email real.
- [ ] **Login**: cierra sesión (o abre una ventana de incógnito) y vuelve a entrar con esas
      credenciales.
- [ ] **Captura desde la app**: escribe algo en el input de captura rápida de la página
      principal. Debe aparecer en la lista al momento.
- [ ] **Token de API**: desde el perfil, genera tu token de API personal (guárdalo — solo se
      muestra una vez).
- [ ] **Atajo de iOS**: sigue `docs/ios-shortcut-setup.md` para montar el Atajo con ese token.
      Comparte una URL desde Safari usando el Atajo. Confirma que la nota aparece en la app al
      recargar (puede tardar un instante: el scraping de metadatos y el embedding se generan en
      segundo plano).
- [ ] **Bookmark enriquecido**: abre esa nota capturada por URL y comprueba que tiene título,
      descripción e imagen extraídos de la página (si la web es alcanzable — si no, la nota debe
      seguir ahí, solo sin metadatos, no como un error).
- [ ] **Búsqueda**: busca por una palabra que sepas que aparece en una de tus notas. Debe
      aparecer en los resultados. Prueba también el filtro por tag tras añadir un tag a una nota.
- [ ] **Notas relacionadas**: abre el detalle de una nota con contenido similar a otra (por
      ejemplo, dos notas sobre el mismo tema) y comprueba que aparece en el panel de "Related
      notes" de la otra.
- [ ] **Asistente**: en `/assistant`, pregunta algo que solo se pueda responder con una nota que
      hayas capturado (por ejemplo, "¿qué apunté sobre X?"). Debe responder citando que está
      basado en tus notas ("grounded in N of your notes").
- [ ] **Asistente sin contexto**: pregunta algo que no tenga nada que ver con tus notas. Debe
      decir que no encontró nada relevante, no inventarse una respuesta.
- [ ] **Aislamiento** (si tienes o creas una segunda cuenta de prueba): confirma que esa segunda
      cuenta no ve ni encuentra por búsqueda ninguna nota de la primera, y que preguntarle al
      asistente sobre el contenido de la primera cuenta no devuelve nada.

Si algo de esto falla, el sitio más probable para mirar primero son los logs de
`docker compose logs synap-api synap-ai` — la mayoría de estos pasos cruzan ambos servicios.
