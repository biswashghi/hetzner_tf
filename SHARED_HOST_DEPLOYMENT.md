# Shared-host deployment model

The VPS is a capacity node, not an application release unit. Infrastructure and
application releases have separate lifecycles:

1. Terraform creates a server, firewall, SSH user, and outputs the host contract.
2. `deploy-vps-platform.sh` installs Docker once, creates the external `vps-edge`
   network, and starts the shared Caddy proxy.
3. Each application repository deploys its own named Compose project and writes
   exactly one route file through `/usr/local/bin/vps-route`.

An application deploy never provisions a server, rewrites another application's
route, or recreates Caddy. The route helper serializes changes, validates the full
Caddy configuration, restores the previous file on failure, and performs an
in-process reload.

Application repositories use a common three-stage contract: full local Docker,
disposable Docker staging in GitHub Actions, and production deployment of the exact
GHCR digest that passed staging. Production hosts pull images; they do not build
application source.

The Caddy data and configuration volumes are explicitly external. The bootstrap
creates them on a new host and reuses the existing `shared-caddy_caddy_data` and
`shared-caddy_caddy_config` volumes during a legacy cutover, so Compose teardown
cannot remove certificate state.

## Host contract

Any provider can host the platform when Terraform exposes:

```text
server_ipv4
deploy_user
acme_email
```

Application domain outputs remain optional provider-module conveniences. The
runtime needs Ubuntu, SSH key access, passwordless `sudo` for the deploy user, and
inbound TCP 22/80/443 (plus UDP 443 for HTTP/3).

## Bootstrap

Using Terraform outputs:

```bash
./scripts/deploy-vps-platform-from-tf.sh
```

Using any VPS directly:

```bash
./scripts/deploy-vps-platform.sh deploy <server-ip> admin@example.com
```

Run this only for a new host or a platform change. Normal application releases do
not invoke it.

## Application isolation

Public services join the external `vps-edge` network using stable aliases. Private
databases stay only on their application's default network. Current aliases are:

| App | Edge upstreams | Route owner |
| --- | --- | --- |
| Family Hub | `family-hub:8788` | `family-hub.caddy` |
| Paisa | `paisa-web:80`, `paisa-api:8080` | `paisa.caddy` |
| Novel Tracker | `novel-api:3000`, `novel-auth:8080` | `novel-tracker.caddy` |
| Drift | `drift-api:8080` | `drift.caddy` |

Each app uses a separate deployment lock. Route reloads use a short global lock.

`fitness` and `badge_creator` are intentionally not part of this conversion. Their
legacy host-port scripts must be migrated or retired before the platform cutover;
the new wrapper refuses to deploy them.

## One-time cutover from host ports

The old Caddy container used host networking and one generated Caddyfile containing
every app. The new Caddy container publishes 80/443 and connects to `vps-edge`.
Apply the transition as a coordinated maintenance operation:

1. Take and copy off-host database/application backups.
2. Lower relevant DNS TTLs if this is also a provider migration.
3. Confirm that no required legacy routes remain, then explicitly bootstrap the
   cutover. The safety flag is required when the current Caddyfile still contains
   host-port routes:

   ```bash
   ALLOW_LEGACY_ROUTE_CUTOVER=1 ./scripts/deploy-vps-platform-from-tf.sh
   ```

   The script saves the previous Caddy and Compose files as `*.pre-platform` under
   `/opt/shared-caddy` and preserves Caddy certificate volumes. Without the flag it
   refuses to replace a detected legacy Caddyfile.
4. Deploy Family Hub, Paisa, Novel Tracker, and Drift. Each release attaches its
   services and installs its own route.
5. Verify every public health endpoint before removing the previous host or files.

There can be a short routing interruption between steps 3 and 4. Do not bootstrap
the new platform during an ordinary single-app release.

Novel Tracker explicitly retains the existing `infra_postgres-data` Docker volume,
so changing its Compose project name does not create an empty production database.
Its first deployment stops and removes the old `infra` project containers without
removing volumes before starting `novel-tracker`; this prevents two PostgreSQL
processes from mounting the same data directory.

## Provider migration

Provision the destination host, bootstrap this platform, deploy app containers with
`VERIFY_PUBLIC_DEPLOYMENT=0`, restore state, then change DNS. Public verification is
enabled by default and should be re-enabled after cutover.
