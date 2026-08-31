# Desplegar Synap en el VPS (tarea 5.4)

Esto es lo que **tú** tienes que ejecutar contra tu VPS real (3 vCPU / 8 GB, sin GPU, ya sirviendo
otras webs — ver `openspec/changes/synap-mvp/design.md`). No pude hacerlo desde este entorno de
desarrollo: no hay Docker ni acceso a tu VPS aquí. Esto es el paso a paso exacto, no una promesa
de que ya está desplegado.

## 0. Antes de empezar

- [ ] Docker y Docker Compose instalados en el VPS.
- [ ] DNS de `synap.sergioizq.com` (o el subdominio que uses) apuntando al VPS.
- [ ] Revisa cuánta RAM/CPU están usando ya tus otras webs — el objetivo es confirmar que queda
      margen real antes de sumar Postgres + la API + el servicio de IA + el frontend.

## 1. Clonar los tres repos

```bash
git clone https://github.com/SergioIzq/Synap-Workspace.git synap
cd synap
git clone https://github.com/SergioIzq/Synap-Backend.git
git clone https://github.com/SergioIzq/Synap-Frontend.git
```

## 2. Configurar secretos

```bash
cp .env.example .env
```

Rellena en `.env`:
- `POSTGRES_PASSWORD` — contraseña nueva, no la de desarrollo local.
- `JWT_SECRET_KEY` y `INTERNAL_API_KEY` — genera cada una con `openssl rand -base64 48`. Son
  secretos distintos entre sí y distintos de cualquier valor usado en local.
- `GROQ_API_KEY` — puedes dejarlo vacío al principio; solo lo necesita el chat del asistente
  (`/api/assistant/ask`). Captura, búsqueda, embeddings y notas relacionadas funcionan sin él.

**Nunca comitees `.env`** (ya está en `.gitignore`).

## 3. Ajustar CORS al dominio real

`Synap-Backend/Synap.Api/Program.cs` tiene `builder.Services.AddKernelCors("synap.sergioizq.com")`
como placeholder — cámbialo por tu dominio real si es distinto, o el frontend no podrá llamar a
la API desde el navegador.

## 4. Levantar el stack

```bash
docker compose up --build -d
```

Verifica que arrancan los cuatro servicios:

```bash
docker compose ps
docker compose logs -f synap-api synap-ai
```

## 5. Aplicar las migraciones de base de datos

Las migraciones se generaron aquí pero **nunca se aplicaron** contra una Postgres real — hazlo
ahora, una vez el contenedor de `postgres` esté sano:

```bash
docker compose exec synap-api dotnet ef database update \
  --project /app  # ajusta si tu imagen publica los assemblies en otra ruta
```

Si la imagen de producción no incluye las herramientas de EF Core (probable, ya que
`Dockerfile` publica solo el runtime), aplica las migraciones desde tu máquina apuntando a la
Postgres del VPS (por ejemplo, abriendo un túnel SSH temporal al puerto 5432, o ejecutando
`dotnet ef database update` desde un contenedor efímero con el SDK que sí tenga red hacia el
`postgres` del VPS). El objetivo es simplemente que las tablas `users`, `notes`, `tags`,
`note_tags` y `note_embeddings` (con la extensión `vector`) existan antes del primer registro.

## 6. Comprobar recursos bajo carga ligera

Con el stack arriba y sin usuarios reales todavía:

```bash
docker stats
```

Confirma que, sumado a tus otras webs, sigues con margen — especialmente al generar unos
cuantos embeddings de prueba (`fastembed` carga el modelo ONNX en memoria una vez al arrancar
`synap-ai`, así que el pico de RAM de ese contenedor debería estabilizarse pronto tras el
arranque, no crecer sin límite).

## 7. Reverse proxy / TLS

Si ya tienes nginx (u otro) delante de tus webs actuales, añade un `server` para
`synap.sergioizq.com` → `synap-frontend` (puerto 4200 del host) y, si expones la API en un
subdominio propio, otro para la API → `synap-api` (puerto 8080 del host). `postgres` y
`synap-ai` deliberadamente no tienen puertos publicados en `docker-compose.yml` — no deben ser
alcanzables desde fuera del propio stack.

## 8. Cuando todo esto esté hecho

Sigue con `docs/smoke-test-checklist.md` (tarea 5.5) para la prueba de extremo a extremo.
