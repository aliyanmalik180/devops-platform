{{- define "shortener.labels" -}}
app.kubernetes.io/part-of: shortener
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{/* Usage: include "shortener.image" .Values.api.image  -- refuses empty or "latest" tags */}}
{{- define "shortener.image" -}}
{{- $tag := required "image tag is required (use the git SHA)" .tag -}}
{{- if eq $tag "latest" }}{{ fail "image tag 'latest' is not allowed" }}{{ end -}}
{{ .repository }}:{{ $tag }}
{{- end }}

{{/* Usage: include "shortener.podSecurity" (dict "uid" 10001) */}}
{{- define "shortener.podSecurity" -}}
securityContext:
  runAsNonRoot: true
  runAsUser: {{ .uid }}
  runAsGroup: {{ .uid }}
  fsGroup: {{ .uid }}
  seccompProfile:
    type: RuntimeDefault
{{- end }}

{{- define "shortener.containerSecurity" -}}
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: ["ALL"]
{{- end }}
