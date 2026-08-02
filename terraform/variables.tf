variable "vps_host" {
  description = "Hostinger VPS IP / hostname"
  type        = string
  default     = "195.35.21.139"
}

variable "vps_user" {
  description = "SSH user on the VPS"
  type        = string
  default     = "root"
}

variable "vps_password" {
  description = "SSH password for the VPS (used only for initial provisioning)"
  type        = string
  sensitive   = true
}

variable "github_repo" {
  description = "GitHub repository HTTPS URL (public)"
  type        = string
  default     = "https://github.com/rohith1246/video-platform.git"
}

variable "app_dir" {
  description = "Directory on the VPS where the app lives"
  type        = string
  default     = "/var/www/video-platform"
}

# ─── Backend .env secrets ─────────────────────────────────────────────────────

variable "database_url" {
  description = "Full Neon PostgreSQL connection string"
  type        = string
  sensitive   = true
}

variable "db_host" {
  type      = string
  sensitive = true
}

variable "db_name" {
  type = string
}

variable "db_user" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "jwt_secret" {
  type      = string
  sensitive = true
}

variable "jwt_refresh_secret" {
  type      = string
  sensitive = true
}

variable "cors_origin" {
  description = "Allowed CORS origin (production domain)"
  type        = string
  default     = "https://elevateiq-softtech.com"
}
