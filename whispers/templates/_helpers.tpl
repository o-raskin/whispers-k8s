{{- define "whispers.name" -}}
{{- .Chart.Name -}}
{{- end -}}

{{- define "whispers.fullname" -}}
{{- .Release.Name -}}
{{- end -}}
