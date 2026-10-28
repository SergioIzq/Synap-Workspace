## MODIFIED Requirements

### Requirement: Consultar el calendario desde la conversación global
Cuando el usuario tiene un calendario conectado y su modelo admite acciones, el asistente SHALL poder, en la conversación global, leer los eventos del calendario en un intervalo para responder preguntas como "¿qué tengo mañana?" o "¿cuándo es la próxima reunión de sprint?". El intervalo SHALL expresarse con las palabras del usuario y resolverse por el sistema en su zona horaria, igual que el momento de un recordatorio. La lectura SHALL ser una acción de solo lectura: el asistente no SHALL crear, cambiar ni borrar eventos, y cuando se le pida SHALL decir que no puede hacerlo. Sin calendario conectado, o con la conexión marcada para reconectar, el asistente SHALL decirlo y remitir a Configuración en vez de inventar eventos. Las conversaciones acotadas a una nota o a una etiqueta no SHALL leer el calendario.

#### Scenario: Qué tengo mañana
- **WHEN** un usuario con un calendario CalDAV conectado pregunta "¿qué tengo mañana?"
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
