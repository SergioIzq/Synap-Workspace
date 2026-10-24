# Spec Delta

## ADDED Requirements

### Requirement: Sección "Calendario" en Configuración
La página de Configuración SHALL incluir una sección "Calendario" que muestre si hay un calendario conectado y, si lo hay, el proveedor, la cuenta conectada, desde cuándo y si necesita reconectarse. Sin calendario conectado SHALL ofrecer conectar Google Calendar (solo cuando el despliegue lo permite) y conectar un calendario CalDAV con un formulario de URL, usuario y contraseña que explique que conviene una contraseña de aplicación. Con un calendario conectado SHALL ofrecer reconectarlo y desconectarlo, y la desconexión SHALL pedir confirmación. Todos los mensajes SHALL estar en español.

#### Scenario: Sin calendario
- **WHEN** un usuario sin calendario conectado abre Configuración
- **THEN** la sección "Calendario" ofrece conectar Google Calendar y conectar un calendario CalDAV

#### Scenario: Calendario conectado
- **WHEN** un usuario con Google conectado abre Configuración
- **THEN** la sección muestra Google, la cuenta conectada y desde cuándo, con opciones para reconectar y desconectar

#### Scenario: Necesita reconectarse
- **WHEN** la conexión de un usuario está marcada para reconectar
- **THEN** la sección lo indica de forma visible y ofrece reconectar

#### Scenario: Vuelta del consentimiento de Google
- **WHEN** un usuario vuelve a Configuración tras el consentimiento de Google
- **THEN** ve una notificación en español de que el calendario se conectó, o de por qué no se conectó

#### Scenario: Desconexión confirmada
- **WHEN** un usuario pulsa desconectar el calendario
- **THEN** se le pide confirmación antes de desconectarlo
