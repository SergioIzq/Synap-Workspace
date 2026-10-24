# Spec Delta

## ADDED Requirements

### Requirement: Un recordatorio creado a partir de un evento es un recordatorio ordinario
Un recordatorio creado a partir de un evento del calendario SHALL guardarse como cualquier otro: su texto, un momento fijo en UTC calculado al crearlo y, opcionalmente, una nota. No SHALL guardar ninguna referencia al evento ni ningún dato suyo más allá de lo que el usuario puso en el texto. Si el evento cambia de hora o se borra después, el recordatorio no SHALL cambiar. Se SHALL poder ver, editar, cancelar, confirmar y posponer como cualquier otro, aunque el calendario se desconecte.

#### Scenario: El evento se mueve
- **WHEN** el evento al que se ancló un recordatorio se mueve a otra hora
- **THEN** el recordatorio se sigue entregando en el momento calculado al crearlo

#### Scenario: Visible en Recordatorios
- **WHEN** un usuario abre la sección "Recordatorios" tras crear uno a partir de un evento
- **THEN** aparece con su texto y su momento como cualquier otro recordatorio pendiente, y puede editarlo o cancelarlo
