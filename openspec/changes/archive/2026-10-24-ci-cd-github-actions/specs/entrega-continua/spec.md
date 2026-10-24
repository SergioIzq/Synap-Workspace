# Spec Delta

## Purpose

Define cómo un cambio fusionado en la rama de producción se comprueba, se empaqueta y llega al servidor de producción sin intervención manual, y cómo se vuelve a una versión anterior si algo falla.

## ADDED Requirements

### Requirement: Los cambios se comprueban antes de fusionarse
Cada pull request hacia la rama de integración o hacia la de producción SHALL ejecutar de forma automática la compilación y las pruebas de su repositorio: [BACK] la compilación de la solución y las pruebas del servicio de IA que no necesitan red ni base de datos, [FRONT] la compilación de producción de la aplicación. El resultado SHALL ser visible en la propia pull request. La ejecución para una pull request SHALL NOT tener acceso a los secretos de despliegue ni publicar imágenes ni desplegar.

#### Scenario: Pull request que compila
- **WHEN** se abre una pull request cuyo código compila y cuyas pruebas pasan
- **THEN** la pull request muestra la comprobación como superada

#### Scenario: Pull request que no compila
- **WHEN** se abre una pull request cuyo código no compila o con una prueba que falla
- **THEN** la pull request muestra la comprobación como fallida y no se publica ni se despliega nada

#### Scenario: Pull request desde un fork
- **WHEN** una pull request procede de un fork
- **THEN** su ejecución no dispone de ningún secreto de despliegue

### Requirement: Cada fusión en la rama de producción publica imágenes versionadas
Cuando un cambio se fusiona en la rama de producción y la comprobación del repositorio es superada, el sistema SHALL construir las imágenes de los servicios de ese repositorio y publicarlas en un registro público, cada una con una etiqueta que identifique de forma única el commit y otra `latest` que apunte a la más reciente. [BACK] publica la imagen de la API y la del servicio de IA; [FRONT] publica la de la aplicación web. Las imágenes SHALL NOT contener secretos ni valores de configuración de producción.

#### Scenario: Fusión con comprobación superada
- **WHEN** se fusiona un cambio en [BACK] y su comprobación es superada
- **THEN** quedan publicadas las imágenes de la API y del servicio de IA con la etiqueta del commit y con `latest`

#### Scenario: Comprobación fallida
- **WHEN** la compilación o las pruebas del commit fusionado fallan
- **THEN** no se publica ninguna imagen nueva y `latest` sigue apuntando a la anterior

#### Scenario: Una imagen publicada no revela secretos
- **WHEN** se inspecciona una imagen publicada
- **THEN** no contiene claves, contraseñas ni el fichero de variables de entorno del servidor

### Requirement: El servidor ejecuta imágenes ya construidas
El stack del servidor SHALL poder arrancar cada servicio a partir de la imagen publicada, descargándola, sin compilar código en el servidor. La etiqueta de cada servicio SHALL poder fijarse por configuración y, si no se indica, ser `latest`. El mismo stack SHALL seguir pudiendo construirse en local a partir del código fuente.

#### Scenario: Actualizar sin compilar
- **WHEN** el servidor actualiza un servicio a la última imagen publicada
- **THEN** el servicio se reinicia con esa imagen y no se compila código en el servidor

#### Scenario: Fijar una etiqueta concreta
- **WHEN** la configuración del servidor fija la etiqueta de un servicio a la de un commit anterior
- **THEN** ese servicio arranca con la imagen de ese commit y los demás servicios no cambian

#### Scenario: Construcción local
- **WHEN** un desarrollador construye el stack en su máquina desde el código fuente
- **THEN** las imágenes se construyen localmente como antes

### Requirement: Cada fusión se despliega automáticamente
Tras publicar las imágenes de una fusión en la rama de producción, el sistema SHALL desplegarlas en el servidor de producción sin aprobación manual, siempre, incluidos los cambios que traen migraciones de base de datos. El despliegue SHALL actualizar únicamente los servicios del repositorio que cambió, y SHALL ejecutarse solo por una fusión en la rama de producción, nunca por una pull request. Para conectarse, SHALL usar una cuenta dedicada del servidor sin privilegios de administrador del sistema, con una credencial exclusiva para el despliegue que no esté en el repositorio ni en las imágenes.

