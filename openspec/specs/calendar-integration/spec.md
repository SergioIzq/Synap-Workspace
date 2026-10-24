# calendar-integration Specification

## Purpose

Permite a cada usuario conectar su calendario externo (Google Calendar o un servidor CalDAV) para que el asistente y el briefing conozcan sus eventos, leyéndolos solo en el momento en que hacen falta y sin guardarlos nunca en Synap.

## Requirements

### Requirement: Un usuario conecta como mucho un calendario
Un usuario autenticado SHALL poder tener como mucho una conexión de calendario, de Google o de CalDAV. Conectar un calendario cuando ya hay uno conectado SHALL reemplazar la conexión anterior, borrando sus credenciales. De cada conexión se SHALL leer únicamente el calendario principal de la cuenta.

#### Scenario: Primera conexión
- **WHEN** un usuario sin calendario conectado completa la conexión con Google
- **THEN** queda conectado su calendario principal de Google, y Configuración lo muestra como conectado

#### Scenario: Cambio de proveedor
- **WHEN** un usuario con Google conectado conecta un calendario CalDAV
- **THEN** la conexión de Google se elimina con sus credenciales y solo queda la de CalDAV

#### Scenario: Solo el calendario principal
- **WHEN** la cuenta conectada tiene varios calendarios
- **THEN** solo se leen los eventos de su calendario principal

### Requirement: Conectar Google Calendar
El sistema SHALL permitir conectar Google Calendar mediante el consentimiento de Google, pidiendo solo permiso de lectura del calendario. El sistema SHALL aceptar el resultado del consentimiento únicamente para el usuario que lo inició y dentro de un plazo limitado, y SHALL rechazar cualquier respuesta de Google que no corresponda a un inicio de conexión vigente de ese usuario. Si el usuario cancela o deniega el permiso, no se SHALL guardar nada y la web SHALL decirlo en español. Cuando el despliegue no tiene configurado el acceso a Google, la opción de Google no SHALL ofrecerse y CalDAV SHALL seguir disponible.

#### Scenario: Consentimiento concedido
- **WHEN** un usuario inicia la conexión con Google y concede el permiso de lectura
- **THEN** la conexión se guarda para ese usuario y vuelve a Configuración con el calendario conectado

#### Scenario: Permiso denegado
- **WHEN** un usuario cancela o deniega el permiso en la pantalla de Google
- **THEN** no se guarda ninguna conexión, se conserva la anterior si la había, y Configuración muestra un mensaje en español

#### Scenario: Respuesta de Google ajena o caducada
- **WHEN** llega a Synap una respuesta de consentimiento que no corresponde a un inicio de conexión vigente, o que fue iniciada por otro usuario
- **THEN** no se guarda nada y no se conecta ningún calendario

#### Scenario: Google no configurado en el despliegue
- **WHEN** el despliegue no tiene configurado el acceso a Google y un usuario abre la sección "Calendario"
- **THEN** solo se ofrece conectar un calendario CalDAV

### Requirement: Conectar un calendario CalDAV
El sistema SHALL permitir conectar un calendario CalDAV indicando la URL del servidor o del calendario, un usuario y una contraseña. Antes de guardar nada, el sistema SHALL comprobar contra el servidor que las credenciales son válidas y localizar el calendario principal. Si la comprobación falla, no SHALL guardarse nada y el mensaje en español SHALL distinguir credenciales rechazadas, servidor inalcanzable y servidor sin calendario utilizable. La URL SHALL usar HTTPS.

#### Scenario: Conexión CalDAV válida
- **WHEN** un usuario indica la URL de su servidor CalDAV con un usuario y una contraseña de aplicación válidos
- **THEN** se localiza su calendario principal, la conexión se guarda y Configuración la muestra como conectada

#### Scenario: Credenciales rechazadas
- **WHEN** el servidor CalDAV rechaza el usuario o la contraseña
- **THEN** no se guarda nada y el usuario ve que las credenciales no son válidas

#### Scenario: Servidor inalcanzable
- **WHEN** el servidor CalDAV no responde durante la comprobación
- **THEN** no se guarda nada y el usuario ve que no se pudo contactar con el servidor y que lo intente más tarde

#### Scenario: Sin calendario utilizable
- **WHEN** las credenciales son válidas pero la cuenta no tiene ningún calendario de eventos
- **THEN** no se guarda nada y el usuario ve que no se encontró ningún calendario

#### Scenario: URL sin HTTPS
- **WHEN** un usuario indica una URL que no usa HTTPS
- **THEN** se rechaza con un mensaje en español y no se contacta con el servidor

### Requirement: Las credenciales del calendario nunca se revelan
Las credenciales de una conexión de calendario (los tokens de Google y la contraseña CalDAV) SHALL guardarse cifradas, SHALL usarse solo para leer el calendario de su propietario, y no SHALL devolverse en ninguna respuesta de la API ni aparecer en ningún registro. El estado de la conexión SHALL exponer solo el proveedor, la cuenta o el usuario conectado, desde cuándo, y si la conexión necesita volver a conectarse.

