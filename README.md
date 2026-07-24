# VPS Deployment Runbook

Start here for production deployment. Hetzner still provisions the current server, but app deployment is now provider-agnostic: SSH, Docker Compose, shared Caddy, optional Gandi DNS.

This runbook covers:
- `family_hub`
- `fitness`
- `badge_creator`

## Architecture

- Provider layer: Terraform in `shared/` creates the current Hetzner VPS, firewall, SSH key, and deploy user.
- VPS runtime layer: `scripts/deploy-shared-caddy.sh` installs/refreshes Docker and the shared Caddy reverse proxy.
- App deployment layer: each app exposes `scripts/deploy-vps.sh`; deployment docs and automation use the generic script names.
- Optional DNS layer: `scripts/update-gandi-dns.sh` updates Gandi LiveDNS `A` records when explicitly requested.

## Prerequisites

- `terraform`, `bw`, `jq`, and `curl` installed locally.
- Hetzner token available in Bitwarden item `hetzner-hcloud-token`, field `token`.
- Gandi PAT available either as `GANDI_PAT` or in Bitwarden item `gandi-pat` for DNS updates.
- SSH key available at the path used in `terraform.tfvars`.

## 1) Configure Terraform Variables

```bash
cd /Users/biswash/Documents/repos/hetzner_tf/shared
cp terraform.tfvars.example terraform.tfvars
```

Set at minimum in `terraform.tfvars`:
- `ssh_public_key_path`
- `admin_ipv4_cidrs` / `admin_ipv6_cidrs`
- `family_domain` (example: `family.bghimire.com`)
- `fitness_domain` (example: `fitness.bghimire.com`)
- `badge_creator_domain` (example: `badges.bghimire.com`)
- `acme_email`

## 2) Apply Hetzner Infrastructure

From `hetzner_tf` root:

```bash
cd /Users/biswash/Documents/repos/hetzner_tf
./scripts/tf-hcloud.sh init
./scripts/tf-hcloud.sh plan
./scripts/tf-hcloud.sh apply
./scripts/tf-hcloud.sh output
```

If you intentionally want a clean rebuild:

```bash
./scripts/tf-hcloud.sh destroy -auto-approve
./scripts/tf-hcloud.sh apply -auto-approve
./scripts/tf-hcloud.sh output
```

## 3) Configure DNS

Point each app subdomain to the Terraform `server_ipv4` output:
- `family.bghimire.com` -> `<server_ipv4>`
- `fitness.bghimire.com` -> `<server_ipv4>`
- `badges.bghimire.com` -> `<server_ipv4>`

Manual Gandi update:

```bash
./scripts/update-gandi-dns.sh family.bghimire.com <server-ip>
```

Deploy commands can also update the selected app record with `--update-dns`.

## 4) Deploy Apps

Recommended Terraform-output flow:

```bash
cd /Users/biswash/Documents/repos/hetzner_tf
./scripts/deploy-vps-prod-from-tf.sh family_hub main
./scripts/deploy-vps-prod-from-tf.sh fitness main
./scripts/deploy-vps-prod-from-tf.sh badge_creator main
```

With Gandi DNS update:

```bash
./scripts/deploy-vps-prod-from-tf.sh --update-dns family_hub main
```

Manual VPS flow:

```bash
FAMILY_DOMAIN=family.bghimire.com \
FITNESS_DOMAIN=fitness.bghimire.com \
BADGE_CREATOR_DOMAIN=badges.bghimire.com \
ACME_EMAIL=ghi.biswash@gmail.com \
./scripts/deploy-vps-prod.sh family_hub deploy <server-ip> https://github.com/biswashghi/family_hub.git main
```

Legacy Hetzner command names still work:

```bash
./scripts/deploy-hetzner-prod-from-tf.sh \
  /Users/biswash/Documents/repos/family_hub \
  deploy <server-ip> https://github.com/biswashghi/family_hub.git main
```

## 5) Verify

```bash
curl -I https://family.bghimire.com
curl -f https://family.bghimire.com/api/health
curl -I https://fitness.bghimire.com
curl -f https://fitness.bghimire.com/api/health
curl -I https://badges.bghimire.com
```

## Scripts

- Hetzner Terraform wrapper: [/Users/biswash/Documents/repos/hetzner_tf/scripts/tf-hcloud.sh](/Users/biswash/Documents/repos/hetzner_tf/scripts/tf-hcloud.sh)
- Generic Terraform-output deploy: [/Users/biswash/Documents/repos/hetzner_tf/scripts/deploy-vps-prod-from-tf.sh](/Users/biswash/Documents/repos/hetzner_tf/scripts/deploy-vps-prod-from-tf.sh)
- Generic manual VPS deploy: [/Users/biswash/Documents/repos/hetzner_tf/scripts/deploy-vps-prod.sh](/Users/biswash/Documents/repos/hetzner_tf/scripts/deploy-vps-prod.sh)
- Shared Caddy deploy: [/Users/biswash/Documents/repos/hetzner_tf/scripts/deploy-shared-caddy.sh](/Users/biswash/Documents/repos/hetzner_tf/scripts/deploy-shared-caddy.sh)
- Gandi DNS update: [/Users/biswash/Documents/repos/hetzner_tf/scripts/update-gandi-dns.sh](/Users/biswash/Documents/repos/hetzner_tf/scripts/update-gandi-dns.sh)
