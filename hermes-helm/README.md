# Hermes Agent Helm Chart

Deploy [Hermes Agent](https://hermes-agent.nousresearch.com/) and [Hermes Web UI](https://github.com/EKKOLearnAI/hermes-web-ui) on Kubernetes.

## Architecture

```
┌──────────────────────────────────────────────┐
│                   Ingress                     │
│              hermes.example.com               │
│            / → Web UI  :8648                  │
│           /api → Agent API :8642              │
└──────────────┬───────────────┬────────────────┘
               │               │
    ┌──────────▼──────┐  ┌────▼──────────────┐
    │  Hermes Web UI  │  │   Hermes Agent    │
    │  (Deployment)   │──│   (Deployment)    │
    │  Port: 8648     │  │   Ports: 8642,9119│
    │  Image:         │  │   Image:           │
    │  ekkoye8888/    │  │   nousresearch/    │
    │  hermes-web-ui  │  │   hermes-agent     │
    └────────┬────────┘  └────────┬───────────┘
             │                    │
             └──────────┬─────────┘
                        │
              ┌─────────▼──────────┐
              │    Persistent      │
              │   Volume Claim     │
              │   /opt/data        │
              │   (config, keys,   │
              │    sessions, logs) │
              └────────────────────┘
```

## Prerequisites

- Kubernetes 1.19+
- Helm 3.8+
- Persistent storage provisioner (for the data volume)
- API keys for Anthropic and/or OpenAI

## Quick Start

### 1. Create a values override file

```yaml
# my-values.yaml
secrets:
  anthropicApiKey: "sk-ant-..."      # Your Anthropic API key
  openaiApiKey: "sk-..."             # Your OpenAI API key (optional)
  apiServerKey: "my-secret-key-123"  # Min 8 chars, required for API server
  webuiAuthToken: ""                 # Auto-generated if empty

hermes:
  dashboard:
    enabled: true
    basicAuthUsername: "admin"
    basicAuthPassword: "changeme"

webui:
  env:
    CORS_ORIGINS: "*"

persistence:
  size: 20Gi

ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: hermes.example.com
      paths:
        - path: /
          pathType: Prefix
          serviceName: hermes-webui
          servicePort: 8648
```

### 2. Install the chart

```bash
helm install hermes ./hermes-helm -f my-values.yaml
```

### 3. Access the Web UI

```bash
# Port-forward if no ingress
kubectl port-forward svc/hermes-webui 8648:8648

# Then open http://localhost:8648
# Default login: admin / 123456
```

### 4. Check Hermes Agent status

```bash
# Check the agent logs
kubectl logs deployment/hermes-agent

# Port-forward the API
kubectl port-forward svc/hermes-agent 8642:8642

# Test the health endpoint
curl http://localhost:8642/health
```

## Configuration Reference

### Hermes Agent

| Parameter | Description | Default |
|-----------|-------------|---------|
| `hermes.enabled` | Enable agent deployment | `true` |
| `hermes.replicaCount` | Replicas (MUST be 1) | `1` |
| `hermes.image.repository` | Agent image | `nousresearch/hermes-agent` |
| `hermes.image.tag` | Image tag | `latest` |
| `hermes.resources.requests.memory` | Memory request | `1Gi` |
| `hermes.resources.limits.memory` | Memory limit | `4Gi` |
| `hermes.shmSize` | Shared memory for browser | `1Gi` |
| `hermes.dashboard.enabled` | Built-in dashboard | `false` |
| `hermes.service.type` | Service type | `ClusterIP` |

### Hermes Web UI

| Parameter | Description | Default |
|-----------|-------------|---------|
| `webui.enabled` | Enable Web UI deployment | `true` |
| `webui.image.repository` | Web UI image | `ekkoye8888/hermes-web-ui` |
| `webui.image.tag` | Image tag | `latest` |
| `webui.service.port` | Service port | `8648` |

### Secrets

| Parameter | Description |
|-----------|-------------|
| `secrets.anthropicApiKey` | Anthropic API key |
| `secrets.openaiApiKey` | OpenAI API key (optional) |
| `secrets.apiServerKey` | API server key (min 8 chars) |
| `secrets.webuiAuthToken` | Web UI auth token (auto-generated if empty) |

### Persistence

| Parameter | Description | Default |
|-----------|-------------|---------|
| `persistence.enabled` | Use PVC for data | `true` |
| `persistence.size` | Storage size | `10Gi` |
| `persistence.storageClass` | Storage class | `""` (default) |

## Important Notes

1. **Replica count must be 1** — Never run two Hermes gateway containers against the same data directory simultaneously.
2. **API server key required** — The Hermes Agent API server requires `secrets.apiServerKey` (minimum 8 characters).
3. **Web UI default credentials** — On first login, use `admin` / `123456`. Change immediately.
4. **Dashboard vs Web UI** — The built-in dashboard (`hermes.dashboard.enabled`) is optional when using the Web UI. The Web UI provides a richer interface.
5. **Data persistence** — All configuration, API keys, sessions, skills, and memories are stored in the persistent volume at `/opt/data`.
6. **Resource requirements** — Hermes Agent needs at least 1Gi memory; 4Gi is recommended for browser automation.
7. **Headless browser** — The Hermes Agent image includes Playwright + Chromium. The chart allocates 1Gi shared memory (`/dev/shm`) for browser automation.

## Automated Image Updates

Both projects (Hermes Agent and Hermes Web UI) are updated very frequently. There are three mechanisms to keep your deployment current:

### Option A: In-Cluster CronJob (simplest, included in chart)

Enable the built-in CronJob to perform rolling restarts — Kubernetes re-pulls the `:latest` image:

```yaml
# my-values.yaml
autoUpdate:
  enabled: true
  schedule: "0 3 * * *"  # Daily at 3 AM
```

**How it works:** A CronJob runs `kubectl rollout restart` on the Deployments. When pods restart with `imagePullPolicy: Always`, they pull the newest `latest` image. RBAC (ServiceAccount + Role + RoleBinding) is created automatically.

**Requirements:** You must be using `:latest` tag with `imagePullPolicy: Always`:

```yaml
hermes:
  image:
    tag: "latest"
    pullPolicy: Always
webui:
  image:
    tag: "latest"
    pullPolicy: Always
```

### Option B: Renovate Bot (GitHub CI, recommended for production)

This repo includes a [`renovate.json`](../renovate.json) config. Install the [Renovate GitHub App](https://github.com/apps/renovate) on your fork — it will automatically open PRs when new Docker tags are pushed. This gives you:

- Version-pinned tags (not `latest`) for reproducibility
- PR review before merging
- Auto-merge for patch updates (configurable)
- Change history in git

### Option C: GitHub Actions Image Check

The [`.github/workflows/image-check.yaml`](../.github/workflows/image-check.yaml) workflow runs daily and creates a GitHub Issue when new tags are detected. Less automated but requires no external bot.

---

## Publishing to ArtifactHub

[ArtifactHub](https://artifacthub.io/) is the go-to discovery platform for Helm charts.

### Step 1: Push chart to a GitHub repository

Ensure your chart is in a public GitHub repo (e.g., `https://github.com/YOUR_USER/hermes-agent-helm`).

### Step 2: Enable GitHub Pages

Go to **Settings → Pages** in your repo, set:
- Source: `Deploy from a branch`
- Branch: `gh-pages`, root (`/`)

### Step 3: Run the release workflow

The included [`.github/workflows/release.yaml`](../.github/workflows/release.yaml) will:

1. Lint and package the chart on every push to `main`
2. Publish `.tgz` packages and `index.yaml` to the `gh-pages` branch
3. Create a GitHub Release with the chart package attached

```bash
git add .
git commit -m "Release hermes-helm chart"
git push origin main
```

After the workflow completes, your Helm repository is served at:
`https://YOUR_USER.github.io/hermes-agent-helm/`

Verify:
```bash
helm repo add hermes-agent https://YOUR_USER.github.io/hermes-agent-helm/
helm repo update
helm search repo hermes-agent
```

### Step 4: Register on ArtifactHub

1. Go to **https://artifacthub.io/** → login with GitHub
2. Click **"Add Repository"** (or visit `https://artifacthub.io/control-panel/repositories/add`)
3. Choose **"Helm chart repository"**
4. Enter your repository URL: `https://YOUR_USER.github.io/hermes-agent-helm/`
5. ArtifactHub automatically scans `index.yaml` and lists all chart versions

Alternatively, add an **`artifacthub-repo.yml`** file to your `gh-pages` branch:

```yaml
# artifacthub-repo.yml
repositoryID: <uuid-from-artifacthub>
owners:
  - name: YOUR_NAME
    email: YOUR_EMAIL
```

For full documentation, see: https://artifacthub.io/docs/topics/repositories/

---

## Upgrading

```bash
helm upgrade hermes ./hermes-helm -f my-values.yaml
```

## Uninstall

```bash
# Uninstall but keep the PVC (data preserved)
helm uninstall hermes

# Uninstall and delete all data
helm uninstall hermes
kubectl delete pvc -l app.kubernetes.io/instance=hermes
```
