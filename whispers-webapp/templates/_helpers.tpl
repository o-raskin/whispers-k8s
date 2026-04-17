{{- define "whispers-webapp.name" -}}
{{- .Chart.Name -}}
{{- end -}}

{{- define "whispers-webapp.fullname" -}}
{{- .Release.Name -}}
{{- end -}}