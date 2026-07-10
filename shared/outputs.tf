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

output "family_url" {
  value = "https://${var.family_domain}"
}

output "fitness_url" {
  value = "https://${var.fitness_domain}"
}

output "badge_creator_url" {
  value = "https://${var.badge_creator_domain}"
}

output "acme_email" {
  value = var.acme_email
}
