#!/usr/bin/env bash
# PR01 — Falla de la VM de backoffice: mide el tiempo de recuperación (RTO < 30 min).
# La VM ejecuta el contenedor con "--restart unless-stopped", por lo que debe volver sola al arrancar.
# Uso: ZONA=us-central1-a HEALTH_CMD='<comando que devuelve 0 si /health responde>' ./pr01-falla-vm.sh
set -euo pipefail
ZONA="${ZONA:-us-central1-a}"
VM="${VM:-vm-backoffice-01}"
: "${HEALTH_CMD:?Defina HEALTH_CMD, p. ej.: gcloud compute ssh bastion-vm --zone $ZONA --command 'curl -sf http://<IP_PRIVADA_VM>:8080/health'}"

marca() { echo "$(date -u +%H:%M:%S)  $*"; }

marca "Se detiene $VM (falla simulada)"
T0=$(date +%s)
gcloud compute instances stop "$VM" --zone "$ZONA" --quiet
marca "Se inicia $VM (recuperación)"
gcloud compute instances start "$VM" --zone "$ZONA" --quiet
until eval "$HEALTH_CMD" >/dev/null 2>&1; do sleep 5; done
T1=$(date +%s)
marca "Servicio restablecido (/health responde)"
echo "Tiempo de recuperación medido: $((T1 - T0)) s (objetivo RTO: 1800 s)"
