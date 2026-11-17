#!/bin/bash
# Respaldo periódico de MongoDB con retención. Corre dentro del servicio "backup" del compose.
set -u

INTERVAL_HOURS="${BACKUP_INTERVAL_HOURS:-24}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"
DIR="${BACKUP_DIR:-/backups}"

mkdir -p "$DIR"

while true; do
  FILE="$DIR/carwash-$(date +%Y%m%d-%H%M%S).archive.gz"
  echo "[backup] $(date -Is) iniciando -> $FILE"
  if mongodump --uri="$MONGO_URI" --gzip --archive="$FILE"; then
    echo "[backup] OK ($(du -h "$FILE" | cut -f1))"
  else
    echo "[backup] ERROR: mongodump falló" >&2
    rm -f "$FILE"   # no dejar respaldos corruptos a medias
  fi

  # Retención: borra respaldos más viejos que RETENTION_DAYS
  find "$DIR" -name 'carwash-*.archive.gz' -mtime "+$RETENTION_DAYS" -print -delete

  sleep "$((INTERVAL_HOURS * 3600))"
done
