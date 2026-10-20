# Cifrado y secretos (Capítulo 7 del informe)

# Llave asimétrica para la firma digital de comprobantes (RF02).
# Nota: los key rings y las llaves de Cloud KMS NO se pueden eliminar de GCP; tras un
# "terraform destroy" hay que cambiar var.kms_suffix para volver a crearlos con otro nombre.
resource "google_kms_key_ring" "facturacion" {
  name     = "kr-facturacion-${var.kms_suffix}"
  location = var.region
}

resource "google_kms_crypto_key" "firma" {
  name     = "key-firma-comprobantes"
  key_ring = google_kms_key_ring.facturacion.id
  purpose  = "ASYMMETRIC_SIGN"

  version_template {
    algorithm = "RSA_SIGN_PKCS1_2048_SHA256"
  }
}

# Secreto con la contraseña de la base de datos (nunca se guarda en el repositorio)
resource "google_secret_manager_secret" "db_password" {
  secret_id = "db-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password_v1" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = var.db_password
}
