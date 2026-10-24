#!/usr/bin/env bash
# Despliega servicios de Synap con las imágenes publicadas de un commit.
#
#   scripts/deploy.sh <servicio...> <sha>
#
# Servicios admitidos: synap-api, synap-ai, synap-frontend. <sha> es el SHA completo (40 hex).
# Es también el único comando que puede ejecutar la clave SSH de CI (`command=` en authorized_keys):
# en ese caso los argumentos llegan en SSH_ORIGINAL_COMMAND y se validan igual.
#
# Qué hace: copia previa de la base de datos (solo si incluye synap-api), fija los tags en .env,
# descarga las imágenes, reinicia únicamente esos servicios y espera a que estén healthy.
# Sale con error si algo falla o si un servicio no llega a healthy dentro de SYNAP_DEPLOY_TIMEOUT.
#
# Variables opcionales: SYNAP_DEPLOY_TIMEOUT (segundos, 180), SYNAP_BACKUP_DIR (/var/backups/synap).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
timeout="${SYNAP_DEPLOY_TIMEOUT:-180}"
backup_dir="${SYNAP_BACKUP_DIR:-/var/backups/synap}"

fail() { echo "deploy: $*" >&2; exit 1; }

if [ "$#" -eq 0 ] && [ -n "${SSH_ORIGINAL_COMMAND:-}" ]; then
  # shellcheck disable=SC2086  # separar por espacios es lo que se busca; cada palabra se valida abajo
  set -- $SSH_ORIGINAL_COMMAND
fi
[ "$#" -ge 2 ] || fail "uso: deploy.sh <servicio...> <sha>"

sha="${!#}"
services=("${@:1:$#-1}")

[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || fail "el sha debe tener 40 caracteres hexadecimales en minúscula"

tag_var() {
  case "$1" in
    synap-api) echo SYNAP_API_TAG ;;
    synap-ai) echo SYNAP_AI_TAG ;;
    synap-frontend) echo SYNAP_FRONTEND_TAG ;;
    *) return 1 ;;
  esac
}
for service in "${services[@]}"; do
  tag_var "$service" >/dev/null || fail "servicio no admitido: $service"
done

cd "$root"
[ -f .env ] || fail "no existe $root/.env"

# Un despliegue cada vez, también entre repos (back y front comparten servidor).
# El bloqueo se toma sobre este mismo fichero, en solo lectura: no exige permisos de escritura.
exec 9<"$root/scripts/deploy.sh"
flock -w 600 9 || fail "otro despliegue sigue en curso"

backup_database() {
  if [ -z "$(docker compose ps --status running -q postgres)" ]; then
    echo "deploy: postgres no está en marcha, se omite la copia previa" >&2
    return 0
  fi
  SYNAP_BACKUP_DIR="$backup_dir" "$root/scripts/backup.sh" predeploy \
    || fail "no se pudo hacer la copia previa de la base de datos"
}

set_env_tag() {
  local var="$1" value="$2" tmp
  tmp="$(mktemp)"
  # Se reescribe el contenido de .env en sitio (no se sustituye el fichero) para conservar dueño y permisos.
  { grep -v "^${var}=" .env || true; echo "${var}=${value}"; } > "$tmp"
  cat "$tmp" > .env
  rm -f "$tmp"
}

wait_healthy() {
  local service="$1" deadline=$((SECONDS + timeout)) id status
  while [ "$SECONDS" -lt "$deadline" ]; do
    id="$(docker compose ps -q "$service")"
    status="$([ -n "$id" ] && docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$id" || echo missing)"
    case "$status" in
      healthy) echo "deploy: $service healthy"; return 0 ;;
      unhealthy|exited|dead|missing)
        docker compose logs --tail 40 "$service" >&2 || true
        fail "$service no está sano ($status)" ;;
    esac
    sleep 3
  done
  docker compose logs --tail 40 "$service" >&2 || true
  fail "$service no llegó a healthy en ${timeout}s"
}

for service in "${services[@]}"; do
  if [ "$service" = synap-api ]; then backup_database; fi
done

for service in "${services[@]}"; do
  set_env_tag "$(tag_var "$service")" "$sha"
done

docker compose pull "${services[@]}"
docker compose up -d --no-build --no-deps "${services[@]}"

for service in "${services[@]}"; do
  wait_healthy "$service"
done
echo "deploy: ${services[*]} en $sha"
