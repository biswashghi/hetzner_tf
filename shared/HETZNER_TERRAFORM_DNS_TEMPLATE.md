# Hetzner + Terraform + DNS Deployment Template

This document is a reusable template for deploying apps to a Hetzner Cloud server using:
- Terraform for infrastructure
- Docker Compose for app runtime
- Caddy for HTTPS termination
- DNS (example: Gandi) to map domain -> server

Use this writeup as a blueprint for other apps.

> The runtime follows the shared-host model in
> [`../SHARED_HOST_DEPLOYMENT.md`](../SHARED_HOST_DEPLOYMENT.md): bootstrap Caddy
> and `vps-edge` once, then let each app own one Compose project and route file.
> Application releases must not invoke the platform bootstrap.

## 1) Deployment Architecture

For this app, deployment is split into layers:

1. Infrastructure layer (Terraform)
- Provisions server, firewall, SSH key, and outputs.
- Reference: [main.tf](./main.tf)

2. Runtime layer (Docker Compose)
- The platform runs Caddy; each app runs in a separate named Compose project.
- Reference: [fitness/docker-compose.prod.yml](../../fitness/docker-compose.prod.yml)

3. HTTPS + routing (Caddy)
- Terminates TLS on 443 and reaches public services over `vps-edge`.
- Reference: [scripts/deploy-vps-platform.sh](../scripts/deploy-vps-platform.sh)

4. Deployment automation (scripts)
- Terraform token orchestration via Bitwarden
- Server pull/build/up workflow
- References:
  - [scripts/tf-hcloud.sh](../scripts/tf-hcloud.sh)
  - [fitness/scripts/deploy-vps.sh](../../fitness/scripts/deploy-vps.sh)
  - [paisa/scripts/deploy-vps.sh](../../paisa/scripts/deploy-vps.sh)
  - [scripts/deploy-hetzner-prod-from-tf.sh](../scripts/deploy-hetzner-prod-from-tf.sh)

## 2) What Terraform Manages

Terraform resources in this project:
- `hcloud_server.app`
- `hcloud_firewall.web`
- `hcloud_firewall_attachment.app_firewall`
- `hcloud_ssh_key.admin`

Primary files:
- Provider/version config: [versions.tf](./versions.tf)
- Variables: [variables.tf](./variables.tf)
- Resources: [main.tf](./main.tf)
- Outputs: [outputs.tf](./outputs.tf)
- Cloud-init bootstrap: [cloud-init.yaml.tftpl](./cloud-init.yaml.tftpl)
- Example tfvars: [terraform.tfvars.example](./terraform.tfvars.example)

Production firewall posture in this template:
- Open: `22`, `80`, `443`
- Closed by default: app/debug ports (`5173`, `8787`)

## 3) Runtime Topology (Docker)

Production compose stack:

- `fitness-tracker` service
  - built from `Dockerfile` production target
  - internal app port: `8787`
  - SQLite persisted via volume

- `caddy` service
  - exposes host ports `80` and `443`
  - reverse proxies to `fitness-tracker:8787`
  - auto-manages certs via ACME

References:
- Compose file: [fitness/docker-compose.prod.yml](../../fitness/docker-compose.prod.yml)
- Image build targets: [fitness/Dockerfile](../../fitness/Dockerfile)

## 4) Domain and DNS Flow

For a subdomain like `fit.bghimire.com`:

1. Deploy infra and get `server_ipv4` from Terraform output.
2. In DNS provider (e.g., Gandi), create:
- `A` record: `fit` -> `<server_ipv4>`
3. Set Terraform vars:
- `fitness_domain = "fit.bghimire.com"`
- `badge_creator_domain = "badges.bghimire.com"` (if deploying the static badge site too)
- `paisa_web_domain = "paisa.bghimire.com"`
- `paisa_api_domain = "api.paisa.bghimire.com"`
- `acme_email = "you@bghimire.com"`
4. Deploy compose stack with Caddy.
5. Caddy obtains certificate and serves app at `https://fit.bghimire.com`.

