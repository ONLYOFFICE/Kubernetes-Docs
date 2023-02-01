{{/*
Check the DB type
*/}}
{{- define "ds.db.type" -}}
{{- $dbType := .Values.connections.dbType -}}
{{- $possibleTypes := list "postgres" "mysql" "mariadb" -}}
{{- if has $dbType $possibleTypes }}
    {{- $dbType -}}
{{- else -}}
    {{- fail "You have specified an unsupported DB type!" -}}
{{- end -}}
{{- end -}}

{{/*
Get the DB password secret
*/}}
{{- define "ds.db.secretName" -}}
{{- if .Values.connections.dbPassword -}}
    {{- printf "%s-db" .Release.Name -}}
{{- else if .Values.connections.dbExistingSecret -}}
    {{- printf "%s" (tpl .Values.connections.dbExistingSecret $) -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a secret object should be created for DB
*/}}
{{- define "ds.db.createSecret" -}}
{{- if or .Values.connections.dbPassword (not .Values.connections.dbExistingSecret) -}}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Return DB password
*/}}
{{- define "ds.db.password" -}}
{{- if not (empty .Values.connections.dbPassword) }}
    {{- .Values.connections.dbPassword }}
{{- else }}
    {{- required "A DB Password is required!" .Values.connections.dbPassword }}
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
Get the Redis password secret
*/}}
{{- define "ds.redis.secretName" -}}
{{- if or .Values.connections.redisPassword .Values.connections.redisNoPass -}}
    {{- printf "%s-redis" .Release.Name -}}
{{- else if .Values.connections.redisExistingSecret -}}
    {{- printf "%s" (tpl .Values.connections.redisExistingSecret $) -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a secret object should be created for Redis
*/}}
{{- define "ds.redis.createSecret" -}}
{{- if or .Values.connections.redisPassword .Values.connections.redisNoPass (not .Values.connections.redisExistingSecret) -}}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Return Redis password
*/}}
{{- define "ds.redis.password" -}}
{{- if not (empty .Values.connections.redisPassword) }}
    {{- .Values.connections.redisPassword }}
{{- else if .Values.connections.redisNoPass }}
    {{- printf "" }}
{{- else }}
    {{- required "A Redis Password is required!" .Values.connections.redisPassword }}
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
Define a branch with sql scripts for ds
*/}}
{{- define "ds.sqlScripts.branchName" -}}
{{- $appVersion := .Chart.AppVersion -}}
{{- if semverCompare ">=7.2.0" $appVersion -}}
    {{- printf "master" -}}
{{- else if semverCompare ">=7.1.0 <7.2.0" $appVersion -}}
    {{- printf "v7.1.1.23" -}}
{{- else -}}
    {{- printf "%s" .Values.sqlScripts.branchName -}}
{{- end -}}
{{- end -}}

{{/*
Get the configmap name containing the ds upgrade script
*/}}
{{- define "ds.upgrade.configMapName" -}}
{{- if .Values.upgrade.existingConfigmap.dsStop -}}
    {{- printf "%s" (tpl .Values.upgrade.existingConfigmap.dsStop $) -}}
{{- else }}
    {{- printf "pre-upgrade" -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a configmap object containing the ds upgrade script should be created
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
Return true if a configmap object containing the ds rollback script should be created
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

{{/*
Get the configmap name containing the ds delete script
*/}}
{{- define "ds.delete.configMapName" -}}
{{- if .Values.delete.existingConfigmap.dsStop -}}
    {{- printf "%s" (tpl .Values.delete.existingConfigmap.dsStop $) -}}
{{- else }}
    {{- printf "pre-delete" -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a configmap object containing the ds delete script should be created
*/}}
{{- define "ds.delete.createConfigMap" -}}
{{- if empty .Values.delete.existingConfigmap.dsStop }}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Return the configmap name of deleting tables for rollback
*/}}
{{- define "ds.delete.configmap.tblRemove.name" -}}
{{- if not (empty .Values.delete.existingConfigmap.tblRemove.name) }}
    {{- .Values.delete.existingConfigmap.tblRemove.name }}
{{- else if and .Values.privateCluster (not .Values.delete.existingConfigmap.dsStop) (not .Values.delete.existingConfigmap.tblRemove.name) }}
    {{- required "You set privateCluster=true and did not specify an existing secret containing the ds delete script. In this case, you must set delete.existingConfigmap.tblRemove.name!" .Values.delete.existingConfigmap.tblRemove.name }}
{{- end }}
{{- end -}}

{{/*
Get the configmap name containing the initdb script
*/}}
{{- define "ds.install.configMapName" -}}
{{- if .Values.install.existingConfigmap.initdb -}}
    {{- printf "%s" (tpl .Values.install.existingConfigmap.initdb $) -}}
{{- else }}
    {{- printf "pre-install" -}}
{{- end -}}
{{- end -}}

{{/*
Return true if a configmap object containing the initdb script should be created
*/}}
{{- define "ds.install.createConfigMap" -}}
{{- if empty .Values.install.existingConfigmap.initdb }}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Return the configmap name of creating tables for install ds
*/}}
{{- define "ds.install.configmap.tblCreate.name" -}}
{{- if not (empty .Values.install.existingConfigmap.tblCreate.name) }}
    {{- .Values.install.existingConfigmap.tblCreate.name }}
{{- else if and .Values.privateCluster (not .Values.install.existingConfigmap.initdb) (not .Values.install.existingConfigmap.tblCreate.name) }}
    {{- required "You set privateCluster=true and did not specify an existing secret containing the initdb script. In this case, you must set install.existingConfigmap.tblCreate.name!" .Values.install.existingConfigmap.tblCreate.name }}
{{- end }}
{{- end -}}

{{/*
Get the ds labels
*/}}
{{- define "ds.labels.commonLabels" -}}
{{- range $key, $value := .Values.commonLabels }}
{{ $key }}: {{ tpl $value $ }}
{{- end }}
{{- end -}}

{{/*
Get the ds Service Account name
*/}}
{{- define "ds.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default .Release.Name .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Get the ds Namespace
*/}}
{{- define "ds.namespace" -}}
{{- if .Values.namespaceOverride -}}
    {{- .Values.namespaceOverride -}}
{{- else -}}
    {{- .Release.Namespace -}}
{{- end -}}
{{- end -}}

{{/*
Get the ds Grafana Namespace
*/}}
{{- define "ds.grafana.namespace" -}}
{{- if .Values.grafana.namespace -}}
    {{- .Values.grafana.namespace -}}
{{- else if .Values.namespaceOverride -}}
    {{- .Values.namespaceOverride -}}
{{- else -}}
    {{- .Release.Namespace -}}
{{- end -}}
{{- end -}}
