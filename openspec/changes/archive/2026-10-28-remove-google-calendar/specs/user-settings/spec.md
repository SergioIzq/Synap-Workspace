## ADDED Requirements

### Requirement: Sección "Calendario" con conexión CalDAV
La página de Configuración SHALL incluir una sección "Calendario" que muestre si hay un calendario conectado y, si lo hay, la cuenta conectada, desde cuándo y si necesita reconectarse. Sin calendario conectado SHALL ofrecer conectar un calendario CalDAV con un formulario de URL, usuario y contraseña que explique que conviene una contraseña de aplicación. No SHALL ofrecer conectar Google Calendar. Con un calendario conectado SHALL ofrecer reconectarlo y desconectarlo, y la desconexión SHALL pedir confirmación. El estado que muestra la sección SHALL ser el que devuelve la API, y todos los mensajes SHALL estar en español.

#### Scenario: Sin calendario
- **WHEN** un usuario sin calendario conectado abre Configuración
- **THEN** la sección "Calendario" ofrece conectar un calendario CalDAV y no muestra ninguna opción de Google

#### Scenario: Calendario conectado
- **WHEN** un usuario con un calendario CalDAV conectado abre Configuración
- **THEN** la sección muestra la cuenta conectada y desde cuándo, con opciones para reconectar y desconectar

#### Scenario: Conexión recién hecha
- **WHEN** un usuario conecta un calendario CalDAV válido desde la sección
- **THEN** la sección pasa a mostrarlo como conectado con su cuenta, sin recargar la página

#### Scenario: Necesita reconectarse
- **WHEN** la conexión de un usuario está marcada para reconectar
- **THEN** la sección lo indica de forma visible y ofrece reconectar

#### Scenario: Desconexión confirmada
- **WHEN** un usuario pulsa desconectar el calendario
- **THEN** se le pide confirmación antes de desconectarlo

## REMOVED Requirements

### Requirement: Sección "Calendario" en Configuración
**Reason**: Ofrecía conectar Google Calendar y notificaba la vuelta de su consentimiento, que desaparecen con el proveedor. Lo sustituye "Sección "Calendario" con conexión CalDAV".
**Migration**: Ninguna: la sección sigue en el mismo sitio y la conexión CalDAV no cambia.
