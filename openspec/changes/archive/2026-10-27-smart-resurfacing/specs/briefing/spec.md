# Spec Delta

## ADDED Requirements

### Requirement: El briefing rescata notas dormidas
El briefing SHALL incluir una sección «Para retomar» con las notas dormidas que el sistema rescata para el usuario en ese momento (specs `redescubrimiento`, «Rescate de notas dormidas relacionadas con lo reciente»). Cada nota SHALL identificarse por su título o, si no lo tiene, por un fragmento de su texto, y SHALL decir cuánto tiempo lleva sin abrirse ni editarse y con qué nota reciente se relaciona. La sección SHALL ser la última del briefing, SHALL omitirse cuando no hay nada que rescatar y, como mucho, SHALL mostrar el número de notas que fija el sistema. Las notas rescatadas SHALL contar como contenido: un día con notas para retomar y nada más no es un día vacío. Cuando un briefing con la sección se entrega, sus notas SHALL quedar registradas como mostradas, de modo que no vuelvan a rescatarse hasta pasado el periodo que fija el sistema; un briefing que no llega a entregarse no SHALL registrarlas. Esto SHALL aplicarse igual al briefing automático y al pedido bajo demanda. Que una nota aparezca en el briefing no SHALL contar como abrirla.

#### Scenario: Notas para retomar
- **WHEN** un usuario tiene una nota dormida sobre Kubernetes relacionada con la nota sobre Helm que escribió ayer
- **THEN** el briefing incluye una sección «Para retomar» con la nota de Kubernetes, cuánto lleva sin tocarse y que se relaciona con la nota de Helm

#### Scenario: Nada que retomar
- **WHEN** ninguna nota dormida del usuario se relaciona con lo reciente
- **THEN** la sección «Para retomar» no aparece y el resto del briefing no cambia

#### Scenario: Solo notas para retomar
- **WHEN** a la hora elegida un usuario no tiene nada más que contar que notas para retomar
- **THEN** el briefing se envía con esa sección

#### Scenario: La sección va al final
- **WHEN** un briefing tiene notas para retomar y otras secciones
- **THEN** la sección «Para retomar» aparece después de todas las demás

#### Scenario: No se repiten al día siguiente
- **WHEN** un briefing entregado ayer mostró una nota para retomar que sigue dormida
- **THEN** el briefing de hoy no la vuelve a mostrar

#### Scenario: Un briefing no entregado no consume el rescate
- **WHEN** la entrega de un briefing con notas para retomar falla
- **THEN** esas notas no quedan registradas como mostradas y el siguiente intento puede volver a incluirlas

#### Scenario: Pedido bajo demanda
- **WHEN** un usuario pide su briefing y tiene notas para retomar
- **THEN** el briefing incluye la sección y, al entregarse, esas notas quedan registradas como mostradas

#### Scenario: Aparecer no es abrir
- **WHEN** una nota aparece en la sección «Para retomar»
- **THEN** sigue dormida hasta que el usuario la abra o la edite

#### Scenario: El análisis no está disponible
- **WHEN** el servicio que compara notas no responde al construir el briefing
- **THEN** el briefing se construye y se envía sin la sección «Para retomar», sin aviso, y sus notas no quedan registradas como mostradas
