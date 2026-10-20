# API Gateway: punto de entrada con API key y cuota (proveedor google-beta)

resource "google_api_gateway_api" "api" {
  provider = google-beta
  api_id   = "api-facturacion"
}

resource "google_api_gateway_api_config" "cfg" {
  provider             = google-beta
  api                  = google_api_gateway_api.api.api_id
  api_config_id_prefix = "cfg-"

  openapi_documents {
    document {
      path = "openapi.yaml"
      contents = base64encode(templatefile("${path.module}/../../api/openapi.yaml.tftpl", {
        backend_url = google_cloudfunctions2_function.fn["api-emision"].service_config[0].uri
      }))
    }
  }

  gateway_config {
    backend_config {
      google_service_account = google_service_account.gateway.email
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_api_gateway_gateway" "gw" {
  provider   = google-beta
  api_config = google_api_gateway_api_config.cfg.id
  gateway_id = "gw-facturacion"
  region     = var.region
}
