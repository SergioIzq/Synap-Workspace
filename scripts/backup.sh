#!/usr/bin/env bash
# Copia de seguridad de la base de datos de Synap (pg_dump comprimido).
#
#   scripts/backup.sh [daily|predeploy]
#
# daily (por defecto) la lanza el cron diario del VPS; predeploy, scripts/deploy.sh antes de
# reiniciar synap-api. Deja <tipo>-<fecha UTC>.sql.gz en SYNAP_BACKUP_DIR, fuera del volumen de
# Postgres, y borra las de ese mismo tipo con más de 7 días solo si la copia nueva es válida.
# Sale con error si postgres no está en marcha o si el volcado falla, sale vacío o incompleto.
#
# Variables opcionales: SYNAP_BACKUP_DIR (/var/backups/synap).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
backup_dir="${SYNAP_BACKUP_DIR:-/var/backups/synap}"
kind="${1:-daily}"

fail() { echo "backup: $*" >&2; exit 1; }

case "$kind" in
  daily|predeploy) ;;
  *) fail "uso: backup.sh [daily|predeploy]" ;;
esac

cd "$root"
[ -n "$(docker compose ps --status running -q postgres)" ] || fail "postgres no está en marcha"

# El volcado contiene datos de los usuarios: solo lo lee su dueño.
umask 077
mkdir -p "$backup_dir"
file="$backup_dir/$kind-$(date -u +%Y%m%dT%H%M%SZ).sql.gz"
# Se escribe aparte y se renombra al final: nunca queda a la vista una copia a medias.
tmp="$file.partial"
trap 'rm -f "$tmp"' EXIT

# Las variables POSTGRES_* ya existen dentro del contenedor, no hace falta leerlas aquí.
docker compose exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' | gzip > "$tmp" \
  || fail "no se pudo hacer la copia de la base de datos"
# pg_dump escribe esta marca al terminar: si falta, el volcado está cortado.
gunzip -c "$tmp" | tail -n 5 | grep -q 'PostgreSQL database dump complete' \
  || fail "la copia salió vacía o incompleta"

mv "$tmp" "$file"
trap - EXIT
echo "backup: copia en $file"
find "$backup_dir" -name "$kind-*.sql.gz" -mtime +7 -delete
