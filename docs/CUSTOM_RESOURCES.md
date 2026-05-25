# Adding Custom Resources to ONLYOFFICE Docs

This section describes how to add custom resources to ONLYOFFICE Docs, including:

-   Custom fonts
-   Custom plugins
-   Custom dictionaries

Custom resources must be placed into the `persistence.customResources`
PVC, which is mounted into the `custom-resources` Job.

The `custom-resources` Job runs only if at least one of the following
parameters is set to `true`:

-   `customFonts.build`
-   `customDictionaries.build`
-   `customPlugins.build`

After completing the preparation steps, the processed files are copied
into the `persistence.buffer` PVC.

The `persistence.buffer` PVC is mounted into Docs containers in
**readOnly** mode and is used by entrypoint scripts to perform runtime
initialization.

------------------------------------------------------------------------

# Adding Custom Fonts

## 1. Create PVC and Helper Pod

You can use the option described below to add fonts.

Apply the following manifests to create:

-   A PVC for the custom-resources Job
-   A Pod used to upload fonts into the PVC

``` bash
kubectl apply \
  -f https://raw.githubusercontent.com/ONLYOFFICE/Kubernetes-Docs/master/sources/docs-custom-resources-pvc.yaml \
  -f https://raw.githubusercontent.com/ONLYOFFICE/Kubernetes-Docs/master/sources/docs-custom-resources-pod.yaml \
  -n <NAMESPACE>
```

> **Note:**\
> Specify your Storage Class in `spec.storageClassName` \
> inside `docs-custom-resources-pvc.yaml`. \
> The PersistentVolume type to be used for `docs-buffer` PVC placement must support Access Mode `ReadWriteMany`. \
> \
> If you want to use your own PVC, specify its name in\
> `spec.volumes.persistentVolumeClaim.claimName`\
> inside `docs-custom-resources-pod.yaml`.

## 2. Copy Fonts into the Pod

If the fonts are located on the cluster management host, you can copy them to the Pod using the following command:

Copy a single font:

``` bash
kubectl cp ./font_name.ttf docs-custom-resources:/resources/custom-k8s/ -n <NAMESPACE>
```

Copy a directory:

``` bash
kubectl cp ./font_dir docs-custom-resources:/resources/custom-k8s/ -n <NAMESPACE>
```

> **Important:**\
> Fonts must be located in:
>
> `/resources/custom-k8s`

## 3. Delete the Helper Pod

``` bash
kubectl delete  \
  -f https://raw.githubusercontent.com/ONLYOFFICE/Kubernetes-Docs/master/sources/docs-custom-resources-pod.yaml \
  -n <NAMESPACE>
```

## 4. Install or Upgrade the Chart

``` bash
helm install|upgrade documentserver onlyoffice/docs \
  --set persistence.customResources.existingClaim=docs-custom-resources \
  --set persistence.buffer.existingClaim=docs-buffer \
  --set customFonts.build=true \
  --timeout 25m \
  -n <NAMESPACE>
```

------------------------------------------------------------------------

# Adding or Managing Plugins

## Adding Custom Plugins

### 1. Create PVC and Helper Pod

You can use the option described below to add plugins.

Apply the following manifests to create:

-   A PVC for the custom-resources Job
-   A Pod used to upload plugins into the PVC

``` bash
kubectl apply \
  -f https://raw.githubusercontent.com/ONLYOFFICE/Kubernetes-Docs/master/sources/docs-custom-resources-pvc.yaml \
  -f https://raw.githubusercontent.com/ONLYOFFICE/Kubernetes-Docs/master/sources/docs-custom-resources-pod.yaml \
  -n <NAMESPACE>
```

> **Note:**\
> Specify your Storage Class in `spec.storageClassName` \
> inside `docs-custom-resources-pvc.yaml`. \
> The PersistentVolume type to be used for `docs-buffer` PVC placement must support Access Mode `ReadWriteMany`. \
> \
> If you want to use your own PVC, specify its name in\
> `spec.volumes.persistentVolumeClaim.claimName`\
> inside `docs-custom-resources-pod.yaml`.

### 2. Copy Plugin Directories

If the directories with the plugin are located on the cluster management host, you can copy them to the Pod using the following command:

``` bash
kubectl cp ./plugin_name_dir_1 docs-custom-resources:/resources/ -n <NAMESPACE>
kubectl cp ./plugin_name_dir_2 docs-custom-resources:/resources/ -n <NAMESPACE>
```

> **Important:**\
> Each plugin directory must be located at:
>
> `/resources/plugin_name_dir`

### 3. Delete the Helper Pod

``` bash
kubectl delete \
  -f https://raw.githubusercontent.com/ONLYOFFICE/Kubernetes-Docs/master/sources/docs-custom-resources-pod.yaml \
  -n <NAMESPACE>
```

### 4. Install or Upgrade the Chart

``` bash
helm install|upgrade documentserver onlyoffice/docs \
  --set persistence.customResources.existingClaim=docs-custom-resources \
  --set persistence.buffer.existingClaim=docs-buffer \
  --set customPlugins.build=true \
  --set "customPlugins.pluginNames={plugin_name_dir_1,plugin_name_dir_2}" \
  --timeout 25m \
  -n <NAMESPACE>
```

## Disabling Default Plugins

### Disable Plugin Manager

