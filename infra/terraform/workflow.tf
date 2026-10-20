# Cloud Workflows: reemplaza los marcadores __X_URL__ del YAML por las URL reales de las funciones

locals {
  workflow_yaml = file("${path.module}/../../workflows/proceso-facturacion.workflow.yaml")

  workflow_source = replace(
    replace(
      replace(
        replace(
          replace(
            local.workflow_yaml,
            "__VALIDAR_URL__", google_cloudfunctions2_function.fn["validar-comprobante"].service_config[0].uri
          ),
          "__FIRMAR_URL__", google_cloudfunctions2_function.fn["firmar-generar-xml"].service_config[0].uri
        ),
        "__SUNAT_URL__", google_cloudfunctions2_function.fn["enviar-sunat"].service_config[0].uri
      ),
      "__PDF_URL__", google_cloudfunctions2_function.fn["generar-pdf"].service_config[0].uri
    ),
    "__NOTIFICAR_URL__", google_cloudfunctions2_function.fn["notificar-cliente"].service_config[0].uri
  )
}

resource "google_workflows_workflow" "facturacion" {
  name            = "proceso-facturacion"
  region          = var.region
  description     = "Orquesta validación, firma, envío a SUNAT, PDF, registro de estado y notificación"
  service_account = google_service_account.workflow.email
  source_contents = local.workflow_source

  depends_on = [
    google_cloud_run_service_iam_member.invoker,
    google_pubsub_topic_iam_member.workflow_publica_eventos,
    google_pubsub_topic_iam_member.workflow_publica_dlq,
  ]
}