#### Scenario: Estado de la conexión
- **WHEN** un usuario con un calendario conectado consulta su configuración
- **THEN** ve el proveedor, la cuenta conectada, desde cuándo y si funciona, pero nunca un token ni una contraseña

#### Scenario: Credenciales aisladas entre usuarios
- **WHEN** se leen eventos para un usuario
- **THEN** se usan solo las credenciales de ese usuario, y nunca se leen ni se muestran eventos de otro

### Requirement: Desconectar el calendario
El usuario SHALL poder desconectar su calendario desde Configuración. Desconectar SHALL borrar las credenciales guardadas y, en Google, SHALL pedir a Google que revoque el acceso; si la revocación falla, la desconexión SHALL completarse igualmente en Synap. Borrar la cuenta de un usuario SHALL borrar su conexión de calendario. Los recordatorios ya creados a partir de eventos SHALL conservarse.

#### Scenario: Calendario desconectado
- **WHEN** un usuario desconecta su calendario
- **THEN** sus credenciales se borran, Configuración lo muestra como no conectado, y el asistente y el briefing dejan de leer sus eventos

#### Scenario: Revocación fallida en Google
- **WHEN** un usuario desconecta Google y Google no responde a la revocación
- **THEN** la conexión se borra igualmente en Synap y el fallo queda registrado

#### Scenario: Recordatorios conservados
- **WHEN** un usuario con recordatorios creados a partir de eventos desconecta su calendario
- **THEN** esos recordatorios siguen pendientes y se entregan en su momento

#### Scenario: Cuenta borrada
- **WHEN** se borra la cuenta de un usuario con un calendario conectado
- **THEN** su conexión de calendario y sus credenciales se borran

### Requirement: Los eventos nunca se almacenan
Los eventos SHALL leerse del proveedor en el momento en que se necesitan y no SHALL guardarse en la base de datos, convertirse en notas, embeberse, ni escribirse en los registros con su título, descripción o asistentes. Leer el calendario no SHALL modificar nada en él.

#### Scenario: Eventos leídos para una respuesta
- **WHEN** el asistente o el briefing leen los eventos de un usuario
- **THEN** después no queda ningún evento guardado en Synap ni su contenido en los registros

#### Scenario: El calendario no se modifica
- **WHEN** Synap lee el calendario de un usuario
- **THEN** ningún evento del calendario se crea, se cambia ni se borra

### Requirement: Qué se lee de un evento
De cada evento se SHALL leer su título, su inicio y su fin, si dura todo el día, su ubicación y su descripción. Los eventos recurrentes SHALL devolverse como sus ocurrencias concretas dentro del intervalo pedido. Los eventos cancelados y los que el usuario ha rechazado no SHALL devolverse. Los momentos SHALL presentarse en la zona horaria del usuario, y un evento de todo el día SHALL pertenecer al día de calendario en que está anotado, sin desplazarse por la zona horaria. Una lectura SHALL limitarse a un intervalo y a un número máximo de eventos que fija el sistema.

#### Scenario: Evento recurrente
- **WHEN** el usuario tiene una reunión que se repite todos los lunes y se leen los eventos de una semana
- **THEN** se devuelve la ocurrencia de ese lunes con su hora

#### Scenario: Evento de todo el día
- **WHEN** el usuario tiene un evento de todo el día el 14 de noviembre y está en `America/Mexico_City`
- **THEN** el evento pertenece al 14 de noviembre, no al 13 ni al 15

#### Scenario: Evento rechazado o cancelado
- **WHEN** el usuario ha rechazado una invitación o el evento está cancelado
- **THEN** ese evento no se devuelve

### Requirement: Un calendario que deja de responder no rompe nada
Cuando no se puede leer el calendario porque el acceso fue revocado, caducó o las credenciales dejaron de ser válidas, el sistema SHALL marcar la conexión como necesitada de reconexión, SHALL mostrarlo en Configuración, y el asistente y el briefing SHALL seguir funcionando sin eventos y diciéndolo. Cuando el proveedor no responde, SHALL tratarse como un fallo temporal que no marca la conexión. En ambos casos el fallo SHALL registrarse con su causa real, sin el contenido de ningún evento.

#### Scenario: Acceso revocado
- **WHEN** el usuario revocó el acceso de Synap desde su cuenta de Google y se intenta leer su calendario
- **THEN** la conexión queda marcada para reconectar, Configuración lo muestra, y la lectura falla sin impedir la respuesta o el briefing

#### Scenario: Proveedor caído
- **WHEN** el servidor del calendario no responde al leer eventos
- **THEN** la conexión no se marca para reconectar, el fallo se registra como proveedor inalcanzable, y la respuesta o el briefing siguen sin eventos

#### Scenario: Reconexión
- **WHEN** un usuario con la conexión marcada para reconectar vuelve a conectar su calendario
- **THEN** la marca desaparece y los eventos vuelven a leerse
