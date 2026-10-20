# VPC dedicada del proyecto (Criterio 1 — Topología de Red Virtual)
resource "google_compute_network" "vpc" {
  name                    = "vpc-facturacion-electronica"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# Subred pública: solo el bastión y el NAT viven aquí
resource "google_compute_subnetwork" "public" {
  name          = "subnet-public"
  ip_cidr_range = "10.10.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# Subred privada: backoffice y Cloud SQL, sin IP pública
resource "google_compute_subnetwork" "private" {
  name                     = "subnet-private"
  ip_cidr_range            = "10.10.2.0/24"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
}

# Cloud Router + Cloud NAT: salida a Internet para la subred privada sin IP pública
resource "google_compute_router" "router" {
  name    = "cr-facturacion"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "nat-facturacion"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.private.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

# Rango privado reservado para el VPC peering que usa Cloud SQL (IP privada)
resource "google_compute_global_address" "private_ip_range" {
  name          = "sql-private-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}

# Conector para que Cloud Workflows / Cloud Run functions (capa serverless del APF1)
# puedan alcanzar Cloud SQL por IP privada
resource "google_vpc_access_connector" "connector" {
  name          = "serverless-vpc-connector"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.10.8.0/28"
  min_instances = 2
  max_instances = 3
}
