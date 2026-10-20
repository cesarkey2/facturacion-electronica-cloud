# Identidades y permisos de mínimo privilegio (Capítulo 7.2 del informe)

resource "google_service_account" "backoffice" {
  account_id   = "sa-backoffice"
  display_name = "Cuenta de servicio de la VM backoffice"
}

resource "google_service_account" "functions" {
  account_id   = "sa-functions"
  display_name = "Cuenta de servicio de las Cloud Run functions"
}

locals {
  backoffice_roles = [
    "roles/cloudsql.client",
    "roles/artifactregistry.reader",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ]
}

resource "google_project_iam_member" "backoffice" {
  for_each = toset(local.backoffice_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.backoffice.email}"
}

# Solo la VM de backoffice puede leer la contraseña de la base de datos
resource "google_secret_manager_secret_iam_member" "backoffice_db_password" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.backoffice.email}"
}

# Funciones del flujo: firmar con la llave KMS y escribir en sus buckets (el estado en Firestore lo escribe el workflow)
resource "google_kms_crypto_key_iam_member" "functions_sign" {
  crypto_key_id = google_kms_crypto_key.firma.id
  role          = "roles/cloudkms.signerVerifier"
  member        = "serviceAccount:${google_service_account.functions.email}"
}

resource "google_storage_bucket_iam_member" "functions_xml" {
  bucket = google_storage_bucket.comprobantes_xml.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.functions.email}"
}

resource "google_storage_bucket_iam_member" "functions_pdf" {
  bucket = google_storage_bucket.comprobantes_pdf.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.functions.email}"
}


# ---------------------------------------------------------------------------
# Identidades de la capa serverless (APF3)
# ---------------------------------------------------------------------------
resource "google_service_account" "workflow" {
  account_id   = "sa-workflow"
  display_name = "Cloud Workflows: invoca funciones y publica eventos"
}

resource "google_service_account" "api" {
  account_id   = "sa-api"
  display_name = "Función api-emision: inicia ejecuciones del workflow"
}

resource "google_service_account" "sync" {
  account_id   = "sa-sync"
  display_name = "Función sincronizar-reportes: escribe en Cloud SQL"
}

resource "google_service_account" "gateway" {
  account_id   = "sa-gateway"
  display_name = "API Gateway: invoca la función api-emision"
}

resource "google_service_account" "push" {
  account_id   = "sa-push"
  display_name = "Pub/Sub push: invoca la función sincronizar-reportes"
}

resource "google_project_iam_member" "workflow_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.workflow.email}"
}

resource "google_project_iam_member" "workflow_logs" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.workflow.email}"
}

resource "google_pubsub_topic_iam_member" "workflow_publica_eventos" {
  topic  = google_pubsub_topic.eventos.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${google_service_account.workflow.email}"
}

resource "google_pubsub_topic_iam_member" "workflow_publica_dlq" {
  topic  = google_pubsub_topic.dlq.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${google_service_account.workflow.email}"
}

# Simplificación académica: permiso a nivel de proyecto (mejora: restringirlo al workflow)
resource "google_project_iam_member" "api_workflows" {
  project = var.project_id
  role    = "roles/workflows.invoker"
  member  = "serviceAccount:${google_service_account.api.email}"
}

resource "google_secret_manager_secret_iam_member" "sync_db_password" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.sync.email}"
}
