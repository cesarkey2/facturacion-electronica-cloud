# Observabilidad (Capítulo 9): alertas, uptime check, métrica de negocio y dashboard

resource "google_monitoring_notification_channel" "correo" {
  display_name = "Correo del equipo"
  type         = "email"

  labels = {
    email_address = var.alert_email
  }
}

# Métrica basada en logs: CDR aceptados (métrica de negocio)
resource "google_logging_metric" "cdr_aceptados" {
  name   = "cdr_aceptados"
  filter = "resource.type=\"cloud_run_revision\" AND jsonPayload.evento=\"cdr_aceptado\""

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}

resource "google_monitoring_alert_policy" "errores_5xx" {
  display_name = "Funciones: errores 5xx"
  combiner     = "OR"

  conditions {
    display_name = "Más de 5 respuestas 5xx en 5 minutos"
    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_count\" AND metric.labels.response_code_class=\"5xx\""
      comparison      = "COMPARISON_GT"
      threshold_value = 5
      duration        = "0s"

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.correo.id]
}

resource "google_monitoring_alert_policy" "latencia_p95" {
  display_name = "Funciones: latencia p95 > 5 s"
  combiner     = "OR"

  conditions {
    display_name = "p95 de latencia mayor a 5000 ms"
    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_latencies\""
      comparison      = "COMPARISON_GT"
      threshold_value = 5000
      duration        = "300s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_PERCENTILE_95"
        cross_series_reducer = "REDUCE_MAX"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.correo.id]
}

resource "google_monitoring_alert_policy" "dlq_con_mensajes" {
  display_name = "Pub/Sub: mensajes en la DLQ"
  combiner     = "OR"

  conditions {
    display_name = "Hay mensajes sin procesar en comprobantes-dlq"
    condition_threshold {
      filter          = "resource.type=\"pubsub_subscription\" AND resource.labels.subscription_id=\"${google_pubsub_subscription.dlq_lectura.name}\" AND metric.type=\"pubsub.googleapis.com/subscription/num_undelivered_messages\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "60s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MAX"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.correo.id]
}

resource "google_monitoring_alert_policy" "cloudsql_cpu" {
  display_name = "Cloud SQL: CPU > 85%"
  combiner     = "OR"

  conditions {
    display_name = "CPU mayor a 85% por 5 minutos"
    condition_threshold {
      filter          = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.85
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.correo.id]
}

resource "google_monitoring_alert_policy" "vm_cpu" {
  display_name = "VM backoffice: CPU > 85%"
  combiner     = "OR"

  conditions {
    display_name = "CPU mayor a 85% por 5 minutos"
    condition_threshold {
      filter          = "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/cpu/utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.85
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.correo.id]
}

# Disponibilidad (RNF01): verificación periódica de /health a través de API Gateway
resource "google_monitoring_uptime_check_config" "gateway" {
  display_name = "uptime-api-gateway"
  timeout      = "10s"
  period       = "300s"

  http_check {
    path         = "/health"
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = google_api_gateway_gateway.gw.default_hostname
    }
  }
}

resource "google_monitoring_alert_policy" "uptime_falla" {
  display_name = "API Gateway: /health no disponible"
  combiner     = "OR"

  conditions {
    display_name = "Falla del uptime check"
    condition_threshold {
      filter          = "resource.type=\"uptime_url\" AND metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND metric.labels.check_id=\"${google_monitoring_uptime_check_config.gateway.uptime_check_id}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 1
      duration        = "60s"

      aggregations {
        alignment_period     = "1200s"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields      = ["resource.*"]
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.correo.id]
}

resource "google_monitoring_dashboard" "facturacion" {
  dashboard_json = jsonencode({
    displayName = "Facturación Electrónica Serverless"
    gridLayout = {
      columns = 2
      widgets = [
        {
          title = "Solicitudes por segundo (Cloud Run)"
          xyChart = { dataSets = [{ plotType = "LINE", timeSeriesQuery = { timeSeriesFilter = {
            filter      = "metric.type=\"run.googleapis.com/request_count\" resource.type=\"cloud_run_revision\""
            aggregation = { alignmentPeriod = "60s", perSeriesAligner = "ALIGN_RATE", crossSeriesReducer = "REDUCE_SUM" }
          } } }] }
        },
        {
          title = "Latencia p95 (ms)"
          xyChart = { dataSets = [{ plotType = "LINE", timeSeriesQuery = { timeSeriesFilter = {
            filter      = "metric.type=\"run.googleapis.com/request_latencies\" resource.type=\"cloud_run_revision\""
            aggregation = { alignmentPeriod = "60s", perSeriesAligner = "ALIGN_PERCENTILE_95", crossSeriesReducer = "REDUCE_MAX" }
          } } }] }
        },
        {
          title = "Instancias activas (autoescalado)"
          xyChart = { dataSets = [{ plotType = "LINE", timeSeriesQuery = { timeSeriesFilter = {
            filter      = "metric.type=\"run.googleapis.com/container/instance_count\" resource.type=\"cloud_run_revision\""
            aggregation = { alignmentPeriod = "60s", perSeriesAligner = "ALIGN_MAX", crossSeriesReducer = "REDUCE_SUM" }
          } } }] }
        },
        {
          title = "CPU de la VM de backoffice"
          xyChart = { dataSets = [{ plotType = "LINE", timeSeriesQuery = { timeSeriesFilter = {
            filter      = "metric.type=\"compute.googleapis.com/instance/cpu/utilization\" resource.type=\"gce_instance\""
            aggregation = { alignmentPeriod = "60s", perSeriesAligner = "ALIGN_MEAN" }
          } } }] }
        },
        {
          title = "CPU de Cloud SQL"
          xyChart = { dataSets = [{ plotType = "LINE", timeSeriesQuery = { timeSeriesFilter = {
            filter      = "metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\" resource.type=\"cloudsql_database\""
            aggregation = { alignmentPeriod = "60s", perSeriesAligner = "ALIGN_MEAN" }
          } } }] }
        },
        {
          title = "CDR aceptados por minuto (métrica de negocio)"
          xyChart = { dataSets = [{ plotType = "LINE", timeSeriesQuery = { timeSeriesFilter = {
            filter      = "metric.type=\"logging.googleapis.com/user/cdr_aceptados\""
            aggregation = { alignmentPeriod = "60s", perSeriesAligner = "ALIGN_RATE", crossSeriesReducer = "REDUCE_SUM" }
          } } }] }
        },
        {
          title = "Mensajes sin procesar en la DLQ"
          xyChart = { dataSets = [{ plotType = "LINE", timeSeriesQuery = { timeSeriesFilter = {
            filter      = "metric.type=\"pubsub.googleapis.com/subscription/num_undelivered_messages\" resource.type=\"pubsub_subscription\""
            aggregation = { alignmentPeriod = "60s", perSeriesAligner = "ALIGN_MAX" }
          } } }] }
        },
      ]
    }
  })
}
