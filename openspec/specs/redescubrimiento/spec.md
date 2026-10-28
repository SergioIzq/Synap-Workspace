# redescubrimiento Specification

## Purpose

Evita que el conocimiento capturado se pierda de vista: conecta cada nota con las demás notas del usuario que tratan de lo mismo, se lo hace saber al capturar y detecta las notas que llevan tiempo sin consultarse para traerlas de vuelta cuando vuelven a importar.

## Requirements

### Requirement: Conexiones de una nota
El sistema SHALL permitir a un usuario autenticado consultar las conexiones de una de sus notas: las otras notas suyas cuyo sentido se parece al de ella lo bastante para superar un umbral de relevancia que fija el sistema, ordenadas de más a menos parecidas, como mucho un número que fija el sistema y sin incluir la propia nota. Cada conexión SHALL identificarse por su título o, si no lo tiene, por un fragmento de su texto. Cuando la nota aún no ha terminado de analizarse, la respuesta SHALL decirlo, en lugar de responder como una nota sin conexiones. Cuando al menos dos conexiones comparten una etiqueta, la respuesta SHALL nombrar como tema común la etiqueta que llevan más conexiones; si ninguna etiqueta la comparten al menos dos de ellas, no SHALL nombrar ninguna.

#### Scenario: Nota con conexiones
- **WHEN** un usuario consulta las conexiones de su nota sobre Helm y tiene tres notas sobre Kubernetes que se le parecen lo bastante
- **THEN** recibe esas tres notas, de la más parecida a la menos, sin la nota de Helm

#### Scenario: Notas poco parecidas no son conexiones
- **WHEN** las notas más parecidas a una nota no llegan al umbral de relevancia
- **THEN** la nota no tiene conexiones, en lugar de mostrar las menos alejadas

#### Scenario: Nota aún sin analizar
- **WHEN** un usuario consulta las conexiones de una nota que acaba de crear y cuyo análisis no ha terminado
- **THEN** la respuesta indica que el análisis está pendiente, sin conexiones, y no la presenta como una nota sin relación con nada

#### Scenario: Tema común
- **WHEN** tres de las cuatro conexiones de una nota llevan la etiqueta "kubernetes"
- **THEN** la respuesta nombra "kubernetes" como tema común

#### Scenario: Sin tema común
- **WHEN** ninguna etiqueta la llevan al menos dos de las conexiones
- **THEN** la respuesta no nombra ningún tema

#### Scenario: Más conexiones de las que se muestran
- **WHEN** más notas de las que fija el sistema superan el umbral
- **THEN** solo se devuelven las más parecidas, hasta ese número

#### Scenario: Las conexiones nunca cruzan usuarios
- **WHEN** un usuario consulta las conexiones de una de sus notas
- **THEN** solo recibe notas suyas, por parecidas que sean las de otros usuarios

#### Scenario: Nota ajena o inexistente
- **WHEN** un usuario consulta las conexiones de una nota que no existe o es de otro usuario
- **THEN** el sistema responde que la nota no se encontró, sin revelar si existe

#### Scenario: Servicio de análisis no disponible
- **WHEN** el servicio que compara notas no responde
- **THEN** la consulta falla con un mensaje en español y el resto de la nota sigue pudiéndose consultar

### Requirement: Aviso de conexiones al capturar desde la web
Cuando un usuario crea una nota desde la aplicación web, la aplicación SHALL buscar sus conexiones en segundo plano, esperando a que termine su análisis durante un tiempo acotado que fija el sistema, y SHALL avisar sin bloquear de cuántas notas suyas se relaciona, nombrando el tema común cuando lo hay, con una acción para abrir la nota recién creada. No SHALL avisar cuando no hay conexiones, cuando el análisis no termina dentro de ese tiempo ni cuando la búsqueda falla; en ningún caso SHALL retrasar ni deshacer la creación de la nota. Editar una nota existente no SHALL producir el aviso.

