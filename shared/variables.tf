variable "project_name" {
  description = "Project/service label prefix"
  type        = string
  default     = "fitness-tracker"
}

variable "server_name" {
  description = "Hetzner server name"
  type        = string
  default     = "fitness-prod-1"
}

variable "location" {
  description = "Hetzner location (e.g. nbg1, fsn1, hel1, ash, hil)"
  type        = string
  default     = "ash"
}

variable "server_type" {
  description = "Hetzner server type"
  type        = string
  default     = "cpx11"
}

variable "image" {
  description = "Server image"
  type        = string
  default     = "ubuntu-24.04"
}

variable "ssh_key_name" {
  description = "Name for uploaded SSH key"
  type        = string
  default     = "fitness-admin-key"
}

variable "ssh_public_key" {
  description = "SSH public key contents"
  type        = string
  default     = null
  nullable    = true
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file (used when ssh_public_key is null)"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "admin_ipv4_cidrs" {
  description = "Allowed IPv4 CIDRs for SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "admin_ipv6_cidrs" {
  description = "Allowed IPv6 CIDRs for SSH"
  type        = list(string)
  default     = ["::/0"]
}

variable "enable_backups" {
  description = "Enable Hetzner automatic backups"
  type        = bool
  default     = true
}

variable "deploy_username" {
  description = "Non-root deploy user created via cloud-init"
  type        = string
  default     = "deploy"
}

variable "family_domain" {
  description = "Public domain for Family Hub (e.g. family.example.com)"
  type        = string
  default     = "example.com"
}

variable "fitness_domain" {
  description = "Public domain for Fitness app (e.g. fit.example.com)"
  type        = string
  default     = "example.com"
}

variable "badge_creator_domain" {
  description = "Public domain for Badge Creator (e.g. badges.example.com)"
  type        = string
  default     = "example.com"
}

variable "paisa_web_domain" {
  description = "Public domain for the Paisa web console (e.g. paisa.example.com)"
  type        = string
  default     = "example.com"
}

variable "paisa_api_domain" {
  description = "Public domain for the Paisa API (e.g. api.paisa.example.com)"
  type        = string
  default     = "example.com"
}

variable "novel_api_domain" {
  description = "Public API domain for Novel Tracker (e.g. api.novel.example.com)"
  type        = string
  default     = "example.com"
}

variable "novel_auth_domain" {
  description = "Public Keycloak domain for Novel Tracker (e.g. auth.novel.example.com)"
  type        = string
  default     = "example.com"
}

variable "acme_email" {
  description = "Email used for ACME/Let's Encrypt registration"
  type        = string
  default     = "admin@example.com"
}
