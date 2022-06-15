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

{{/*
Get the PVC name
*/}}
{{- define "ds.pvc.name" -}}
{{- if .Values.persistence.existingClaim -}}
    {{- printf "%s" (tpl .Values.persistence.existingClaim $) -}}
{{- else }}
    {{- printf "ds-files" -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a pvc object should be created
*/}}
{{- define "ds.pvc.create" -}}
{{- if empty .Values.persistence.existingClaim }}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Get the license name
*/}}
{{- define "ds.license.secretName" -}}
{{- if .Values.license.existingSecret -}}
    {{- printf "%s" (tpl .Values.license.existingSecret $) -}}
{{- else }}
    {{- printf "license" -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a secret object should be created for license
*/}}
{{- define "ds.license.createSecret" -}}
{{- if and (empty .Values.license.existingSecret) (empty .Values.license.existingClaim) }}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Get the jwt name
*/}}
{{- define "ds.jwt.secretName" -}}
{{- if .Values.jwt.existingSecret -}}
    {{- printf "%s" (tpl .Values.jwt.existingSecret $) -}}
{{- else }}
    {{- printf "jwt" -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a secret object should be created for jwt
*/}}
{{- define "ds.jwt.createSecret" -}}
{{- if empty .Values.jwt.existingSecret }}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Get the service name for ds
*/}}
{{- define "ds.svc.name" -}}
{{- if .Values.service.existing -}}
    {{- printf "%s" (tpl .Values.service.existing $) -}}
{{- else }}
    {{- printf "documentserver" -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a service object should be created for ds
*/}}
{{- define "ds.svc.create" -}}
{{- if empty .Values.service.existing }}
    {{- true -}}
{{- end -}}
{{- end -}}
