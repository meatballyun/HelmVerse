{{- define "my-sample-chart.name" -}}
{{ .Chart.Name }}
{{- end }}

{{- define "my-sample-chart.fullname" -}}
{{ include "my-sample-chart.name" . }}-{{ .Release.Name }}
{{- end }}