# Capa serverless: 7 Cloud Run functions (2ª generación) empaquetadas desde ../../functions

locals {
  funciones = {
    "validar-comprobante" = {
      entry   = "validarComprobante"
      sa      = google_service_account.functions.email
      invoker = google_service_account.workflow.email
      max     = 20
      env     = tomap({})
      vpc     = false
      secret  = false
    }
    "firmar-generar-xml" = {
      entry   = "firmarYGenerarXml"
      sa      = google_service_account.functions.email
      invoker = google_service_account.workflow.email
      max     = 20
      env = tomap({
        BUCKET_XML      = google_storage_bucket.comprobantes_xml.name
        KMS_KEY_VERSION = "${google_kms_crypto_key.firma.id}/cryptoKeyVersions/1"
      })
      vpc    = false
      secret = false
    }
    "enviar-sunat" = {
      entry   = "enviarSunat"
      sa      = google_service_account.functions.email
      invoker = google_service_account.workflow.email
      max     = 20
      env     = tomap({ SUNAT_FAIL_RATE = var.sunat_fail_rate })
      vpc     = false
      secret  = false
    }
    "generar-pdf" = {
      entry   = "generarPdf"
      sa      = google_service_account.functions.email
      invoker = google_service_account.workflow.email
      max     = 20
      env     = tomap({ BUCKET_PDF = google_storage_bucket.comprobantes_pdf.name })
      vpc     = false
      secret  = false
    }
    "notificar-cliente" = {
      entry   = "notificarCliente"
      sa      = google_service_account.functions.email
      invoker = google_service_account.workflow.email
      max     = 20
      env     = tomap({})
      vpc     = false
      secret  = false
    }
    "api-emision" = {
      entry   = "apiEmision"
      sa      = google_service_account.api.email
      invoker = google_service_account.gateway.email
      max     = 20
      env     = tomap({ WORKFLOW_PARENT = "projects/${var.project_id}/locations/${var.region}/workflows/proceso-facturacion" })
      vpc     = false
      secret  = false
    }
    "sincronizar-reportes" = {
      entry   = "sincronizarReportes"
      sa      = google_service_account.sync.email
      invoker = google_service_account.push.email
      max     = 5 # limita las conexiones simultáneas a Cloud SQL
      env = tomap({
        DB_HOST = google_sql_database_instance.facturacion.private_ip_address
        DB_PORT = "5432"
        DB_NAME = "facturacion"
        DB_USER = var.db_user
      })
      vpc    = true
      secret = true
    }
  }
}

resource "google_storage_bucket" "functions_src" {
  name                        = "${var.project_id}-functions-src"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
}

data "archive_file" "fn" {
  for_each    = local.funciones
  type        = "zip"
  source_dir  = "${path.module}/../../functions/${each.key}"
  output_path = "${path.module}/build/${each.key}.zip"
  excludes    = ["node_modules", "test.js"]
}

resource "google_storage_bucket_object" "fn_src" {
  for_each = local.funciones
  name     = "${each.key}-${data.archive_file.fn[each.key].output_md5}.zip"
  bucket   = google_storage_bucket.functions_src.name
  source   = data.archive_file.fn[each.key].output_path
}

resource "google_cloudfunctions2_function" "fn" {
  for_each = local.funciones
  name     = each.key
  location = var.region

  build_config {
    runtime     = "nodejs20"
    entry_point = each.value.entry

    source {
      storage_source {
        bucket = google_storage_bucket.functions_src.name
        object = google_storage_bucket_object.fn_src[each.key].name
      }
    }
  }

  # Autoescalado (Capítulo 9): de 0 a max instancias; el costo es 0 en inactividad
  service_config {
    min_instance_count    = 0
    max_instance_count    = each.value.max
    available_memory      = "256M"
    timeout_seconds       = 60
    service_account_email = each.value.sa
    ingress_settings      = "ALLOW_ALL" # acceso protegido por IAM (solo el invocador autorizado)
    environment_variables = each.value.env

    vpc_connector                 = each.value.vpc ? google_vpc_access_connector.connector.id : null
    vpc_connector_egress_settings = each.value.vpc ? "PRIVATE_RANGES_ONLY" : null

    dynamic "secret_environment_variables" {
      for_each = each.value.secret ? [1] : []
      content {
        key        = "DB_PASSWORD"
        project_id = var.project_id
        secret     = google_secret_manager_secret.db_password.secret_id
        version    = "latest"
      }
    }
  }

  depends_on = [
    google_secret_manager_secret_iam_member.sync_db_password,
    google_kms_crypto_key_iam_member.functions_sign,
  ]
}

# Cada función solo puede ser invocada por su cliente autorizado (mínimo privilegio)
resource "google_cloud_run_service_iam_member" "invoker" {
  for_each = local.funciones
  location = var.region
  service  = google_cloudfunctions2_function.fn[each.key].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${each.value.invoker}"
}
