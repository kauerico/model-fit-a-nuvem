{{/* Rótulos que ligam o Service aos pods do Deployment */}}
{{- define "fake-news.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "fake-news.labels" -}}
{{ include "fake-news.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}
