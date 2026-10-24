# Spec Delta

## ADDED Requirements

### Requirement: El briefing incluye los eventos del día
Para un usuario con un calendario conectado, el briefing SHALL incluir una sección con los eventos de su calendario principal en el día local que se resume, ordenados por hora de inicio, cada uno con su título y su hora local de inicio, o indicando que dura todo el día. Bajo cada evento SHALL enlazar como mucho un número de notas relacionadas que fija el sistema, buscadas por el sentido y las palabras del título del evento entre las notas del propio usuario, y SHALL omitir el enlace cuando ninguna nota es lo bastante relevante. La sección SHALL ser la primera del briefing, SHALL omitirse cuando el día no tiene eventos, y SHALL indicar el total cuando muestra solo algunos. Los eventos SHALL contar como contenido: un día con eventos y nada más no es un día vacío. Esto SHALL aplicarse igual al briefing automático y al pedido bajo demanda.

#### Scenario: Eventos del día
- **WHEN** un usuario con calendario conectado tiene tres reuniones hoy
- **THEN** el briefing empieza con una sección que las lista por hora de inicio con su título y su hora local

#### Scenario: Evento con notas relacionadas
- **WHEN** el usuario tiene hoy una "Revisión de código del módulo de pagos" y notas sobre el módulo de pagos
- **THEN** bajo ese evento aparecen enlaces a esas notas, como mucho el número que fija el sistema

#### Scenario: Evento sin notas relacionadas
- **WHEN** ningún contenido del usuario es lo bastante relevante para un evento
- **THEN** el evento aparece sin notas, en vez de con notas que no tienen relación

#### Scenario: Evento de todo el día
- **WHEN** el usuario tiene hoy un evento de todo el día
- **THEN** aparece indicando que dura todo el día, antes de los eventos con hora

#### Scenario: Día sin eventos
- **WHEN** el calendario del usuario no tiene eventos hoy
- **THEN** la sección de calendario no aparece y el resto del briefing no cambia

#### Scenario: Solo eventos
- **WHEN** a la hora elegida un usuario tiene eventos hoy y nada más que contar
- **THEN** el briefing se envía con la sección de calendario

#### Scenario: Sin calendario conectado
- **WHEN** un usuario sin calendario conectado recibe su briefing
- **THEN** no aparece ninguna sección de calendario ni ningún aviso sobre el calendario

### Requirement: Un calendario ilegible no detiene el briefing
Cuando el calendario de un usuario conectado no puede leerse al construir el briefing, el briefing SHALL construirse y enviarse con el resto de secciones, en lugar de la sección de calendario SHALL incluir un aviso de una línea de que no se pudo leer el calendario, y cuando la conexión necesita reconectarse SHALL decir que se reconecte en Configuración. El aviso no SHALL contar como contenido: un día sin nada más que contar SHALL seguir sin enviarse de forma automática. Un fallo al leer el calendario de un usuario no SHALL impedir el briefing de los demás.

#### Scenario: Proveedor caído al construir el briefing
- **WHEN** el calendario de un usuario no responde a la hora de su briefing
- **THEN** el briefing se envía con sus notas y recordatorios y una línea que dice que no se pudo leer el calendario

#### Scenario: Conexión que necesita reconectarse
- **WHEN** la conexión de un usuario está marcada para reconectar a la hora de su briefing
- **THEN** el briefing incluye una línea que pide reconectar el calendario en Configuración

#### Scenario: Solo el aviso
- **WHEN** a la hora elegida el calendario no puede leerse y el usuario no tiene nada más que contar
- **THEN** el briefing automático no se envía y el día cuenta como resumido
