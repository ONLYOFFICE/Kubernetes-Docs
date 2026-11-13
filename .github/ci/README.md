# Chart e2e tests

Workflow: `.github/workflows/chart-e2e.yaml`. Runs on every PR and manually (Actions → Chart e2e → Run workflow).

| Job | Cluster | What is checked |
|---|---|---|
| `k8s (install)` | kind | clean install, `helm test`, smoke |
| `k8s (upgrade)` | kind | install from the base branch → upgrade to the PR chart, `helm test`, smoke |
| `k8s (chaos)` | kind | clean install, then resilience scenarios (see below) |
| `OpenShift (<scc>, …)` | MicroShift (OKD) | install under `docs-components` / `anyuid` / `nonroot-v2` SCC, Route, `helm test`, smoke, SCC check |

Dependencies are installed as described in `README.md` and `docs/DEPENDENCIES.md`
(NFS Server Provisioner, cert-manager, RabbitMQ Cluster Operator, CloudNativePG, Valkey operator),
scaled down to a single node, in namespace `deps`. Docs is installed as `documentserver` in namespace `docs`.

## Which images are tested

CI does not build images: it uses what `ONLYOFFICE/Docker-Docs` has already pushed to Docker Hub.

| source | images |
|---|---|
| `release` | `onlyoffice/docs-*:<tag>` |
| `4testing` | `onlyoffice/4testing-docs-*:<tag>` (Docker-Docs `build.yaml` with "Push to 4testing") |
| `4testing-latest` (default for PRs into `release/*` and `hotfix/*`) | most recently pushed `onlyoffice/4testing-docs-*:<appVersion>-<N>` or `<appVersion>-rc.<N>` that exists for every chart image. `<appVersion>` is taken from `Chart.yaml` (`10.0.3` → `10.0.3-40` or `10.0.3-rc.36`). Falls back to `auto` if nothing is found |
| `auto` (default for other PRs) | most recently pushed `<appVersion>-<N>` / `-rc.<N>` build of `appVersion` from `Chart.yaml`: `release` if it exists, otherwise `4testing`, otherwise the run fails |

Override in the PR description (re-run the jobs after editing it):

```
ci-images-source: 4testing
ci-images-tag: 10.0.0-12
```

## Smoke tests

`smoke/smoke.py`, stdlib only. Add a function with `@check`. Env: `DS_URL`, `JWT_SECRET`, `FIXTURE_URL`.
Test files for conversion are served from `smoke/fixtures.yaml`.

## Chaos scenarios

`chaos/chaos.sh`, runs after `deploy-test.sh` in the `k8s (chaos)` job. Each scenario injects a fault,
removes it and requires Docs to recover **by itself** within `RECOVERY_TIMEOUT`, then runs a quick smoke subset.
Recovery is measured in two steps: first the infrastructure (all pods in `deps` and the NFS server Ready,
with at least as many pods as before the scenario), then Docs (pods in `docs` Ready, `/healthcheck` = `true`).

| group | scenarios | tool |
|---|---|---|
| Docs pods | `docservice-kill`, `converter-kill`, `convert-converter-down` (conversion requested while no converter runs) | kubectl |
| dependencies | `postgres-kill`, `pgbouncer-kill`, `rabbitmq-kill`, `valkey-kill`, `nfs-server-kill` | kubectl |
| network / resources | `net-partition-postgres`, `net-partition-rabbitmq`, `net-delay-deps` (smoke during the fault), `cpu-stress-converter` (smoke during the fault) | Chaos Mesh (`chaos/mesh/*.yaml`) |
| node | `node-restart` (`docker restart` of the kind node) | docker |

Chaos Mesh experiments must reach `AllInjected` and select at least one container, otherwise the scenario fails
(a fault that was never injected would pass silently). Removal waits for Chaos Mesh's finalizer, i.e. full recovery.

Job summary columns:

| column | meaning |
|---|---|
| outage | longest continuous period with `/healthcheck` != `true`, by timestamps |
| infra | fault removed → `deps` + NFS pods Ready again (time the dependency itself needs) |
| Docs lag | infra Ready → Docs Ready and healthy (Docs' own reconnect / recovery time) |
| smoke | duration of the smoke subset after recovery: catches hangs `/healthcheck` does not see (storage) |
| Docs restarts | container restarts in `docs` during the scenario; expected only for `node-restart` |

Docs is reached through a NodePort (`chaos/nodeport.yaml`): `kubectl port-forward` dies with the pod it is bound to.

Env: `CHAOS_ONLY` / `CHAOS_SKIP` (regex), `CHAOS_MESH=1`, `FAULT_DURATION`, `RECOVERY_TIMEOUT`,
thresholds (report only when unset): `MAX_DOWNTIME`, `MAX_DOCS_LAG`, `MAX_SMOKE`.
Add a scenario: a function that injects and removes the fault, plus `run <name> <function> [args]`.

## Secrets (optional)

- `DOCKER_HUB_USERNAME`, `DOCKER_HUB_ACCESS_TOKEN` – authenticated Docker Hub pulls
