{{/*
Expand the name of the chart.
*/}}
{{- define "docker-proxy.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Chart name and version as used by the chart label.
*/}}
{{- define "docker-proxy.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels (chart-wide).
*/}}
{{- define "docker-proxy.labels" -}}
helm.sh/chart: {{ include "docker-proxy.chart" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ include "docker-proxy.name" . }}
{{- end }}

{{/*
Per-registry resource name: <namePrefix><name> (e.g. registry-hub).
Usage: include "docker-proxy.registryName" (dict "ctx" $ "reg" .)
*/}}
{{- define "docker-proxy.registryName" -}}
{{- $ctx := .ctx -}}
{{- $reg := .reg -}}
{{- printf "%s%s" $ctx.Values.namePrefix $reg.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Per-registry selector labels.
Usage: include "docker-proxy.selectorLabels" (dict "ctx" $ "reg" .)
*/}}
{{- define "docker-proxy.selectorLabels" -}}
{{- $ctx := .ctx -}}
{{- $reg := .reg -}}
app.kubernetes.io/name: {{ include "docker-proxy.registryName" (dict "ctx" $ctx "reg" $reg) }}
app.kubernetes.io/instance: {{ $ctx.Release.Name }}
k8s-app: {{ include "docker-proxy.registryName" (dict "ctx" $ctx "reg" $reg) }}
{{- end }}

{{/*
Per-registry fully-labelled set.
Usage: include "docker-proxy.registryLabels" (dict "ctx" $ "reg" .)
*/}}
{{- define "docker-proxy.registryLabels" -}}
{{- $ctx := .ctx -}}
{{- $reg := .reg -}}
{{ include "docker-proxy.labels" $ctx }}
{{ include "docker-proxy.selectorLabels" (dict "ctx" $ctx "reg" $reg) }}
docker-proxy/role: {{ if $reg.upstream }}mirror{{ else }}hosted{{ end }}
{{- end }}

{{/*
Per-registry hostname: <host|name>.<domain>.
Usage: include "docker-proxy.registryHost" (dict "ctx" $ "reg" .)
*/}}
{{- define "docker-proxy.registryHost" -}}
{{- $ctx := .ctx -}}
{{- $reg := .reg -}}
{{- printf "%s.%s" (default $reg.name $reg.host) $ctx.Values.domain }}
{{- end }}

{{/*
Whether basic auth applies to a given registry entry.
Usage: include "docker-proxy.authEnabled" (dict "ctx" $ "reg" .)  -> "true"/""
*/}}
{{- define "docker-proxy.authEnabled" -}}
{{- $ctx := .ctx -}}
{{- $reg := .reg -}}
{{- if $ctx.Values.auth.enabled -}}
{{- if or $ctx.Values.auth.global $reg.auth -}}
true
{{- end -}}
{{- end -}}
{{- end }}

{{/*
htpasswd Secret name for a registry entry (when auth is generated, not existing).
*/}}
{{- define "docker-proxy.authSecretName" -}}
{{- $ctx := .ctx -}}
{{- $reg := .reg -}}
{{- printf "%s-htpasswd" (include "docker-proxy.registryName" (dict "ctx" $ctx "reg" $reg)) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Render the distribution config.yml for a single registry entry. Mirrors the
upstream Docker-Proxy config: shared base + optional proxy / auth blocks.
Usage: include "docker-proxy.config" (dict "ctx" $ "reg" .)
*/}}
{{- define "docker-proxy.config" -}}
{{- $ctx := .ctx -}}
{{- $reg := .reg -}}
version: 0.1
log:
  accesslog:
    disabled: true
  level: info
  formatter: text
  fields:
    service: registry
    environment: staging
storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
  maintenance:
    uploadpurging:
      enabled: false
  tag:
    concurrencylimit: 8
  delete:
    enabled: true
http:
  addr: :{{ $ctx.Values.containerPort }}
  headers:
    X-Content-Type-Options: [nosniff]
    Access-Control-Allow-Origin: ['*']
    Access-Control-Allow-Methods: ['HEAD', 'GET', 'OPTIONS', 'DELETE']
    Access-Control-Allow-Headers: ['Authorization', 'Accept', 'Cache-Control']
    Access-Control-Max-Age: [1728000]
    Access-Control-Allow-Credentials: [true]
    Access-Control-Expose-Headers: ['Docker-Content-Digest']
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
{{- if include "docker-proxy.authEnabled" (dict "ctx" $ctx "reg" $reg) }}
auth:
  htpasswd:
    realm: {{ $ctx.Values.auth.realm | quote }}
    path: /etc/distribution/auth/htpasswd
{{- end }}
{{- if $reg.upstream }}
proxy:
  remoteurl: {{ $reg.upstream }}
  username: {{ $reg.username | default "" | quote }}
  password: {{ $reg.password | default "" | quote }}
  ttl: {{ $reg.ttl | default $ctx.Values.proxyTtl }}
{{- end }}
{{- end }}
