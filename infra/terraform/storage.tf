# Buckets de Cloud Storage (Criterio 2)
resource "google_storage_bucket" "comprobantes_xml" {
  versioning {
    enabled = true
  }

  name                        = "${var.project_id}-comprobantes-xml"
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  force_destroy               = true
}

resource "google_storage_bucket" "comprobantes_pdf" {
  versioning {
    enabled = true
  }

  name                        = "${var.project_id}-comprobantes-pdf"
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  force_destroy               = true
}

resource "google_storage_bucket" "backups_sql" {
  name                        = "${var.project_id}-backups-sql"
  location                    = var.region
  storage_class               = "NEARLINE"
  uniform_bucket_level_access = true
  force_destroy               = true

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }
}

# Base de datos relacional inicial: Cloud SQL PostgreSQL con IP privada (Criterio 2)
resource "google_sql_database_instance" "facturacion" {
  name                = "cloud-sql-facturacion"
  database_version    = "POSTGRES_16"
  region              = var.region
  deletion_protection = false

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier = "db-f1-micro"

    ip_configuration {
      ipv4_enabled    = false # sin IP pública
      private_network = google_compute_network.vpc.id
    }

    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = true
    }
  }
}

resource "google_sql_database" "facturacion_db" {
  name     = "facturacion"
  instance = google_sql_database_instance.facturacion.name
}

resource "google_sql_user" "app_user" {
  name     = var.db_user
  instance = google_sql_database_instance.facturacion.name
  password = var.db_password
}

# Base NoSQL operacional (estado de comprobantes en tiempo real, definida en el APF1)
resource "google_firestore_database" "default" {
  name            = "(default)"
  location_id     = var.region
  type            = "FIRESTORE_NATIVE"
  deletion_policy = "DELETE"
}
