#!/usr/bin/env bash
# PR03 — Recuperación de Cloud SQL a un punto en el tiempo (PITR): valida el RPO (< 15 min).
# Uso: PUNTO='2026-10-10T15:00:00Z' ./pr03-restaurar-pitr.sh   (un instante dentro del periodo de retención)
set -euo pipefail
: "${PUNTO:?Defina PUNTO en formato UTC, p. ej. 2026-10-10T15:00:00Z}"
ORIGEN="cloud-sql-facturacion"; DESTINO="cloud-sql-restauracion"

T0=$(date +%s)
gcloud sql instances clone "$ORIGEN" "$DESTINO" --point-in-time "$PUNTO"
T1=$(date +%s)
echo "Clon creado a partir de $PUNTO en $((T1 - T0)) s"
echo "Verifique los datos del clon y luego elimínelo para no generar costo:"
echo "  gcloud sql instances delete $DESTINO --quiet"
