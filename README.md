# Synap

Segundo cerebro personal: captura de notas, snippets de código y enlaces con fricción cero desde cualquier dispositivo (incluido iPhone sin Mac), búsqueda potente, y un asistente con IA que conecta tus notas entre sí y responde preguntas ancladas en tu propio contenido ("tengo este fallo, ¿cómo lo resolví la última vez?").

Este repo es el workspace de OpenSpec (specs, diseño técnico, tareas) más la orquestación (`docker-compose.yml`) del proyecto — **no contiene código de aplicación**. El código vive en dos repos hermanos:

- [Synap-Backend](https://github.com/SergioIzq/Synap-Backend) — API en .NET (DDD + Hexagonal + CQRS) + servicio de IA en Python (FastAPI)
- [Synap-Frontend](https://github.com/SergioIzq/Synap-Frontend) — PWA en Angular 21

## Por qué está separado así

Cada feature suele tocar backend y frontend a la vez, así que este workspace vive un nivel por encima de ambos repos para poder diseñarlos con visión de los dos simultáneamente — mientras que el código de cada app se versiona y despliega de forma independiente (igual que [Kash-Backend](https://github.com/SergioIzq/Kash-Backend)/[Kash-Frontend](https://github.com/SergioIzq/Kash-Frontend), el proyecto anterior de Sergio del que Synap hereda su arquitectura).

## Clonar el proyecto completo

```bash
git clone https://github.com/SergioIzq/Synap-Workspace.git Synap
cd Synap
git clone https://github.com/SergioIzq/Synap-Backend.git
git clone https://github.com/SergioIzq/Synap-Frontend.git
```

Quedan como tres repos independientes dentro de la misma carpeta `Synap/` (así es como ya está montado localmente).

## Levantar todo con Docker Compose

```bash
cp .env.example .env   # rellena POSTGRES_PASSWORD
docker compose up --build
```

Levanta Postgres (con `pgvector`), la API, el servicio de IA y el frontend — ver `docker-compose.yml`.

La web queda en http://localhost:4200 y llama a la API en el mismo origen (`/api`), igual que en producción. Aquí es el propio nginx del frontend quien reenvía `/api/` a `synap-api`, porque `docker-compose.yml` le define `SYNAP_API_UPSTREAM=http://synap-api:80`. En producción esa variable **no** se define: el proxy del VPS ya enruta `/api` y el contenedor solo sirve la SPA.

Efecto secundario en local: la API ve todas las peticiones como si vinieran del nginx del frontend (no está en `ForwardedHeaders__KnownProxies`), así que el límite de intentos de login por IP es compartido por todos los clientes que entren por el puerto 4200.

## Dónde está el porqué de cada decisión

Todo el razonamiento de arquitectura (por qué Postgres+pgvector, por qué IA híbrida local+free-tier, por qué el Atajo de iOS en vez de Share Target API, qué partes de los paquetes `SergioIzq.*.Kernel` se reutilizan y cuáles no...) está en:

```
openspec/changes/synap-mvp/proposal.md
openspec/changes/synap-mvp/design.md
openspec/changes/synap-mvp/specs/
openspec/changes/synap-mvp/tasks.md
```
