output "server_name" {
  value = hcloud_server.app.name
}

output "server_ipv4" {
  value = hcloud_server.app.ipv4_address
}

output "server_ipv6" {
  value = hcloud_server.app.ipv6_address
}

output "deploy_user" {
  value = var.deploy_username
}

output "family_domain" {
  value = var.family_domain
}

output "fitness_domain" {
  value = var.fitness_domain
}

output "badge_creator_domain" {
  value = var.badge_creator_domain
}

output "paisa_web_domain" {
  value = var.paisa_web_domain
}

output "paisa_api_domain" {
  value = var.paisa_api_domain
}

output "family_url" {
  value = "https://${var.family_domain}"
}

output "fitness_url" {
  value = "https://${var.fitness_domain}"
}

output "badge_creator_url" {
  value = "https://${var.badge_creator_domain}"
}

output "paisa_web_url" {
  value = "https://${var.paisa_web_domain}"
}

output "paisa_api_url" {
  value = "https://${var.paisa_api_domain}"
}

output "novel_api_domain" {
  value = var.novel_api_domain
}

output "novel_auth_domain" {
  value = var.novel_auth_domain
}

output "novel_api_url" {
  value = "https://${var.novel_api_domain}"
}

output "novel_auth_url" {
  value = "https://${var.novel_auth_domain}"
}

output "acme_email" {
  value = var.acme_email
}

output "drift_api_domain" {
  description = "DNS name for the Drift API"
  value       = var.drift_api_domain
}

output "drift_api_url" {
  description = "Base URL for the Drift API"
  value       = "https://${var.drift_api_domain}"
}
