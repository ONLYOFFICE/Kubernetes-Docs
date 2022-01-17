{{/*
Get the PostgreSQL password secret
*/}}
{{- define "ds.postgresql.secretName" -}}
{{- if .Values.connections.dbPassword -}}
    {{- printf "%s-postgresql" .Release.Name -}}
{{- else if .Values.connections.dbExistingSecret -}}
    {{- printf "%s" (tpl .Values.connections.dbExistingSecret $) -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a secret object should be created for PostgreSQL
*/}}
{{- define "ds.postgresql.createSecret" -}}
{{- if or .Values.connections.dbPassword (not .Values.connections.dbExistingSecret) -}}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Return PostgreSQL password
*/}}
{{- define "ds.postgresql.password" -}}
{{- if not (empty .Values.connections.dbPassword) }}
    {{- .Values.connections.dbPassword }}
{{- else }}
    {{- required "A PostgreSQL Password is required!" .Values.connections.dbPassword }}
{{- end }}
{{- end -}}

{{/*
Get the RabbitMQ password secret
*/}}
{{- define "ds.rabbitmq.secretName" -}}
{{- if .Values.connections.amqpPassword -}}
    {{- printf "%s-rabbitmq" .Release.Name -}}
{{- else if .Values.connections.amqpExistingSecret -}}
    {{- printf "%s" (tpl .Values.connections.amqpExistingSecret $) -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a secret object should be created for RabbitMQ
*/}}
{{- define "ds.rabbitmq.createSecret" -}}
{{- if or .Values.connections.amqpPassword (not .Values.connections.amqpExistingSecret) -}}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Return RabbitMQ password
*/}}
{{- define "ds.rabbitmq.password" -}}
{{- if not (empty .Values.connections.amqpPassword) }}
    {{- .Values.connections.amqpPassword }}
{{- else }}
    {{- required "A RabbitMQ Password is required!" .Values.connections.amqpPassword }}
{{- end }}
{{- end -}}
