# Exposing ONLYOFFICE Docs via Kubernetes Ingress

This guide provides instructions and examples on how to expose ONLYOFFICE Docs 
on a virtual path (e.g., `/docs`) using Kubernetes Ingress. It covers the necessary
steps to configure Ingress resources and ensure that your ONLYOFFICE Docs deployment
is accessible via a specified domain and path.

## Prerequisites

> [!WARNING]
> Before you begin, ensure that you have installed and configured an Ingress controller in your cluster.
> For detailed setup instructions, refer to your controller's documentation.

## Configuring Ingress for ONLYOFFICE Docs

Once the Ingress controller is configured and ready, set ingress parameters:

- `ingress.enabled`: Enables Ingress resource creation.
- `ingress.ingressClassName`: Specifies the Ingress class to use.
- `ingress.controllerName`: Used to distinguish controllers that share the same ingress class name.
- `ingress.host`: The domain name to access ONLYOFFICE Docs (e.g., `docs.example.com`).
- `ingress.tenants`: A list of hostnames for multi-tenant setups.
- `ingress.ssl.enabled`: Enables SSL/TLS for secure communication.
- `ingress.ssl.secret`: The name of the Kubernetes secret containing the SSL/TLS certificate and private key.
- `ingress.path`: The path to route traffic to ONLYOFFICE Docs (e.g., `/`, `/docs`).
- `ingress.pathType`: The type of path matching to use (e.g., `Prefix`, `Exact`, `ImplementationSpecific`).
- `ingress.letsencrypt.enabled`: Enables Let's Encrypt integration for automatic SSL/TLS certificate management.
- `ingress.letsencrypt.clusterIssuerName`: The name of the ClusterIssuer resource to use for Let's Encrypt.
- `ingress.letsencrypt.email`: The email address to use for Let's Encrypt registration and recovery.
- `ingress.letsencrypt.server`: The Let's Encrypt server URL (e.g., `https://acme-v02.api.letsencrypt.org/directory`).
- `ingress.letsencrypt.secretName`: The name of the Kubernetes secret to store the Let's Encrypt certificate and private key.

