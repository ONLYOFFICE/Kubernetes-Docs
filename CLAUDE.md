## Project Overview

Kubernetes-Docs — Helm chart (`docs`) deploying ONLYOFFICE Docs (Document Server) to Kubernetes or OpenShift. Runs docservice, converter, proxy, adminpanel and example as separate deployments; container images come from the sibling `Docker-Docs-SaaS` repo (onlyoffice/docs-docservice-de, docs-converter-de, docs-proxy-de, docs-adminpanel-de, docs-example, docs-utils).

## Tech Stack

Helm 3, Kubernetes (>=1.19), OpenShift, Go templates, GitHub Actions, external PostgreSQL/MySQL + Redis + RabbitMQ (bitnami charts), NFS/RWX storage

## Project Structure

```
Chart.yaml          — chart metadata (name: docs; appVersion = Docs release)
values.yaml         — all chart parameters (large, ~2.5k lines; single source of defaults)
templates/          — manifests: configmaps/, deployments/, jobs/, ingresses/, gateway/, hpa/, pvc/, RBAC/, _helpers.tpl, NOTES.txt
sources/            — auxiliary manifests: extraScrapeConfigs.yaml, custom-resources examples, scc/ (OpenShift), scripts/, metrics/, litmus/
docs/               — CUSTOM_RESOURCES.md, HPA_CUSTOM_METRICS.md, OPENSHIFT.md
.github/workflows/  — lint.yaml (shared ONLYOFFICE/ga-common helm-lint + deprecated-resources), helm-test.yaml (minikube + chart-testing), 4testing_repo.yaml / stable_repo.yaml (chart publishing)
CHANGELOG.md
```

## Build & Run

```bash
# Lint / render locally
helm lint .
helm template documentserver .

# Install from the published repo
helm repo add onlyoffice https://download.onlyoffice.com/charts/stable
helm install documentserver onlyoffice/docs

# Upgrade (skip hooks when only changing parameters, not the version)
helm upgrade documentserver -f ./values.yaml onlyoffice/docs --no-hooks

# Uninstall (delete hooks stop the server and clean PVC/DB; allow time)
helm delete documentserver --timeout 25m
```

## Key Patterns

- All state is external: PostgreSQL/MySQL, Redis, RabbitMQ installed separately (bitnami charts); shared RWX PVC for cache/files
- `values.yaml` top-level blocks per component: `docservice`, `converter`, `proxy`, `adminpanel`, `example`, plus `connections`, `persistence`, `jwt`, `license`, `ingress`, `gateway`, `openshift`
- Helm hooks drive lifecycle: `install`/`upgrade`/`delete` jobs run `onlyoffice/docs-utils` (DB init, shutdown, cleanup) — `--no-hooks` skips them
- JWT enabled by default (`jwt.*`); license via `license.existingSecret`
- Exposure options: ingress, LoadBalancer service, or Gateway API (`gateway.enabled`)
- OpenShift support via SCC manifests in `sources/scc/` and `openshift.*` values
- Comment lines above each key in `values.yaml` are the parameter docs — keep README table and values comments in sync

## Review Focus

**Templates**: helper usage in `_helpers.tpl`, label/selector consistency, hook annotations and weights
**Values**: every new key documented in README parameter table; defaults safe; no precise image tags hardcoded in templates
**Hooks**: job idempotency, `--no-hooks` upgrade path still works, timeouts
**Security**: JWT defaults, secrets via existingSecret patterns, pod/container securityContext toggles
**Compatibility**: Kubernetes >=1.19 and OpenShift (SCC, restricted SCC-compatible defaults)

## Git Workflow

- **Main branch**: `master`
- **Integration branch**: `develop`
- **Branch naming**: `feature/*`, `release/v*` (e.g. `release/v6.2.0`)
- Update `CHANGELOG.md` and bump `version` in `Chart.yaml` for release changes
