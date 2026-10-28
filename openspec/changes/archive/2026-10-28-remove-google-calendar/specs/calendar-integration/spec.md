## MODIFIED Requirements

### Requirement: Un usuario conecta como mucho un calendario
Un usuario autenticado SHALL poder tener como mucho una conexión de calendario, y SHALL ser una conexión CalDAV. Conectar un calendario cuando ya hay uno conectado SHALL reemplazar la conexión anterior, borrando sus credenciales. De cada conexión se SHALL leer únicamente el calendario principal de la cuenta.

#### Scenario: Primera conexión
- **WHEN** un usuario sin calendario conectado completa la conexión CalDAV
- **THEN** queda conectado su calendario principal, y Configuración lo muestra como conectado

#### Scenario: Cambio de proveedor
- **WHEN** un usuario con un calendario CalDAV conectado conecta otro servidor o cuenta CalDAV
- **THEN** la conexión anterior se elimina con sus credenciales y solo queda la nueva

#### Scenario: Solo el calendario principal
- **WHEN** la cuenta conectada tiene varios calendarios
- **THEN** solo se leen los eventos de su calendario principal

#### Scenario: Sin opción de Google
- **WHEN** un usuario intenta iniciar una conexión con Google Calendar
- **THEN** el sistema no ofrece esa opción ni guarda nada

### Requirement: Las credenciales del calendario nunca se revelan
Las credenciales de una conexión de calendario (el usuario y la contraseña CalDAV) SHALL guardarse cifradas, SHALL usarse solo para leer el calendario de su propietario, y no SHALL devolverse en ninguna respuesta de la API ni aparecer en ningún registro. El estado de la conexión SHALL exponer solo el proveedor, la cuenta o el usuario conectado, desde cuándo, y si la conexión necesita volver a conectarse.

#### Scenario: Estado de la conexión
- **WHEN** un usuario con un calendario conectado consulta su configuración
- **THEN** ve el proveedor, la cuenta conectada, desde cuándo y si funciona, pero nunca una contraseña

#### Scenario: Credenciales aisladas entre usuarios
- **WHEN** se leen eventos para un usuario
- **THEN** se usan solo las credenciales de ese usuario, y nunca se leen ni se muestran eventos de otro

### Requirement: Un calendario que deja de responder no rompe nada
Cuando no se puede leer el calendario porque las credenciales dejaron de ser válidas, el sistema SHALL marcar la conexión como necesitada de reconexión, SHALL mostrarlo en Configuración, y el asistente y el briefing SHALL seguir funcionando sin eventos y diciéndolo. Cuando el servidor no responde, SHALL tratarse como un fallo temporal que no marca la conexión. En ambos casos el fallo SHALL registrarse con su causa real, sin el contenido de ningún evento.

#### Scenario: Acceso revocado
- **WHEN** el usuario cambió o revocó la contraseña en su servidor CalDAV y se intenta leer su calendario
- **THEN** la conexión queda marcada para reconectar, Configuración lo muestra, y la lectura falla sin impedir la respuesta o el briefing

#### Scenario: Proveedor caído
- **WHEN** el servidor del calendario no responde al leer eventos
- **THEN** la conexión no se marca para reconectar, el fallo se registra como proveedor inalcanzable, y la respuesta o el briefing siguen sin eventos

#### Scenario: Reconexión
- **WHEN** un usuario con la conexión marcada para reconectar vuelve a conectar su calendario
- **THEN** la marca desaparece y los eventos vuelven a leerse

## ADDED Requirements

### Requirement: Desconectar el calendario CalDAV
El usuario SHALL poder desconectar su calendario desde Configuración. Desconectar SHALL borrar las credenciales guardadas y SHALL completarse en Synap sin depender de ningún servicio externo. Borrar la cuenta de un usuario SHALL borrar su conexión de calendario. Los recordatorios ya creados a partir de eventos SHALL conservarse.

#### Scenario: Calendario desconectado
- **WHEN** un usuario desconecta su calendario
- **THEN** sus credenciales se borran, Configuración lo muestra como no conectado, y el asistente y el briefing dejan de leer sus eventos

#### Scenario: Recordatorios conservados
- **WHEN** un usuario con recordatorios creados a partir de eventos desconecta su calendario
- **THEN** esos recordatorios siguen pendientes y se entregan en su momento

#### Scenario: Cuenta borrada
- **WHEN** se borra la cuenta de un usuario con un calendario conectado
- **THEN** su conexión de calendario y sus credenciales se borran

## REMOVED Requirements

### Requirement: Conectar Google Calendar
**Reason**: CalDAV pasa a ser el único proveedor. Google exigía un cliente OAuth por despliegue y verificación, y nunca ha tenido ninguna conexión en producción.
**Migration**: Conectar el calendario por CalDAV (servidor propio, iCloud, Fastmail, Nextcloud…). No hay conexiones de Google que migrar ni tokens que revocar.

### Requirement: Desconectar el calendario
**Reason**: Incluía la revocación del acceso en Google, que desaparece con el proveedor. Lo sustituye "Desconectar el calendario CalDAV", con el mismo comportamiento sin la revocación.
**Migration**: Ninguna: desconectar sigue borrando las credenciales y conservando los recordatorios.
