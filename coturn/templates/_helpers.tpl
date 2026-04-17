{{- define "coturn.name" -}}
{{- .Chart.Name -}}
{{- end -}}

{{- define "coturn.fullname" -}}
{{- .Release.Name -}}
{{- end -}}