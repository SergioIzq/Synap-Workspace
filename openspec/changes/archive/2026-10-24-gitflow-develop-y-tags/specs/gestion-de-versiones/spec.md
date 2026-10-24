# Spec Delta

## Purpose

Define cómo se organizan las ramas de los repositorios de Synap (integración y producción), cómo se protegen y cómo cada paso a producción queda marcado con una versión SemVer a la que se puede hacer referencia.

## ADDED Requirements

### Requirement: Rama de integración separada de la de producción
Cada repositorio del workspace SHALL tener una rama de integración, `develop`, y una rama de producción, `main`. `develop` SHALL ser la rama por defecto del repositorio y la base de las ramas de trabajo, cuyas pull requests SHALL dirigirse a `develop`. `main` SHALL recibir cambios solo mediante una pull request desde `develop`, y la fusión de esa pull request SHALL ser el paso a producción. Los comandos del flujo de trabajo SHALL tomar ambas ramas de la configuración del workspace, no de valores fijos.

#### Scenario: Nueva rama de trabajo
- **WHEN** se empieza un change en un repositorio
- **THEN** su rama de trabajo se crea desde `develop` y su pull request apunta a `develop`

#### Scenario: Fusión en develop no llega a producción
- **WHEN** se fusiona una pull request en `develop`
- **THEN** no se publica ninguna imagen, no se despliega nada y no se crea ninguna versión

#### Scenario: Paso a producción
- **WHEN** se fusiona la pull request de `develop` a `main`
- **THEN** los cambios acumulados en `develop` llegan a `main` y se despliegan como hasta ahora

### Requirement: Las ramas de integración y producción están protegidas
`develop` y `main` SHALL rechazar el push directo, el borrado y la reescritura de historia, y SHALL aceptar cambios solo mediante pull request. [BACK] y [FRONT] SHALL exigir además que la comprobación de compilación y pruebas esté superada para fusionar en cualquiera de las dos. La protección SHALL nombrar las dos ramas explícitamente, de modo que cambiar la rama por defecto no deje a ninguna sin proteger. La pull request a `main` SHALL fusionarse conservando los commits de `develop` (sin aplastarlos ni reescribirlos), para que las dos ramas no diverjan.

#### Scenario: Push directo rechazado
- **WHEN** alguien intenta hacer push directo a `develop` o a `main`
- **THEN** el repositorio lo rechaza

#### Scenario: Comprobación fallida bloquea la fusión
- **WHEN** una pull request a `develop` o a `main` en [BACK] o [FRONT] tiene la comprobación en rojo
- **THEN** no se puede fusionar

#### Scenario: Fusión aplastada a main no permitida
- **WHEN** se intenta fusionar la pull request de `develop` a `main` aplastando sus commits
- **THEN** el repositorio no ofrece esa opción y solo permite la fusión con commit de merge

### Requirement: Las pull requests se comprueban en integración y en producción
[BACK] y [FRONT] SHALL ejecutar su comprobación de compilación y pruebas en cada pull request dirigida a `develop` o a `main`, con las mismas garantías que ya tiene la comprobación de pull requests (sin secretos de despliegue, sin publicar ni desplegar).

#### Scenario: Pull request a develop
- **WHEN** se abre o actualiza una pull request hacia `develop` en [BACK] o [FRONT]
- **THEN** se ejecuta la comprobación y su resultado aparece en la pull request

### Requirement: Cada paso a producción crea una versión SemVer
Cada vez que `main` recibe un commit, el repositorio SHALL crear automáticamente un tag con forma `vMAJOR.MINOR.PATCH` sobre ese commit, subiendo en uno el PATCH de la versión más alta existente. Si no existe ninguna versión, SHALL crear `v1.0.0`. Si el commit ya tiene una versión, SHALL NOT crear otra. Las subidas de MINOR o MAJOR SHALL hacerse a mano creando el tag correspondiente, y la siguiente versión automática SHALL partir de él. [BACK] y [FRONT] SHALL crear la versión solo cuando el despliegue de ese commit haya terminado bien, de modo que cada versión corresponda a algo que está en producción; si el despliegue falla, SHALL NOT crearla. Dos pasos a producción seguidos SHALL producir versiones distintas y consecutivas.

#### Scenario: Primera versión
- **WHEN** `main` recibe un commit en un repositorio sin ninguna versión
- **THEN** se crea el tag `v1.0.0` sobre ese commit

#### Scenario: Subida automática del patch
- **WHEN** `main` recibe un commit y la versión más alta es `v1.0.3`
- **THEN** se crea el tag `v1.0.4` sobre ese commit

#### Scenario: Subida manual del minor
- **WHEN** el operador crea a mano `v1.1.0` y después `main` recibe otro commit
- **THEN** se crea `v1.1.1`

#### Scenario: Despliegue fallido sin versión
- **WHEN** en [BACK] o [FRONT] falla el despliegue del commit recibido en `main`
- **THEN** no se crea ninguna versión para ese commit

#### Scenario: Reejecución sin duplicar
- **WHEN** se vuelve a ejecutar el proceso para un commit que ya tiene versión
- **THEN** no se crea ningún tag nuevo

#### Scenario: Una vuelta atrás no crea versión
- **WHEN** el operador redespliega a mano una versión anterior
- **THEN** no se crea ningún tag nuevo
