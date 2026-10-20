output "vpc_name" {
  value = google_compute_network.vpc.name
}

output "bastion_public_ip" {
  value = google_compute_instance.bastion.network_interface[0].access_config[0].nat_ip
}

output "backoffice_private_ip" {
  value = google_compute_instance.backoffice.network_interface[0].network_ip
}

output "cloud_sql_private_ip" {
  value = google_sql_database_instance.facturacion.private_ip_address
}

output "buckets" {
  value = [
    google_storage_bucket.comprobantes_xml.name,
    google_storage_bucket.comprobantes_pdf.name,
    google_storage_bucket.backups_sql.name,
  ]
}

output "service_accounts" {
  value = {
    backoffice = google_service_account.backoffice.email
    functions  = google_service_account.functions.email
  }
}

output "kms_signing_key" {
  value = google_kms_crypto_key.firma.id
}

output "gateway_url" {
  value = "https://${google_api_gateway_gateway.gw.default_hostname}"
}

output "api_managed_service" {
  description = "Servicio administrado de la API (para habilitarlo y crear la API key)"
  value       = google_api_gateway_api.api.managed_service
}

output "workflow" {
  value = google_workflows_workflow.facturacion.name
}

output "function_urls" {
  value = { for k, f in google_cloudfunctions2_function.fn : k => f.service_config[0].uri }
}
