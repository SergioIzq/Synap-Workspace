# Spec Delta

## ADDED Requirements

### Requirement: Consultar el calendario desde la conversación global
Cuando el usuario tiene un calendario conectado y su modelo admite acciones, el asistente SHALL poder, en la conversación global, leer los eventos del calendario en un intervalo para responder preguntas como "¿qué tengo mañana?" o "¿cuándo es la próxima reunión de sprint?". El intervalo SHALL expresarse con las palabras del usuario y resolverse por el sistema en su zona horaria, igual que el momento de un recordatorio. La lectura SHALL ser una acción de solo lectura: el asistente no SHALL crear, cambiar ni borrar eventos, y cuando se le pida SHALL decir que no puede hacerlo. Sin calendario conectado, o con la conexión marcada para reconectar, el asistente SHALL decirlo y remitir a Configuración en vez de inventar eventos. Las conversaciones acotadas a una nota o a una etiqueta no SHALL leer el calendario.

#### Scenario: Qué tengo mañana
- **WHEN** un usuario con Google conectado pregunta "¿qué tengo mañana?"
- **THEN** el asistente lee los eventos del día siguiente en su zona horaria y responde con ellos y sus horas

#### Scenario: Próxima ocurrencia
- **WHEN** un usuario pregunta "¿cuándo tengo la próxima reunión de sprint?"
- **THEN** el asistente busca en sus eventos próximos y responde con la fecha y la hora de la primera que coincide, o dice que no encontró ninguna

#### Scenario: Sin calendario conectado
- **WHEN** un usuario sin calendario conectado pregunta "¿qué tengo mañana?"
- **THEN** no se inventa ningún evento y el asistente dice que no tiene calendario conectado y que puede conectarlo en Configuración

#### Scenario: Conexión que necesita reconectarse
- **WHEN** un usuario cuya conexión está marcada para reconectar pregunta por sus eventos
- **THEN** el asistente dice que no puede leer el calendario y que lo reconecte en Configuración

#### Scenario: Crear un evento
- **WHEN** un usuario pide al asistente "pon una reunión el jueves a las 10"
- **THEN** no se crea ningún evento y el asistente explica que solo puede leer el calendario

#### Scenario: Sin acciones disponibles
- **WHEN** un usuario cuyo modelo no admite acciones pregunta "¿qué tengo mañana?"
- **THEN** el asistente dice que el modelo actual no puede consultar el calendario y que puede elegir otro en Configuración

### Requirement: La lectura del calendario se muestra en la respuesta
Cada lectura del calendario SHALL aparecer entre las acciones de la respuesta con una descripción breve en español que diga el intervalo leído ("Calendario consultado: …"), sin enlace. Los eventos no SHALL guardarse con la respuesta: al recargar la conversación se SHALL seguir viendo la acción y el texto de la respuesta, pero no los eventos leídos.

#### Scenario: Acción mostrada
- **WHEN** el asistente lee el calendario para responder
- **THEN** la respuesta lista "Calendario consultado" con el intervalo leído

### Requirement: Recordatorios anclados a un evento
Cuando el usuario pide un recordatorio relativo a un evento de su calendario ("una hora antes de la demo", "el día antes del dentista"), el asistente SHALL localizar el evento leyendo el calendario y pasar el evento y la antelación con las palabras del usuario; el sistema, no el asistente, SHALL calcular el momento a partir del inicio del evento tal como está en ese instante. Cuando la antelación es un día sin hora, se SHALL usar las 09:00 en la zona horaria del usuario. Si el evento no existe, no está en el futuro o el momento calculado ya pasó, no SHALL crearse el recordatorio y la respuesta SHALL decirlo. La respuesta SHALL indicar el evento, la fecha y la hora calculadas, y que el recordatorio no seguirá al evento si este cambia.

#### Scenario: Una hora antes de la demo
- **WHEN** un usuario en `Europe/Madrid` con una demo mañana a las 12:00 pide "recuérdame revisar las diapositivas una hora antes de la demo"
- **THEN** se crea un recordatorio para mañana a las 11:00 en `Europe/Madrid` con ese texto, y la respuesta nombra la demo y esa hora

#### Scenario: El día antes
- **WHEN** un usuario con el dentista el viernes pide "avísame el día antes del dentista"
- **THEN** se crea un recordatorio para el jueves a las 09:00 en su zona horaria

#### Scenario: Evento no encontrado
- **WHEN** un usuario pide un recordatorio antes de un evento que no aparece en su calendario
- **THEN** no se crea ningún recordatorio y la respuesta dice que no encontró el evento

#### Scenario: Momento calculado ya pasado
- **WHEN** un usuario pide a las 11:30 un recordatorio una hora antes de un evento que empieza a las 12:00
- **THEN** no se crea ningún recordatorio y la respuesta explica que ese momento ya pasó

#### Scenario: Sin calendario conectado
- **WHEN** un usuario sin calendario conectado pide un recordatorio antes de un evento
- **THEN** no se crea ningún recordatorio y el asistente remite a Configuración para conectar el calendario