## 5) Token and Secret Handling Pattern

This template avoids hardcoding cloud tokens in tracked files.

- Hetzner token is fetched from Bitwarden at command runtime.
- Terraform authenticates via `HCLOUD_TOKEN` env var (ephemeral per command).
- Secret scanning is enforced with git hooks + gitleaks config.

References:
- Token wrapper: [scripts/tf-hcloud.sh](../scripts/tf-hcloud.sh)
- Gitleaks config: [fitness/.gitleaks.toml](../../fitness/.gitleaks.toml)
- Pre-commit hook: [fitness/.githooks/pre-commit](../../fitness/.githooks/pre-commit)

## 6) Standard Command Sequence (This App)

1. Configure Terraform vars:

```bash
cd shared
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars
```

2. Provision/update infrastructure:

```bash
cd /path/to/hetzner_tf
./scripts/tf-hcloud.sh init
./scripts/tf-hcloud.sh plan
./scripts/tf-hcloud.sh apply
./scripts/tf-hcloud.sh output
```

3. Configure DNS (`A` record to `server_ipv4`).

4. Bootstrap the platform once, then deploy apps independently:

```bash
cd /path/to/hetzner_tf
./scripts/deploy-vps-platform-from-tf.sh
./scripts/deploy-vps-prod-from-tf.sh paisa main
```

The generic wrapper intentionally rejects `fitness` and `badge_creator` until
their Compose stacks have been migrated away from host ports.

5. Verify:

```bash
curl -I https://<fitness_domain>
curl -f https://<fitness_domain>/api/health
curl -I https://<badge_creator_domain>
curl -I https://<paisa_web_domain>
curl -f https://<paisa_api_domain>/health
```

## 7) Adapting This Template for Another App

When reusing for another app, update these areas:

1. App container details
- Update build context/image/cmd/port/volumes in:
  - [fitness/docker-compose.prod.yml](../../fitness/docker-compose.prod.yml)
  - [fitness/Dockerfile](../../fitness/Dockerfile)

2. Reverse proxy target
- Give the public service a unique alias on `vps-edge` and have the app's deploy
  script submit only its route through `/usr/local/bin/vps-route`.

3. Health endpoint
- Ensure `/api/health` exists, or change verification/deploy checks.
- Current backend ref:
  - [fitness/server/index.js](../../fitness/server/index.js)
  - Static sites like `badge_creator` and the Paisa web frontend can use a simple `curl -I` check instead.
  - Paisa verifies both the API health endpoint and the frontend root.

4. Terraform naming and defaults
- Update names/tags/defaults in:
  - [variables.tf](./variables.tf)
  - [main.tf](./main.tf)

5. Deploy script assumptions
- Current scripts assume repo pull to `/opt/fitness-tracker` and compose deploy.
- Update as needed in:
  - [fitness/scripts/deploy-vps.sh](../../fitness/scripts/deploy-vps.sh)

## 8) Operational Best Practices (Template Defaults)

1. Keep SSH restricted to known admin CIDRs.
2. Keep app/debug ports closed publicly in production.
3. Use only `80/443` public ingress via reverse proxy.
4. Enable server backups.
5. Reboot server when kernel upgrade is pending.
6. Run `docker compose ps` and service health checks after deploy.

## 9) Troubleshooting Quick Map

1. `curl https://domain` fails
- Check DNS A record and propagation
- Check Hetzner firewall allows 80/443
- Check Caddy container logs

2. `Host key verification failed` during deploy
- Ensure Git host key is in remote `known_hosts`
- Use HTTPS repo URL if easier

3. App healthy internally, not externally
- Check that the service and `shared-caddy` both join `vps-edge`, then inspect the
  app's file under `/opt/shared-caddy/apps`.

4. Terraform token errors
- Validate `HCLOUD_TOKEN` is present and valid at runtime
- Avoid stale or overridden token variables in tfvars

## 10) Canonical References

- Primary runbook: [fitness/README.md](../../fitness/README.md)
- Terraform details: [shared/README.md](./README.md)
