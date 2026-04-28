# Exposing ONLYOFFICE Docs via Gateway API

This guide explains how to expose ONLYOFFICE Docs using the Gateway API, a Kubernetes standard for managing ingress traffic. The Gateway API offers greater flexibility and features compared to traditional Ingress resources, enabling advanced routing, TLS management, and traffic control.

## Prerequisites

> [!WARNING]
> Before you begin, ensure that you have installed and configured a Gateway API controller in your cluster. For detailed setup instructions, refer to your controller's official documentation.

Create or use an existing Gateway resource. The HTTPRoute will reference this Gateway to route traffic to ONLYOFFICE Docs. If you require secure connections via HTTPS, create a TLS secret using your certificate and reference it in the Gateway configuration, or use cert-manager for automatic certificate management.

```bash
kubectl create secret tls <TLS_SECRET_NAME> \
  --cert=path/to/cert.crt \
  --key=path/to/private.key \
  --namespace <NAMESPACE>
```

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: <GATEWAY_NAME>
  namespace: <NAMESPACE>
spec:
  gatewayClassName: <GATEWAY_CLASS_NAME>
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    hostname: "*.example.com"  # Adjust to your domain
  - name: https
    protocol: HTTPS
    port: 443
    hostname: "*.example.com"  # Adjust to your domain
    tls:
      certificateRefs:
      - kind: Secret
        name: <TLS_SECRET_NAME>
```

> [!IMPORTANT]
> To use cert-manager as a certificate provider for your Gateway, check out the [cert-manager documentation](https://cert-manager.io/docs/usage/gateway/) for detailed instructions.

## Configuring HTTPRoute for ONLYOFFICE Docs

Once the Gateway is configured and ready, use HTTPRoute to route traffic to ONLYOFFICE Docs. Set the following parameters during installation or upgrade:

- `httproute.enabled=true`: Enables HTTPRoute creation.
- `httproute.path`: The path for ONLYOFFICE Docs (e.g., `/` for root or `/docs` for virtual path routing).
- `httproute.hostnames`: An array of hostnames (e.g., `["docs.example.com"]`).
- `httproute.parentRefs`: References to the Gateway's name and namespace.

### Quick Start Example

```bash
helm install documentserver onlyoffice/docs \
  --namespace default \
  --set httproute.enabled=true \
  --set httproute.path=/ \
  --set httproute.hostnames[0]="docs.example.com" \
  --set httproute.parentRefs[0].name="docs-gateway" \
  --set httproute.parentRefs[0].namespace="default"
```

### Manual HTTPRoute Configuration

> [!TIP]
> The Helm chart automatically configures URL rewriting and headers for the HTTPRoute. Use this template only if you need to create or modify it manually:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: documentserver
  namespace: <NAMESPACE>
spec:
  hostnames:
  - docs.example.com  # Adjust to your domain
  parentRefs:
  - name: <GATEWAY_NAME>
    namespace: <NAMESPACE>
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /docs
    filters:
    - type: URLRewrite
      urlRewrite:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /
    - type: RequestHeaderModifier
      requestHeaderModifier:
        set:
        - name: X-Forwarded-Prefix
          value: /docs
    backendRefs:
    - name: documentserver
      kind: Service
      port: 8888
      weight: 100
```
