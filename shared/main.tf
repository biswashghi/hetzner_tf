locals {
  common_labels = {
    app = var.project_name
    env = "prod"
  }

  resolved_ssh_public_key = var.ssh_public_key != null ? trimspace(var.ssh_public_key) : trimspace(file(pathexpand(var.ssh_public_key_path)))
}

resource "hcloud_ssh_key" "admin" {
  name       = var.ssh_key_name
  public_key = local.resolved_ssh_public_key
}

resource "hcloud_firewall" "web" {
  name = "${var.project_name}-fw"

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = concat(var.admin_ipv4_cidrs, var.admin_ipv6_cidrs)
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_server" "app" {
  name        = var.server_name
  server_type = var.server_type
  image       = var.image
  location    = var.location
  backups     = var.enable_backups
  ssh_keys    = [hcloud_ssh_key.admin.id]
  labels      = local.common_labels

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    deploy_username = var.deploy_username
  })
}

resource "hcloud_firewall_attachment" "app_firewall" {
  firewall_id = hcloud_firewall.web.id
  server_ids  = [hcloud_server.app.id]
}