Apply the `docs-custom-resources-pvc.yaml` manifest if you [haven't already done so](#1-create-pvc-and-helper-pod-1).

``` bash
helm install|upgrade documentserver onlyoffice/docs \
  --set persistence.buffer.existingClaim=docs-buffer \
  --set customPlugins.build=true \
  --set customPlugins.marketplace.enabled=false \
  --timeout 25m \
  -n <NAMESPACE>
```

> **Note:**\
> If you want to disable only the Plugin Manager and PVC `docs-custom-resources` is not applied (or your own for `persistence.customResources.existingClaim`),\
> then add the `persistence.customResources.enabled=false` parameter\
> so that the Job `custom-resources` did not use PVC `persistence.customResources`

This removes the `marketplace` directory and hides the "Plugin Manager" from the Plugins menu.

### Install Selected Default Plugins Only

Apply the `docs-custom-resources-pvc.yaml` manifest if you [haven't already done so](#1-create-pvc-and-helper-pod-1).

You can define a list of desired default plugins that will be installed on the server and displayed in the Plugins menu.

To do this, specify them in the `customPlugins.defaultPlugins.list` parameter and set the `customPlugins.build` parameter to `true`:

``` bash
helm install|upgrade documentserver onlyoffice/docs \
  --set persistence.buffer.existingClaim=docs-buffer \
  --set customPlugins.build=true \
  --set "customPlugins.defaultPlugins.list={ai,photoeditor}" \
  --timeout 25m \
  -n <NAMESPACE>
```

> **Note:**\
> If you want to disable only some plugins and PVC `docs-custom-resources` is not applied (or your own for `persistence.customResources.existingClaim`),\
> then add the `persistence.customResources.enabled=false` parameter\
> so that the Job `custom-resources` did not use PVC `persistence.customResources`

Only the listed plugins will be installed and visible in the Plugins menu.

### Disable All Default Plugins

Apply the `docs-custom-resources-pvc.yaml` manifest if you [haven't already done so](#1-create-pvc-and-helper-pod-1)

You can disable all default plugins on the server and in the Plugins menu.

To do this, set the `customPlugins.defaultPlugins.enabled` parameter to `false` and set the `customPlugins.build` parameter to `true`:

``` bash
helm install|upgrade documentserver onlyoffice/docs \
  --set persistence.buffer.existingClaim=docs-buffer \
  --set customPlugins.build=true \
  --set customPlugins.defaultPlugins.enabled=false \
  --timeout 25m \
  -n <NAMESPACE>
```

> **Note:**\
> If you want to disable only all default plugins and PVC `docs-custom-resources` is not applied (or your own for `persistence.customResources.existingClaim`),\
> then add the `persistence.customResources.enabled=false` parameter\
> so that the Job `custom-resources` did not use PVC `persistence.customResources`

## Completely Disable Plugins Directory

You can completely disable default plugins and the "Plugin Manager".

> **Note:**\
> The Job `custom-resources` is not created in this case.

To do this, set the parameter `customPlugins.emptyPluginsDir` to `true`:

``` bash
helm install|upgrade documentserver onlyoffice/docs \
  --set customPlugins.emptyPluginsDir=true \
  -n <NAMESPACE>
```

This mounts an empty `emptyDir` volume over the plugins directory, removing all plugins and hiding the Plugins menu.

------------------------------------------------------------------------

# Adding Custom Dictionaries

## 1. Create PVC and Helper Pod

You can use the option described below to add dictionaries.

Apply the following manifests to create:

-   A PVC for the custom-resources Job
-   A Pod used to upload dictionaries into the PVC

``` bash
kubectl apply \
  -f https://raw.githubusercontent.com/ONLYOFFICE/Kubernetes-Docs/master/sources/docs-custom-resources-pvc.yaml \
  -f https://raw.githubusercontent.com/ONLYOFFICE/Kubernetes-Docs/master/sources/docs-custom-resources-pod.yaml \
  -n <NAMESPACE>
```

> **Note:**\
> Specify your Storage Class in `spec.storageClassName` \
> inside `docs-custom-resources-pvc.yaml`. \
> The PersistentVolume type to be used for `docs-buffer` PVC placement must support Access Mode `ReadWriteMany`. \
> \
> If you want to use your own PVC, specify its name in\
> `spec.volumes.persistentVolumeClaim.claimName`\
> inside `docs-custom-resources-pod.yaml`.

## 2. Copy Dictionary Directories

If the directories with the dictionaries are located on the cluster management host, you can copy them to the Pod using the following command:

``` bash
kubectl cp ./dict_name_1 docs-custom-resources:/resources/ -n <NAMESPACE>
kubectl cp ./dict_name_2 docs-custom-resources:/resources/ -n <NAMESPACE>
```

> **Important:**\
> Each dictionary directory must be located at:
>
> `/resources/dict_name`

## 3. Delete the Helper Pod

``` bash
kubectl delete \
  -f https://raw.githubusercontent.com/ONLYOFFICE/Kubernetes-Docs/master/sources/docs-custom-resources-pod.yaml \
  -n <NAMESPACE>
```

## 4. Install or Upgrade the Chart

``` bash
helm install|upgrade documentserver onlyoffice/docs \
  --set persistence.customResources.existingClaim=docs-custom-resources \
  --set persistence.buffer.existingClaim=docs-buffer \
  --set customDictionaries.build=true \
  --set "customDictionaries.dictionarieNames={dict_name_1,dict_name_2}" \
  --timeout 25m \
  -n <NAMESPACE>
```
