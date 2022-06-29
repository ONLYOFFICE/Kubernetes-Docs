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

{{/*
Get the configmap name containing the ds upgrade script
*/}}
{{- define "ds.upgrade.configMapName" -}}
{{- if .Values.upgrade.existingConfigmap.dsStop -}}
    {{- printf "%s" (tpl .Values.upgrade.existingConfigmap.dsStop $) -}}
{{- else }}
    {{- printf "stop-ds" -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a configmap object should be created for ds for upgrade
*/}}
{{- define "ds.upgrade.createConfigMap" -}}
{{- if empty .Values.upgrade.existingConfigmap.dsStop }}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Return the configmap name of removing tables for upgrade
*/}}
{{- define "ds.upgrade.configmap.tblRemove.name" -}}
{{- if not (empty .Values.upgrade.existingConfigmap.tblRemove.name) }}
    {{- .Values.upgrade.existingConfigmap.tblRemove.name }}
{{- else if and .Values.privateCluster (not .Values.upgrade.existingConfigmap.dsStop) (not .Values.upgrade.existingConfigmap.tblRemove.name) }}
    {{- required "You set privateCluster=true and did not specify an existing secret containing the ds upgrade script. In this case, you must set upgrade.existingConfigmap.tblRemove.name!" .Values.upgrade.existingConfigmap.tblRemove.name }}
{{- end }}
{{- end -}}

{{/*
Return the configmap name of creating tables for upgrade
*/}}
{{- define "ds.upgrade.configmap.tblCreate.name" -}}
{{- if not (empty .Values.upgrade.existingConfigmap.tblCreate.name) }}
    {{- .Values.upgrade.existingConfigmap.tblCreate.name }}
{{- else if and .Values.privateCluster (not .Values.upgrade.existingConfigmap.dsStop) (not .Values.upgrade.existingConfigmap.tblCreate.name) }}
    {{- required "You set privateCluster=true and did not specify an existing secret containing the ds upgrade script. In this case, you must set upgrade.existingConfigmap.tblCreate.name!" .Values.upgrade.existingConfigmap.tblCreate.name }}
{{- end }}
{{- end -}}

{{/*
Get the configmap name containing the ds rollback script
*/}}
{{- define "ds.rollback.configMapName" -}}
{{- if .Values.rollback.existingConfigmap.dsStop -}}
    {{- printf "%s" (tpl .Values.rollback.existingConfigmap.dsStop $) -}}
{{- else }}
    {{- printf "pre-rollback" -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a configmap object should be created for ds for rollback
*/}}
{{- define "ds.rollback.createConfigMap" -}}
{{- if empty .Values.rollback.existingConfigmap.dsStop }}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Return the configmap name of removing tables for rollback
*/}}
{{- define "ds.rollback.configmap.tblRemove.name" -}}
{{- if not (empty .Values.rollback.existingConfigmap.tblRemove.name) }}
    {{- .Values.rollback.existingConfigmap.tblRemove.name }}
{{- else if and .Values.privateCluster (not .Values.rollback.existingConfigmap.dsStop) (not .Values.rollback.existingConfigmap.tblRemove.name) }}
    {{- required "You set privateCluster=true and did not specify an existing secret containing the ds rollback script. In this case, you must set rollback.existingConfigmap.tblRemove.name!" .Values.rollback.existingConfigmap.tblRemove.name }}
{{- end }}
{{- end -}}

{{/*
Return the configmap name of creating tables for rollback
*/}}
{{- define "ds.rollback.configmap.tblCreate.name" -}}
{{- if not (empty .Values.rollback.existingConfigmap.tblCreate.name) }}
    {{- .Values.rollback.existingConfigmap.tblCreate.name }}
{{- else if and .Values.privateCluster (not .Values.rollback.existingConfigmap.dsStop) (not .Values.rollback.existingConfigmap.tblCreate.name) }}
    {{- required "You set privateCluster=true and did not specify an existing secret containing the ds rollback script. In this case, you must set rollback.existingConfigmap.tblCreate.name!" .Values.rollback.existingConfigmap.tblCreate.name }}
{{- end }}
{{- end -}}
