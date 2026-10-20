# Reglas de firewall de mínimo privilegio (Criterio 1)
# - Ninguna regla de INGRESO está abierta a 0.0.0.0/0.
# - Solo el bastión es alcanzable desde Internet, y únicamente desde la IP del administrador.
# - Hacia la VM privada solo se permite tráfico originado en el bastión (referenciado por
#   etiqueta de red, equivalente a referenciar un Security Group por ID).
# - El acceso a Cloud SQL (5432) no pasa por reglas de ingreso de la VPC: la instancia solo
#   tiene IP privada (peering de servicios privados) y no tiene IP pública.

resource "google_compute_firewall" "allow_ssh_bastion" {
  name      = "fw-allow-ssh-bastion"
  network   = google_compute_network.vpc.name
  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.admin_ip]
  target_tags   = ["bastion"]
}

resource "google_compute_firewall" "allow_ssh_bastion_to_backoffice" {
  name      = "fw-allow-ssh-bastion-to-backoffice"
  network   = google_compute_network.vpc.name
  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_tags = ["bastion"]
  target_tags = ["backoffice"]
}

# Acceso a la aplicación del backoffice (puerto 8080) solo desde el bastión,
# por ejemplo mediante un túnel SSH: ssh -L 8080:<IP_PRIVADA_BACKOFFICE>:8080 bastion
resource "google_compute_firewall" "allow_app_from_bastion" {
  name      = "fw-allow-app-from-bastion"
  network   = google_compute_network.vpc.name
  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_tags = ["bastion"]
  target_tags = ["backoffice"]
}

# Denegación explícita de respaldo (además de la denegación implícita de GCP)
resource "google_compute_firewall" "deny_all_ingress" {
  name      = "fw-deny-all"
  network   = google_compute_network.vpc.name
  direction = "INGRESS"
  priority  = 65534

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}