> [!IMPORTANT]
> To use ingress.letsencrypt.* parameters, you must have cert-manager installed and configured in your cluster.
> It will handle the issuance and renewal of SSL/TLS certificates from Let's Encrypt.
> Check out the [cert-manager documentation](https://cert-manager.io/docs/usage/ingress/) for detailed instructions.

## Configuration Examples

The ONLYOFFICE Docs Helm chart includes built-in virtual-path configuration for these
ingress controllers:

- [NGINX Ingress Controller by Kubernetes](#configuration-with-nginx-ingress-controller-by-kubernetes)
- [NGINX Ingress Controller by NGINX](#configuration-with-nginx-ingress-controller-by-nginx)
- [HAProxy Ingress Controller](#configuration-with-haproxy-ingress-controller)

For other controllers, configure ingress manually as shown in the examples below and
set `ingress.enabled=false`.

If you need to expose ONLYOFFICE Docs at the root path `/`, set at least:

- `ingress.enabled=true`
- `ingress.host=<your_domain>`
- `ingress.path=/`
- `ingress.ingressClassName=<your_ingress_class>`
- `ingress.controllerName=""`

No additional rewrite and header settings are required for root-path exposure.

> [!WARNING]
> For simplicity, the TLS configuration is omitted in the examples below.

### Configuration with [NGINX Ingress Controller by Kubernetes](https://github.com/kubernetes/ingress-nginx)

For virtual path configuration, append the pattern `(/|$)(.*)` to the `ingress.path`.

```bash
helm install documentserver onlyoffice/docs \
  --set ingress.enabled=true \
  --set ingress.ingressClassName=nginx \
  --set ingress.controllerName=ingress-nginx \
  --set ingress.host=docs.example.com \
  --set ingress.path='/docs(/|$)(.*)'
```

or apply the following Ingress resource:

```yml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: documentserver
  namespace: <NAMESPACE>
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: 100m
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/x-forwarded-prefix: "/docs"
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
  - host: docs.example.com
    http:
      paths:
      - path: /docs(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: documentserver
            port:
              number: 8888
```

### Configuration with [NGINX Ingress Controller by NGINX](https://github.com/nginx/kubernetes-ingress/)

```bash
helm install documentserver onlyoffice/docs \
  --set ingress.enabled=true \
  --set ingress.ingressClassName=nginx \
  --set ingress.controllerName=nginx-ingress \
  --set ingress.host=docs.example.com \
  --set ingress.path=/docs
```

or apply the following Ingress resource:

```yml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: documentserver
  namespace: <NAMESPACE>
  annotations:
    nginx.org/client-max-body-size: 100m
    nginx.org/websocket-services: "documentserver"
    nginx.org/rewrites: "serviceName=documentserver rewrite=/"
    nginx.org/proxy-set-headers: |
      X-Forwarded-Prefix: /docs,
      X-Scheme
spec:
  ingressClassName: nginx
  rules:
  - host: docs.example.com
    http:
      paths:
      - path: /docs/
        pathType: ImplementationSpecific
        backend:
          service:
            name: documentserver
            port:
              number: 8888
```

### Configuration with [HAProxy Ingress Controller](https://github.com/haproxytech/kubernetes-ingress/)

```bash
helm install documentserver onlyoffice/docs \
  --set ingress.enabled=true \
  --set ingress.ingressClassName=haproxy \
  --set ingress.controllerName=haproxytech \
  --set ingress.host=docs.example.com \
  --set ingress.path=/docs
```

or apply the following Ingress resource:

```yml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: documentserver
  namespace: <NAMESPACE>
  annotations:
    haproxy.org/backend-config-snippet: |
      acl existing-x-forwarded-host req.hdr(X-Forwarded-Host) -m found
      http-request add-header X-Forwarded-Prefix /docs unless existing-x-forwarded-host
      http-request replace-path /docs[/]?(.*) /\1
spec:
  ingressClassName: haproxy
  rules:
  - host: docs.example.com
    http:
      paths:
      - path: /docs/
        pathType: ImplementationSpecific
        backend:
          service:
            name: documentserver
            port:
              number: 8888
```

### Configuration with [Traefik Ingress Controller](https://github.com/traefik/traefik-helm-chart/tree/master/traefik)

```yml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: documentserver-headers
  namespace: <NAMESPACE>
spec:
  stripPrefix:
    prefixes:
      - /docs
```

```yml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: documentserver
  namespace: <NAMESPACE>
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: "<NAMESPACE>-documentserver-headers@kubernetescrd"
spec:
  ingressClassName: traefik
  rules:
  - host: docs.example.com
    http:
      paths:
      - path: /docs
        pathType: Prefix
        backend:
          service:
            name: documentserver
            port:
              number: 8888
```

### Configuration with [Kong Ingress Controller](https://github.com/Kong/charts/tree/main/charts/ingress)

```yml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: documentserver
  namespace: <NAMESPACE>
  annotations:
    konghq.com/strip-path: "true"
spec:
  ingressClassName: kong
  rules:
  - host: docs.example.com
    http:
      paths:
      - path: /docs
        pathType: Prefix
        backend:
          service:
            name: documentserver
            port:
              number: 8888
```

### Configuration with [Azure Application Gateway Ingress Controller](https://github.com/Azure/application-gateway-kubernetes-ingress)

```yml
apiVersion: appgw.ingress.azure.io/v1beta1
kind: AzureApplicationGatewayRewrite
metadata:
  name: documentserver-rewrite
  namespace: <NAMESPACE>
spec:
  rewriteRules:
  - name: rewrite-docs
    ruleSequence: 1
    actions:
      requestHeaderConfigurations:
        - actionType: set
          headerName: X-Forwarded-Prefix
          headerValue: /docs
```

```yml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: documentserver
  namespace: <NAMESPACE>
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
    appgw.ingress.kubernetes.io/backend-protocol: http
    appgw.ingress.kubernetes.io/backend-path-prefix: "/"
    appgw.ingress.kubernetes.io/rewrite-rule-set-custom-resource: documentserver-rewrite
spec:
  rules:
  - host: docs.example.com
    http:
      paths:
      - path: /docs
        pathType: Prefix
        backend:
          service:
            name: documentserver
            port:
              number: 8888
```

### Configuration with [Azure Application Gateway for Containers](https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/)

```yml
apiVersion: alb.networking.azure.io/v1
kind: IngressExtension
metadata:
  name: documentserver
  namespace: <NAMESPACE>
spec:
  rules:
    - host: docs.example.com
      rewrites:
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
```

```yml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: documentserver
  namespace: <NAMESPACE>
  annotations:
    alb.networking.azure.io/alb-name: <ALB_NAME>
    alb.networking.azure.io/alb-namespace: <ALB_NAMESPACE>
    alb.networking.azure.io/alb-ingress-extension: documentserver
spec:
  ingressClassName: azure-alb-external
  rules:
    - host: docs.example.com
      http:
        paths:
          - path: /docs
            pathType: Prefix
            backend:
              service:
                name: documentserver
                port:
                  number: 8888
```

> [!IMPORTANT]
> Other Ingress controllers are not validated for virtual path configuration due to limitations in their configuration options.
> They may still work if they support path rewriting and header modification. If your controller lacks these capabilities,
> use root path `/` or Gateway API.
