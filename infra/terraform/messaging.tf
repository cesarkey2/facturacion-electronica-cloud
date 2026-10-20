# Mensajería asíncrona: eventos de comprobantes y cola de mensajes fallidos (DLQ)

resource "google_pubsub_topic" "eventos" {
  name = "comprobantes-eventos"
}

resource "google_pubsub_topic" "dlq" {
  name = "comprobantes-dlq"
}

# Suscripción de lectura de la DLQ: permite inspeccionar y reprocesar mensajes fallidos
resource "google_pubsub_subscription" "dlq_lectura" {
  name                       = "sub-comprobantes-dlq"
  topic                      = google_pubsub_topic.dlq.id
  message_retention_duration = "604800s" # 7 días
}

# Entrega push a la función sincronizar-reportes, con reintentos y DLQ
resource "google_pubsub_subscription" "sync" {
  name                 = "sub-sincronizar-reportes"
  topic                = google_pubsub_topic.eventos.id
  ack_deadline_seconds = 60

  push_config {
    push_endpoint = google_cloudfunctions2_function.fn["sincronizar-reportes"].service_config[0].uri

    oidc_token {
      service_account_email = google_service_account.push.email
    }
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dlq.id
    max_delivery_attempts = 5
  }
}

data "google_project" "this" {
  project_id = var.project_id
}

locals {
  pubsub_agent = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# Permisos del agente de servicio de Pub/Sub para la DLQ y para firmar tokens OIDC
resource "google_pubsub_topic_iam_member" "dlq_agent_publisher" {
  topic  = google_pubsub_topic.dlq.name
  role   = "roles/pubsub.publisher"
  member = local.pubsub_agent
}

resource "google_pubsub_subscription_iam_member" "sync_agent_subscriber" {
  subscription = google_pubsub_subscription.sync.name
  role         = "roles/pubsub.subscriber"
  member       = local.pubsub_agent
}

resource "google_service_account_iam_member" "push_token_creator" {
  service_account_id = google_service_account.push.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = local.pubsub_agent
}
