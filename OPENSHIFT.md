# ONLYOFFICE Docs on OpenShift 4.x

## Security Context Constraints (SCC)
> [!NOTE]
> OpenShift enforces strict security policies on pods. ONLYOFFICE Docs requires a compatible SCC because the DocumentServer containers run with non-root UID 101, but some SCCs may conflict with this requirement. Therefore, we recommend assigning the `nonroot-v2`, `anyuid` or [docs-components](./sources/scc/common.yaml) SCC to the relevant service accounts.

## Assign SCC to service accounts
> [!NOTE]
> Example below use the release name `documentserver`, because one of the service accounts created by the chart corresponds to the release name. The `wopi-sa` service account remains the same regardless of the release name.

> [!IMPORTANT]
> If required, enable the `podSecurityContext` and/or `containerSecurityContext` settings. Use the table below to check compatibility:

| SCC | podSecurityContext | containerSecurityContexts | Result |
|----------------|----------------------|----------------------------|--------|
| privileged | enabled | enabled | ✅Works |
| privileged | enabled | disabled | ✅Works |
| privileged | disabled | enabled | ✅Works |
| privileged | disabled | disabled | ❌Doesn't |
| nonroot | enabled | enabled | ❌Doesn't |
| nonroot | enabled | disabled | ❌Doesn't |
| nonroot | disabled | enabled | ❌Doesn't |
| nonroot | disabled | disabled | ❌Doesn't |
| nonroot-v2 | enabled | enabled | ✅Works |
| nonroot-v2 | enabled | disabled | ❌Doesn't |
| nonroot-v2 | disabled | enabled | ✅Works |
| nonroot-v2 | disabled | disabled | ❌Doesn't |
| anyuid | enabled | enabled | ❌Doesn't |
| anyuid | enabled | disabled | ✅Works |
| anyuid | disabled | enabled | ❌Doesn't |
| anyuid | disabled | disabled | ✅Works |
| scc-docs-components | enabled | enabled | ✅Works |
| scc-docs-components | enabled | disabled | ✅Works |
| scc-docs-components | disabled | enabled | ✅Works |
| scc-docs-components | disabled | disabled | ✅Works |
| docs-components | enabled | enabled | ✅Works |
| docs-components | enabled | disabled | ✅Works |
| docs-components | disabled | enabled | ✅Works |
| docs-components | disabled | disabled | ✅Works |

If you selected one of the default SCCs, assign it to the service accounts.

> [!IMPORTANT]
> You must have `cluster-admin` privileges to manage SCCs.
  
```bash
oc adm policy add-scc-to-user <SCC-name> -z documentserver -z wopi-sa
```

If you chose `scc-docs-components`. This SCC is the legacy version. We recommend using the `docs-components` SCC instead. If you still want to use the `scc-docs-components` execute the commands below:

```bash
oc apply -f https://raw.githubusercontent.com/ONLYOFFICE/Kubernetes-Docs/master/sources/scc/docs-components.yaml
oc adm policy add-scc-to-user scc-docs-components -z documentserver -z wopi-sa
```

If you chose `docs-components`, download the [common.yaml](./sources/scc/common.yaml) file. Update the `users` field to match the namespace where you are installing the chart, and then apply it:

```bash
curl -O https://raw.githubusercontent.com/ONLYOFFICE/Kubernetes-Docs/master/sources/scc/common.yaml
sed -i 's/<namespace>/your-namespace/g' common.yaml
oc apply -f common.yaml
```

> [!IMPORTANT]
> After assigning any SCC, set `serviceAccount.create` to `true`.

## Set the SCC annotation in the chart
To apply the required SCC to all resources:
```bash
--set commonAnnotations."openshift\.io/required-scc"="anyuid"
```

Or set it per resource:
```bash
--set docservice.annotations."openshift\.io/required-scc"="anyuid" \
--set converter.annotations."openshift\.io/required-scc"="anyuid" \
--set adminpanel.annotations."openshift\.io/required-scc"="anyuid" \
--set example.annotations."openshift\.io/required-scc"="anyuid" \
--set upgrade.job.annotations."openshift\.io/required-scc"="anyuid" \
--set rollback.job.annotations."openshift\.io/required-scc"="anyuid" \
--set delete.job.annotations."openshift\.io/required-scc"="anyuid" \
--set install.job.annotations."openshift\.io/required-scc"="anyuid" \
--set clearCache.job.annotations."openshift\.io/required-scc"="anyuid" \
--set grafanaDashboard.job.annotations."openshift\.io/required-scc"="anyuid" \
--set wopiKeysGeneration.job.annotations."openshift\.io/required-scc"="anyuid" \
--set wopiKeysDeletion.job.annotations."openshift\.io/required-scc"="anyuid" \
--set tests.annotations."openshift\.io/required-scc"="anyuid" \
```

## Enable security contexts
If you assigned an SCC that requires security contexts, enable them in the chart.
To enable `podSecurityContext`:

