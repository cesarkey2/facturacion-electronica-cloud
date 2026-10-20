variable "project_id" {
  type        = string
  description = "ID del proyecto de Google Cloud Platform"
}

variable "region" {
  type        = string
  description = "Región de despliegue"
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "Zona de despliegue para las instancias de Compute Engine"
  default     = "us-central1-a"
}

variable "admin_ip" {
  type        = string
  description = "IP pública fija del administrador (formato CIDR, ej. 200.10.20.30/32) autorizada para SSH y HTTPS administrativo"
}

variable "db_user" {
  type        = string
  description = "Usuario de la base de datos Cloud SQL"
  default     = "app_user"
}

variable "db_password" {
  type        = string
  description = "Contraseña del usuario de Cloud SQL (pasar por variable de entorno TF_VAR_db_password, nunca en el repositorio)"
  sensitive   = true
}

variable "kms_suffix" {
  type        = string
  description = "Sufijo del key ring de KMS (los key rings no se pueden borrar; cambiar el valor si se vuelve a desplegar tras un destroy)"
  default     = "01"
}

variable "alert_email" {
  type        = string
  description = "Correo que recibe las alertas de Cloud Monitoring"
}

variable "sunat_fail_rate" {
  type        = string
  description = "Proporción de solicitudes a la SUNAT simulada que fallan (0 a 1); solo para pruebas de resiliencia"
  default     = "0"
}
