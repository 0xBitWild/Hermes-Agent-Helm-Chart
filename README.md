# Hermes Helm Charts

Production-ready Helm charts for Kubernetes, served as a Helm repository via GitHub Pages.

```bash
helm repo add 0xbitwild https://0xbitwild.github.io/Charts/
helm repo update
helm search repo 0xbitwild
```

## Available Charts

| Chart | Description |
|-------|-------------|
| [hermes-web-ui](charts/hermes-web-ui) | [Hermes Web UI](https://github.com/EKKOLearnAI/hermes-web-ui) — a single pod bundling the full [Hermes Agent](https://hermes-agent.nousresearch.com/) (`FROM nousresearch/hermes-agent`), Playwright/Chromium headless browser, and managed gateway. |
| [docker-proxy](charts/docker-proxy) | Pull-through registry mirror proxies (Docker Hub, GCR, GHCR, Quay, `registry.k8s.io`, MCR, Elastic, NVCR, …) plus optional hosted private registries, behind Traefik. |

## Usage

```bash
# Install a chart
helm install my-release 0xbitwild/<chart-name>

# Show configurable values
helm show values 0xbitwild/<chart-name>

# Upgrade / uninstall
helm upgrade my-release 0xbitwild/<chart-name>
helm uninstall my-release
```

Example — install Hermes Web UI behind Traefik:

```bash
helm install hermes 0xbitwild/hermes-web-ui \
  --set secrets.anthropicApiKey="sk-ant-..." \
  --set traefik.enabled=true \
  --set traefik.host="hermes.example.com" \
  --set traefik.tlsSecretName="example-tls"
```

See the chart's own README for full configuration: **[charts/hermes-web-ui](charts/hermes-web-ui/README.md)**.

## Requirements

- Kubernetes 1.19+
- Helm 3.8+
- A persistent storage provisioner

## License

MIT
