# Terraform Infra Reference

Primary step-by-step deployment instructions live in:
- [README.md](../README.md)

This file is the Hetzner Terraform-specific reference. Deployment scripts consume only the generic outputs listed below, so another provider can be added later by exposing the same output contract.

## Managed Resources

- `hcloud_server.app`
- `hcloud_firewall.web`
- `hcloud_firewall_attachment.app_firewall`
- `hcloud_ssh_key.admin`

## Key Variables (`terraform.tfvars`)

- `server_name`: Hetzner server hostname
- `location`: Datacenter location (`ash`, `nbg1`, etc.)
- `server_type`: VM size (`cpx11`, ...)
- `image`: OS image (`ubuntu-24.04`)
- `ssh_key_name`: Hetzner SSH key resource name
- `ssh_public_key_path`: Local `.pub` key path used for provisioning
- `admin_ipv4_cidrs` / `admin_ipv6_cidrs`: SSH allowlist
- `enable_backups`: Hetzner backups toggle
- `deploy_username`: created server user
- `family_domain`: DNS name for Family Hub
- `fitness_domain`: DNS name for Fitness
- `badge_creator_domain`: DNS name for Badge Creator
- `acme_email`: Let's Encrypt registration email

## Outputs

- `server_name`
- `server_ipv4`
- `server_ipv6`
- `deploy_user`
- `family_domain`
- `fitness_domain`
- `badge_creator_domain`
- `family_url`
- `fitness_url`
- `badge_creator_url`
- `acme_email`

The provider-agnostic deploy wrapper requires:

```text
server_ipv4
deploy_user
family_domain
fitness_domain
badge_creator_domain
acme_email
```

## Notes

- Firewall is production-oriented: `22`, `80`, `443`.
- App containers bind only to localhost (`127.0.0.1`) and are exposed publicly through shared Caddy.
- Token auth is runtime-only through `HCLOUD_TOKEN` (handled by [`../scripts/tf-hcloud.sh`](../scripts/tf-hcloud.sh)).

## Lifecycle Commands

From the `hetzner_tf` repo root:

```bash
./scripts/tf-hcloud.sh init
./scripts/tf-hcloud.sh plan
./scripts/tf-hcloud.sh apply
./scripts/tf-hcloud.sh output
./scripts/tf-hcloud.sh destroy
```