#### Scenario: Captura con conexiones
- **WHEN** un usuario guarda desde la web una nota sobre Helm y tiene tres notas relacionadas con la etiqueta "kubernetes"
- **THEN** la nota se crea como siempre y, poco después, aparece un aviso no bloqueante «Se relaciona con 3 notas tuyas sobre #kubernetes» con una acción para abrirla

#### Scenario: Captura sin tema común
- **WHEN** las conexiones de la nota recién creada no comparten etiqueta
- **THEN** el aviso dice de cuántas notas se relaciona, sin nombrar tema

#### Scenario: Captura sin conexiones
- **WHEN** un usuario guarda una nota que no se relaciona con ninguna otra
- **THEN** no aparece ningún aviso

#### Scenario: El análisis tarda demasiado
- **WHEN** el análisis de la nota no termina dentro del tiempo que espera la aplicación
- **THEN** no aparece ningún aviso, y las conexiones se pueden ver más tarde en el detalle de la nota

#### Scenario: La búsqueda falla
- **WHEN** la búsqueda de conexiones falla tras crear la nota
- **THEN** no aparece ningún aviso de error por ello, y la nota está creada

#### Scenario: Abrir desde el aviso
- **WHEN** el usuario usa la acción del aviso
- **THEN** se abre el detalle de la nota recién creada, con sus conexiones

#### Scenario: Editar no avisa
- **WHEN** un usuario guarda cambios en una nota existente
- **THEN** no aparece ningún aviso de conexiones

### Requirement: Conexiones en el detalle de una nota
El detalle de una nota en la aplicación web SHALL mostrar sus conexiones, cada una enlazada a su nota e identificada por su título o, sin título, por un fragmento de su texto. Cuando la nota aún no ha terminado de analizarse, la aplicación SHALL volver a consultarlas durante un tiempo acotado antes de darse por vencida. El bloque SHALL omitirse cuando la nota no tiene conexiones, cuando el análisis no termina a tiempo o cuando la consulta falla, sin impedir ver ni editar la nota. Mientras se edita la nota, el bloque no SHALL mostrarse.

#### Scenario: Detalle con conexiones
- **WHEN** un usuario abre una nota que tiene conexiones
- **THEN** el detalle muestra un bloque con ellas, cada una enlazada a su nota

#### Scenario: Detalle de una nota recién creada
- **WHEN** un usuario abre una nota recién creada cuyo análisis termina pocos segundos después
- **THEN** el bloque de conexiones aparece al terminar el análisis, sin recargar la página

#### Scenario: Detalle sin conexiones
- **WHEN** un usuario abre una nota sin conexiones
- **THEN** no aparece ningún bloque de conexiones, ni vacío ni con notas por debajo del umbral

#### Scenario: Ir a una conexión
- **WHEN** el usuario sigue el enlace de una conexión
- **THEN** se abre el detalle de esa nota con sus propias conexiones

### Requirement: Actividad de una nota
El sistema SHALL registrar, para cada nota, el momento en que su dueño la abrió por última vez en la aplicación web, aparte del momento en que la editó por última vez. Abrir el detalle de una nota SHALL contar como abrirla; que la nota aparezca en un listado, una búsqueda, una respuesta del asistente, una lectura del asistente o un briefing no SHALL contar. Registrar una apertura no SHALL cambiar el momento de la última edición, el estado de la nota ni su contenido. La última actividad de una nota SHALL ser el más reciente de su creación, su última edición y su última apertura. Solo el dueño de una nota SHALL poder registrar su apertura.

#### Scenario: Abrir una nota cuenta como actividad
- **WHEN** un usuario abre el detalle de una nota que creó hace dos meses y no ha editado
- **THEN** su última actividad pasa a ser ese momento

#### Scenario: Abrir no es editar
- **WHEN** un usuario abre una nota sin cambiarla
- **THEN** el momento de su última edición, su estado y su contenido no cambian

