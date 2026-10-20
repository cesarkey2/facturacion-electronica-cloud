#!/usr/bin/env bash
# PR02 — SUNAT simulada no disponible: verifica reintentos del workflow y llegada a la DLQ.
# Uso: BASE_URL=https://<gateway> API_KEY=<clave> ./pr02-falla-sunat.sh
set -euo pipefail
: "${BASE_URL:?}"; : "${API_KEY:?}"
REGION="${REGION:-us-central1}"

echo "1) Se fuerza que enviar-sunat responda 503 siempre"
gcloud run services update enviar-sunat --region "$REGION" --update-env-vars SUNAT_FAIL_RATE=1 --quiet

echo "2) Se envían 5 comprobantes"
for i in 1 2 3 4 5; do
  curl -s -o /dev/null -w "  comprobante $i -> HTTP %{http_code}\n" -X POST "$BASE_URL/comprobantes" \
    -H "x-api-key: $API_KEY" -H "Content-Type: application/json" \
    -d "{\"tipoComprobante\":\"FACTURA\",\"serie\":\"F002\",\"numero\":\"$RANDOM\",\"ruc\":\"20123456789\",\"razonSocialEmisor\":\"Mi Pyme SAC\",\"cliente\":\"Prueba\",\"items\":[{\"descripcion\":\"Servicio\",\"cantidad\":1,\"precioUnitario\":100}],\"moneda\":\"PEN\",\"total\":118}"
done

echo "3) Se espera a que se agoten los reintentos del workflow (~2 min)"
sleep 120
echo "4) Mensajes en la DLQ:"
gcloud pubsub subscriptions pull sub-comprobantes-dlq --limit=5 --format="value(message.data)" | head -5

echo "5) Se restablece la SUNAT simulada"
gcloud run services update enviar-sunat --region "$REGION" --update-env-vars SUNAT_FAIL_RATE=0 --quiet
echo "Nota: el cambio manual de la variable genera 'drift' en Terraform; 'terraform apply' lo corrige."