#### Scenario: Despliegue tras una fusión en el back
- **WHEN** se fusiona un cambio en [BACK] y sus imágenes quedan publicadas
- **THEN** el servidor actualiza la API y el servicio de IA, y no toca la aplicación web ni la base de datos

#### Scenario: Despliegue tras una fusión en el front
- **WHEN** se fusiona un cambio en [FRONT] y su imagen queda publicada
- **THEN** el servidor actualiza la aplicación web, y no toca la API, el servicio de IA ni la base de datos

#### Scenario: Cambio con migraciones
- **WHEN** el cambio desplegado incluye migraciones de base de datos
- **THEN** se despliega igualmente sin aprobación manual y las migraciones se aplican al arrancar la API

#### Scenario: Una pull request no despliega
- **WHEN** se abre o se actualiza una pull request
- **THEN** no se produce ningún despliegue

### Requirement: Un despliegue solo se da por bueno si el servicio está sano
Tras actualizar los servicios, el sistema SHALL esperar a que la comprobación de salud de la plataforma informe de que está sana, con un tiempo máximo. Si no lo hace en ese tiempo, el despliegue SHALL darse por fallido, SHALL indicar qué servicio falla y SHALL NOT presentarse como correcto.

#### Scenario: El servicio arranca sano
- **WHEN** tras el despliegue la comprobación de salud informa de estado sano dentro del tiempo máximo
- **THEN** el despliegue se da por correcto

#### Scenario: El servicio no llega a estar sano
- **WHEN** tras el despliegue la comprobación de salud no informa de estado sano dentro del tiempo máximo
- **THEN** el despliegue se marca como fallido y se identifica el servicio que falla

### Requirement: Se puede volver a una versión anterior
El operador SHALL poder devolver un servicio a cualquier versión publicada anteriormente fijando su etiqueta y actualizando solo ese servicio, sin recompilar. Como las migraciones de base de datos solo avanzan, un cambio con migraciones SHALL ser compatible hacia atrás con la versión inmediatamente anterior de la aplicación, para que esta vuelta atrás sea segura.

#### Scenario: Volver a la versión anterior de la API
- **WHEN** el operador fija la etiqueta de la API a la del commit anterior y actualiza ese servicio
- **THEN** la API arranca con esa versión y el resto de servicios no se reinician

#### Scenario: Migración compatible hacia atrás
- **WHEN** se vuelve a la versión anterior de la aplicación tras haberse aplicado la migración más reciente
- **THEN** la versión anterior sigue funcionando con el esquema ya migrado

### Requirement: Existe una copia de seguridad reciente de los datos antes de migrar
El sistema SHALL mantener copias de seguridad automáticas de la base de datos de producción con una antigüedad máxima conocida, y SHALL conservarlas fuera del volumen de la base de datos, de modo que perder o recrear ese volumen no destruya las copias. Cada despliegue SHALL poder apoyarse en una copia anterior a las migraciones que aplique.

#### Scenario: Copia periódica
- **WHEN** transcurre el intervalo de copia configurado
- **THEN** existe una copia nueva de la base de datos con su fecha

#### Scenario: Despliegue con migraciones
- **WHEN** va a desplegarse un cambio con migraciones
- **THEN** existe una copia de la base de datos anterior al despliegue de antigüedad no superior a la máxima establecida

### Requirement: Los secretos de producción no salen del servidor
Las credenciales de producción de la aplicación (base de datos, claves de firma y de cifrado, claves internas, bot de mensajería, correo) SHALL residir solo en el servidor. Ni el código, ni las imágenes, ni las ejecuciones de CI SHALL contenerlas. El repositorio SHALL NOT contener el fichero de variables real, solo una plantilla con nombres.

#### Scenario: Repositorio público sin secretos
- **WHEN** se revisa el contenido de los repositorios y de las imágenes publicadas
- **THEN** no aparece ninguna credencial de producción

#### Scenario: Plantilla de variables
- **WHEN** un operador prepara un servidor nuevo
- **THEN** dispone de una plantilla con los nombres de las variables necesarias, sin valores reales