#### Scenario: Lo que no cuenta como abrir
- **WHEN** una nota aparece en el listado, en una búsqueda, entre las fuentes de una respuesta, en una lectura del asistente o en un briefing
- **THEN** su última actividad no cambia

#### Scenario: Nota ajena o inexistente
- **WHEN** un usuario registra la apertura de una nota que no existe o es de otro usuario
- **THEN** el sistema responde que la nota no se encontró, sin revelar si existe, y no cambia nada

### Requirement: Notas dormidas
Una nota SHALL considerarse dormida cuando no lleva estado y su última actividad es anterior a un periodo que fija el sistema. Una nota con estado, sea cual sea, no SHALL considerarse dormida: el trabajo marcado tiene sus propias secciones en el briefing.

#### Scenario: Nota sin tocar durante el periodo
- **WHEN** una nota sin estado no se ha abierto ni editado desde hace más del periodo que fija el sistema
- **THEN** está dormida

#### Scenario: Nota abierta hace poco
- **WHEN** una nota sin estado se creó hace meses pero se abrió la semana pasada
- **THEN** no está dormida

#### Scenario: Nota con estado
- **WHEN** una nota pendiente, en desarrollo, pausada o completada no se ha tocado en meses
- **THEN** no está dormida

### Requirement: Rescate de notas dormidas relacionadas con lo reciente
El sistema SHALL poder elegir, para un usuario, las notas dormidas que se relacionan con lo que ha creado o editado recientemente: una nota dormida es rescatable cuando su sentido se parece, por encima del mismo umbral de relevancia que las conexiones, al de alguna nota suya creada o editada dentro de un periodo reciente que fija el sistema. Cada nota rescatada SHALL ir acompañada de la nota reciente que más se le parece, como motivo de que vuelva ahora. El sistema SHALL elegir como mucho un número que fija el sistema, empezando por las más parecidas a su motivo. Una nota rescatada y mostrada al usuario no SHALL volver a rescatarse hasta pasado un periodo que fija el sistema, aunque siga dormida. Una nota dormida que no se relaciona con nada reciente no SHALL rescatarse: traer de vuelta notas al azar es ruido.

#### Scenario: Nota dormida relacionada con algo reciente
- **WHEN** un usuario escribió ayer una nota sobre Helm y tiene una nota sobre Kubernetes que no toca desde hace dos meses y que se le parece lo bastante
- **THEN** la nota sobre Kubernetes es rescatable, con la nota sobre Helm como motivo

#### Scenario: Nota dormida sin relación con lo reciente
- **WHEN** una nota dormida no se parece lo bastante a ninguna nota creada o editada recientemente
- **THEN** no se rescata

#### Scenario: Sin actividad reciente
- **WHEN** un usuario no ha creado ni editado ninguna nota dentro del periodo reciente
- **THEN** no se rescata ninguna nota

#### Scenario: Varias notas recientes como motivo
- **WHEN** una nota dormida se parece a dos notas recientes
- **THEN** se rescata una sola vez, con la más parecida como motivo

#### Scenario: Más notas rescatables de las que se muestran
- **WHEN** hay más notas rescatables que el número que fija el sistema
- **THEN** se eligen las más parecidas a su motivo

#### Scenario: No se repite cada día
- **WHEN** una nota se rescató y se mostró al usuario ayer, y sigue dormida
- **THEN** hoy no vuelve a rescatarse, ni lo hará hasta pasado el periodo que fija el sistema

#### Scenario: Abrir la nota rescatada la despierta
- **WHEN** el usuario abre la nota rescatada
- **THEN** deja de estar dormida y no vuelve a rescatarse mientras no vuelva a dormirse

#### Scenario: El rescate nunca cruza usuarios
- **WHEN** el sistema elige notas dormidas para un usuario
- **THEN** tanto las notas rescatadas como sus motivos son notas de ese usuario
