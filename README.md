# Hermes Agent Helm Chart

Production-ready Helm chart for [Hermes Web UI](https://github.com/EKKOLearnAI/hermes-web-ui) on Kubernetes.  
The Web UI image is built on top of [Hermes Agent](https://hermes-agent.nousresearch.com/) (`FROM nousresearch/hermes-agent`) and includes the full Agent, Playwright/Chromium headless browser, and all tooling in a single container.

## Architecture

```
 Browser ───────────────────────────────────────────┐
                                                     │
 Kubernetes Cluster                                   │
 ┌───────────────────────────────────────────────────┤
 │  Traefik / Ingress (optional)                     │
 │  hermes.example.com → Web UI :8648                │
 │                                                   │
 │  ┌────────────────────────────────────────────┐   │
 │  │          Hermes Web UI (single pod)         │   │
 │  │  ┌──────────────┐  ┌────────────────────┐  │   │
 │  │  │  Web UI      │  │  Hermes Agent      │  │   │
 │  │  │  Vue + Koa   │◀▶│  (managed gateway) │──┼───┼──▶ LLM APIs
 │  │  │  :8648       │  │  :8642 (internal)  │  │   │
 │  │  └──────────────┘  └────────────────────┘  │   │
 │  │  ┌──────────────────────────────────────┐  │   │
 │  │  │  Persistent Volume                   │  │   │
 │  │  │  /home/agent/.hermes                 │  │   │
 │  │  │  (config, sessions, skills, memory)  │  │   │
 │  │  └──────────────────────────────────────┘  │   │
 │  └────────────────────────────────────────────┘   │
 └───────────────────────────────────────────────────┘
```

## Quick Start

```bash
helm repo add hermes-agent https://0xbitwild.github.io/Hermes-Agent-Helm-Chart/
helm repo update
helm install hermes hermes-agent/hermes-agent \
  --set secrets.anthropicApiKey="sk-ant-..." \
  --set traefik.enabled=true \
  --set traefik.host="hermes.example.com" \
  --set traefik.tlsSecretName="example-tls"
```

Default login: `admin` / `123456` (change immediately).

## Configuration

See [`hermes-helm/values.yaml`](hermes-helm/values.yaml) for all options.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `secrets.anthropicApiKey` | Anthropic API key | `""` |
| `traefik.enabled` | Enable Traefik IngressRoute | `false` |
| `traefik.host` | Domain name | `hermes.example.com` |
| `traefik.tlsSecretName` | TLS secret name | `""` |
| `web_ui.resources.limits.memory` | Memory limit | `4Gi` |
| `web_ui.resources.limits.cpu` | CPU limit | `2` |
| `persistence.size` | PVC storage size | `10Gi` |

## Requirements

- Kubernetes 1.19+
- Helm 3.8+
- Persistent storage provisioner
- Anthropic API key

## License

MIT
