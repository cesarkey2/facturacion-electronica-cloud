# VM Bastión — único recurso con IP pública, solo para administración (Criterio 2)
resource "google_compute_instance" "bastion" {
  name         = "bastion-vm"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["bastion"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.public.id
    access_config {} # asigna IP pública efímera
  }
}

# VM Backoffice — corre el contenedor Docker del panel de reportería
# Sin access_config: no tiene IP pública, solo accesible desde la VPC
resource "google_compute_instance" "backoffice" {
  name         = "vm-backoffice-01"
  machine_type = "e2-small"
  zone         = var.zone
  tags         = ["backoffice"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 20
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private.id
  }

  # Identidad propia con permisos mínimos (ver iam.tf)
  service_account {
    email  = google_service_account.backoffice.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = file("${path.module}/scripts/install-docker.sh")

  depends_on = [google_compute_router_nat.nat]
}

# Repositorio de imágenes Docker donde se publica la imagen del backoffice
resource "google_artifact_registry_repository" "backoffice" {
  location      = var.region
  repository_id = "backoffice"
  format        = "DOCKER"
  description   = "Imágenes de contenedor del backoffice"
}