```bash
--set podSecurityContext.enabled=true \
```

To enable `containerSecurityContext`:
```bash
--set docservice.containerSecurityContext.enabled=true \
--set proxy.containerSecurityContext.enabled=true \
--set converter.containerSecurityContext.enabled=true \
--set adminpanel.containerSecurityContext.enabled=true \
--set example.containerSecurityContext.enabled=true \
--set upgrade.job.containerSecurityContext.enabled=true \
--set rollback.job.containerSecurityContext.enabled=true \
--set delete.job.containerSecurityContext.enabled=true \
--set install.job.containerSecurityContext.enabled=true \
--set clearCache.job.containerSecurityContext.enabled=true \
--set grafanaDashboard.job.containerSecurityContext.enabled=true \
--set wopiKeysGeneration.job.containerSecurityContext.enabled=true \
--set wopiKeysDeletion.job.containerSecurityContext.enabled=true \
--set tests.containerSecurityContext.enabled=true
```

## Publish ONLYOFFICE Docs via Route
To expose ONLYOFFICE Docs outside the OpenShift cluster, you can use an OpenShift Route. To enable route creation, set the following parameters:
```bash
--set openshift.route.enabled=true \
--set openshift.route.host=<HOSTNAME> \
--set openshift.route.path=<PATH>
```

> [!WARNING]
> TLS configuration is not managed by the chart. Configure TLS manually in the console after installation.

> [!TIP]
> For reference, here is an example route configuration on the `/docs` virtual path. Use it as a template if you need to create or modify the route manually:

```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: documentserver
  namespace: <NAMESPACE>
  annotations:
    haproxy.router.openshift.io/rewrite-target: /
spec:
  host: <HOSTNAME>
  path: /docs
  wildcardPolicy: <WILDCARD_POLICY>
  to:
    kind: Service
    name: documentserver
    weight: 100
  port:
    targetPort: 8888
  httpHeaders:
    actions:
      request:
        - name: X-Forwarded-Prefix
          action:
            type: Set
            set:
              value: /docs
```

## Example install command

> [!IMPORTANT]
> Deployment of dependencies such as RabbitMQ, Redis, and Database not included in the example below. Make sure to deploy them first or set the corresponding parameters to use external services.

Complete example of deploying ONLYOFFICE Docs on OpenShift with nonroot-v2 SCC and route enabled:

```bash
# execute with a user who has cluster-admin permissions
oc adm policy add-scc-to-user nonroot-v2 -z documentserver -z wopi-sa
oc adm policy who-can use scc nonroot-v2
# then, install the chart with any user
helm install documentserver onlyoffice/docs \
  --set serviceAccount.create=true \
  --set openshift.route.enabled=true \
  --set openshift.route.host=<HOSTNAME> \
  --set openshift.route.path=<PATH> \
  --set docservice.annotations."openshift\.io/required-scc"="nonroot-v2" \
  --set converter.annotations."openshift\.io/required-scc"="nonroot-v2" \
  --set adminpanel.annotations."openshift\.io/required-scc"="nonroot-v2" \
  --set example.annotations."openshift\.io/required-scc"="nonroot-v2" \
  --set upgrade.job.annotations."openshift\.io/required-scc"="nonroot-v2" \
  --set rollback.job.annotations."openshift\.io/required-scc"="nonroot-v2" \
  --set delete.job.annotations."openshift\.io/required-scc"="nonroot-v2" \
  --set install.job.annotations."openshift\.io/required-scc"="nonroot-v2" \
  --set clearCache.job.annotations."openshift\.io/required-scc"="nonroot-v2" \
  --set grafanaDashboard.job.annotations."openshift\.io/required-scc"="nonroot-v2" \
  --set wopiKeysGeneration.job.annotations."openshift\.io/required-scc"="nonroot-v2" \
  --set wopiKeysDeletion.job.annotations."openshift\.io/required-scc"="nonroot-v2" \
  --set tests.annotations."openshift\.io/required-scc"="nonroot-v2" \
  --set podSecurityContext.enabled=true \
  --set docservice.containerSecurityContext.enabled=true \
  --set proxy.containerSecurityContext.enabled=true \
  --set converter.containerSecurityContext.enabled=true \
  --set adminpanel.containerSecurityContext.enabled=true \
  --set example.containerSecurityContext.enabled=true \
  --set upgrade.job.containerSecurityContext.enabled=true \
  --set rollback.job.containerSecurityContext.enabled=true \
  --set delete.job.containerSecurityContext.enabled=true \
  --set install.job.containerSecurityContext.enabled=true \
  --set clearCache.job.containerSecurityContext.enabled=true \
  --set grafanaDashboard.job.containerSecurityContext.enabled=true \
  --set wopiKeysGeneration.job.containerSecurityContext.enabled=true \
  --set wopiKeysDeletion.job.containerSecurityContext.enabled=true \
  --set tests.containerSecurityContext.enabled=true
```
