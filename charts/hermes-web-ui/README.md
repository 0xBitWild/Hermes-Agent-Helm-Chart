# Hermes Agent Helm Chart

Production-ready Helm chart for [Hermes Web UI](https://github.com/EKKOLearnAI/hermes-web-ui) on Kubernetes.

The Web UI image is built on top of [Hermes Agent](https://hermes-agent.nousresearch.com/)
(`FROM nousresearch/hermes-agent`) and bundles the **full Agent**, the Playwright/Chromium
headless browser, and all tooling in a **single container**. The chart therefore deploys
**one pod** — the Web UI manages its own internal Hermes gateway. There is no separate Agent
deployment.

## Architecture

```
 Browser
    │
 ┌──┴────────────────────────────────────────────────┐
 │ Kubernetes Cluster                                 │
 │  Traefik / Ingress (optional)                      │
 │  hermes.example.com → Web UI :8648                 │
 │                                                    │
 │  ┌──────────────────────────────────────────────┐ │
 │  │           Hermes Web UI (single pod)          │ │
 │  │  ┌──────────────┐   ┌────────────────────┐   │ │
 │  │  │  Web UI      │   │  Hermes Agent      │   │ │
 │  │  │  Vue + Koa   │◀─▶│  (managed gateway) │───┼─┼──▶ LLM APIs
 │  │  │  :8648       │   │  :8642 (internal)  │   │ │
 │  │  └──────────────┘   └────────────────────┘   │ │
 │  │  ┌────────────────────────────────────────┐  │ │
 │  │  │  Persistent Volume                     │  │ │
 │  │  │  /home/agent/.hermes                   │  │ │
 │  │  │  (config, sessions, skills, memory)    │  │ │
 │  │  └────────────────────────────────────────┘  │ │
 │  └──────────────────────────────────────────────┘ │
 └────────────────────────────────────────────────────┘
```

## Prerequisites

- Kubernetes 1.19+
- Helm 3.8+
- A persistent storage provisioner (for the data volume)
- An Anthropic and/or OpenAI API key

## Quick Start

```bash
helm repo add 0xbitwild https://0xbitwild.github.io/Charts/
helm repo update

helm install hermes 0xbitwild/hermes-web-ui \
  --set secrets.anthropicApiKey="sk-ant-..." \
  --set traefik.enabled=true \
  --set traefik.host="hermes.example.com" \
  --set traefik.tlsSecretName="example-tls"
```

Or with a values override file:

```yaml
# my-values.yaml
secrets:
  anthropicApiKey: "sk-ant-..."   # required
  openaiApiKey: "sk-..."          # optional
  # apiServerKey / webuiAuthToken are auto-generated if left empty

persistence:
  size: 20Gi

traefik:
  enabled: true
  host: "hermes.example.com"
  tlsSecretName: "hermes-tls"
```

```bash
helm install hermes 0xbitwild/hermes-web-ui -f my-values.yaml
```

### Access the Web UI

```bash
# Port-forward if you have no ingress
kubectl port-forward svc/hermes-web-ui 8648:8648
# Then open http://localhost:8648
```

Default login: **`admin` / `123456`** — change it immediately.

The auto-generated API key can be read after install:

```bash
kubectl get secret hermes-web-ui -o jsonpath='{.data.API_SERVER_KEY}' | base64 -d
```

## Configuration Reference

### Web UI

| Parameter | Description | Default |
|-----------|-------------|---------|
| `web_ui.enabled` | Enable the Web UI deployment | `true` |
| `web_ui.replicaCount` | Replicas (MUST be 1) | `1` |
| `web_ui.image.repository` | Image repository | `ekkoye8888/hermes-web-ui` |
| `web_ui.image.tag` | Image tag (empty → chart `appVersion`) | `""` |
| `web_ui.image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `web_ui.env.PORT` | Listen port | `8648` |
| `web_ui.env.CORS_ORIGINS` | Allowed CORS origins | `*` |
| `web_ui.resources.requests.memory` | Memory request | `512Mi` |
| `web_ui.resources.limits.memory` | Memory limit | `4Gi` |
| `web_ui.resources.limits.cpu` | CPU limit | `2` |
| `web_ui.service.type` | Service type | `ClusterIP` |
| `web_ui.service.port` | Service port | `8648` |

### Secrets

| Parameter | Description |
|-----------|-------------|
| `secrets.anthropicApiKey` | Anthropic API key |
| `secrets.openaiApiKey` | OpenAI API key (optional) |
| `secrets.telegramBotToken` | Telegram bot token (optional) |
| `secrets.apiServerKey` | API server key (auto-generated if empty) |
| `secrets.webuiAuthToken` | Web UI auth token (auto-generated if empty) |
| `secrets.existingSecret` | Use an existing Secret instead of creating one |

Auto-generated keys are preserved across `helm upgrade` (the Secret carries
`helm.sh/resource-policy: keep` and values are re-read via `lookup`).

### Persistence

| Parameter | Description | Default |
|-----------|-------------|---------|
| `persistence.enabled` | Use a PVC for data | `true` |
| `persistence.size` | Storage size | `10Gi` |
| `persistence.storageClass` | Storage class (empty = default) | `""` |
| `persistence.existingClaim` | Use an existing PVC | `""` |
| `persistence.hermesMountPath` | Hermes data path | `/home/agent/.hermes` |

### Traefik IngressRoute

| Parameter | Description | Default |
|-----------|-------------|---------|
| `traefik.enabled` | Generate a Traefik IngressRoute + HTTP→HTTPS redirect | `false` |
| `traefik.host` | Domain name | `hermes.example.com` |
| `traefik.tlsSecretName` | TLS certificate secret name | `""` |
| `traefik.httpEntryPoint` | HTTP entry point | `web` |
| `traefik.httpsEntryPoint` | HTTPS entry point | `websecure` |

### Ingress (standard Kubernetes Ingress)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable a standard Ingress | `false` |
| `ingress.className` | Ingress class name | `""` |
| `ingress.hosts` | Host rules (service `hermes-web-ui`, port `8648`) | see values |

Use **either** `traefik.*` (IngressRoute CRD) **or** `ingress.*` (standard Ingress) — not both.

## Important Notes

1. **Replica count must be 1** — never run two gateways against the same data directory.
2. **Single pod** — the Web UI bundles the full Hermes Agent and a headless Chromium; there is
   no separate Agent deployment.
3. **API keys are optional to set** — `apiServerKey` and `webuiAuthToken` are auto-generated and
   stay stable across upgrades.
4. **Data persistence** — all config, API keys, sessions, skills and memory live in the PVC at
   `/home/agent/.hermes`.
5. **Image tag** — the default image tag follows the chart `appVersion`, so each chart release
   pins a concrete, reproducible Web UI version.

## Automated Updates

The repository's CI watches the upstream Web UI image and **automatically bumps `appVersion`
(and the chart version) and publishes a new release** when a new stable `vX.Y.Z` tag is
published — see [`.github/workflows/image-check.yaml`](../../.github/workflows/image-check.yaml). A
[`renovate.json`](../../renovate.json) is also provided if you prefer the Renovate GitHub App.

## Upgrading

```bash
helm upgrade hermes 0xbitwild/hermes-web-ui -f my-values.yaml
```

## Uninstall

```bash
# Uninstall (the PVC and Secret are kept by resource-policy: keep)
helm uninstall hermes

# To also delete the data:
kubectl delete pvc,secret -l app.kubernetes.io/instance=hermes
```

## License

MIT
