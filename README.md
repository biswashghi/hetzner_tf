# Hetzner Deployment Runbook

Start here for production deployment on Hetzner.

This runbook covers the shared infrastructure and shared proxy flow for:
- `family_hub`
- `fitness`
- `badge_creator`

For app-specific behavior (credentials, app operations, tests), go back to each repo README:
- [Family Hub README](https://github.com/biswashghi/family_hub/blob/main/README.md)
- [Fitness README](https://github.com/biswashghi/fitness/blob/main/README.md)
- [Badge Creator README](https://github.com/biswashghi/badge_creator/blob/main/README.md)

## Prerequisites

- `terraform`, `bw`, and `jq` installed locally.
- Hetzner token available in Bitwarden item `hetzner-hcloud-token`, field `token`.
- DNS access for your domain.
- SSH key available at path used in `terraform.tfvars`.

## 1) Configure Terraform Variables

```bash
cd /Users/biswash/Documents/repos/hetzner_tf/shared
cp terraform.tfvars.example terraform.tfvars
```

Set at minimum in `terraform.tfvars`:
- `ssh_public_key_path`
- `admin_ipv4_cidrs` / `admin_ipv6_cidrs`
- `family_domain` (example: `family.bghimire.com`)
- `fitness_domain` (example: `fit.bghimire.com`)
- `badge_creator_domain` (example: `badges.bghimire.com`)
- `acme_email`

## 2) Recreate or Apply Infrastructure

From `hetzner_tf` root:

```bash
cd /Users/biswash/Documents/repos/hetzner_tf
./scripts/tf-hcloud.sh init
./scripts/tf-hcloud.sh plan
./scripts/tf-hcloud.sh apply
./scripts/tf-hcloud.sh output
```

If you want a clean rebuild:

```bash
./scripts/tf-hcloud.sh destroy -auto-approve
./scripts/tf-hcloud.sh apply -auto-approve
./scripts/tf-hcloud.sh output
```

## 3) Configure DNS

Point both subdomains to the same Terraform output server IP:
- `family.bghimire.com` -> `<server_ipv4>`
- `fit.bghimire.com` -> `<server_ipv4>`
- `badges.bghimire.com` -> `<server_ipv4>`

## 4) Deploy Family Hub

From `hetzner_tf` root:

```bash
cd /Users/biswash/Documents/repos/hetzner_tf
./scripts/deploy-hetzner-prod-from-tf.sh \
  /Users/biswash/Documents/repos/family_hub \
  <deploy-user> <server-ip> <family-repo-url> main
```

Family Hub credentials are pulled from Bitwarden by default:
- Item: `family-hub-prod-credentials`
- Fields: `username`, `password`

Override names if needed:
- `BW_FAMILY_HUB_ITEM_NAME`
- `BW_FAMILY_HUB_USERNAME_FIELD`
- `BW_FAMILY_HUB_PASSWORD_FIELD`

If needed, return to the Family Hub README for app-specific details:
- [Family Hub README](https://github.com/biswashghi/family_hub/blob/main/README.md)

## 5) Deploy Fitness

From `hetzner_tf` root:

```bash
cd /Users/biswash/Documents/repos/hetzner_tf
./scripts/deploy-hetzner-prod-from-tf.sh \
  /Users/biswash/Documents/repos/fitness \
  <deploy-user> <server-ip> <fitness-repo-url> main
```

If needed, return to the Fitness README for app-specific details:
- [Fitness README](https://github.com/biswashghi/fitness/blob/main/README.md)

## 6) Deploy Badge Creator

From `hetzner_tf` root:

```bash
cd /Users/biswash/Documents/repos/hetzner_tf
./scripts/deploy-hetzner-prod-from-tf.sh \
  /Users/biswash/Documents/repos/badge_creator \
  <deploy-user> <server-ip> <badge-creator-repo-url> main
```

If needed, return to the Badge Creator README for app-specific details:
- [Badge Creator README](https://github.com/biswashghi/badge_creator/blob/main/README.md)

## 7) Verify

```bash
curl -I https://family.bghimire.com
curl -f https://family.bghimire.com/api/health
curl -I https://fit.bghimire.com
curl -f https://fit.bghimire.com/api/health
curl -I https://badges.bghimire.com
```

## Scripts

- Terraform wrapper: [/Users/biswash/Documents/repos/hetzner_tf/scripts/tf-hcloud.sh](/Users/biswash/Documents/repos/hetzner_tf/scripts/tf-hcloud.sh)
- Shared deploy wrapper: [/Users/biswash/Documents/repos/hetzner_tf/scripts/deploy-hetzner-prod-from-tf.sh](/Users/biswash/Documents/repos/hetzner_tf/scripts/deploy-hetzner-prod-from-tf.sh)
- Shared Caddy deploy: [/Users/biswash/Documents/repos/hetzner_tf/scripts/deploy-shared-caddy.sh](/Users/biswash/Documents/repos/hetzner_tf/scripts/deploy-shared-caddy.sh)
