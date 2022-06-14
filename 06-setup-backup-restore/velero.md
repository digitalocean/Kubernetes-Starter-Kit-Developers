# How to Perform Backup and Restore Using Velero

## Introduction

In this tutorial, you will learn how to deploy `Velero` to your `Kubernetes` cluster, create `backups`, and `recover` from a backup if something goes wrong. You can back up your `entire` cluster, or optionally choose a `namespace` or `label` selector to back up.

`Backups` can be run `one off` or `scheduled`. It’s a good idea to have `scheduled` backups so you are certain you have a `recent` backup to easily fall back to. You can also create [backup hooks](https://velero.io/docs/v1.6/backup-hooks/), if you want to execute actions `before` or `after` a backup is made.

Why choose `Velero`?

`Velero` gives you tools to `back up` and `restore` your `Kubernetes cluster resources` and `persistent volumes`. You can run `Velero` with a `cloud provider` or `on-premises`.

Advantages of using `Velero`:

- Take full `backups` of your cluster and `restore` in case of data loss.
- `Migrate` from one cluster to another.
- `Replicate` your `production` cluster to `development` and `testing` clusters.

### How Velero Works

`Velero` consists of two parts:

- A `server` that runs on your cluster.
- A `command-line` client that runs locally.

Each `Velero` operation – `on-demand backup`, `scheduled backup`, `restore` – is a `custom resource`, defined with a `Kubernetes Custom Resource Definition` (CRD) and stored in `etcd`. `Velero` also includes `controllers` that process the custom resources to perform backups, restores, and all related operations.

### Backup and Restore Workflow

Whenever you execute a `backup command`, the `Velero CLI` makes a call to the `Kubernetes API` server to create a `Backup` object. `Backup Controller` is notified about the change, and performs backup object inspection and validation (i.e. whether it is `cluster` backup, `namespace` backup, etc.). Then, it makes a call to the `Kubernetes API` server to query the data to be backed up, and starts the backup process once it collects all the data. Finally, data is backed up to `DigitalOcean Spaces` storage as a `tarball` file (`.tar.gz`).

Similarly whenever you execute a `restore command`, the `Velero CLI` makes a call to `Kubernetes API` server to `restore` from a `backup` object. Based on the restore command executed, Velero `Restore Controller` makes a call to `DigitalOcean Spaces`, and initiates restore from the particular backup object.

Below is a diagram that shows the `Backup/Restore` workflow for `Velero`:

![Velero Backup/Restore Workflow](assets/images/velero_bk_res_wf.png)

`Velero` is ideal for the `disaster` recovery use case, as well as for `snapshotting` your application state, prior to performing `system operations` on your `cluster`, like `upgrades`. For more details on this topic, please visit the [How Velero Works](https://velero.io/docs/v1.6/how-velero-works/) official page.

After finishing this tutorial, you should be able to:

- Configure `DO Spaces` storage backend for `Velero` to use.
- `Backup` and `restore` your `applications`
- `Backup` and `restore` your entire `DOKS` cluster.
- Create `scheduled` backups for your applications.
- Create `retention policies` for your backups.

## Table of Contents

- [Introduction](#introduction)
  - [How Velero Works](#how-velero-works)
  - [Backup and Restore Workflow](#backup-and-restore-workflow)
- [Prerequisites](#prerequisites)
- [Step 1 - Installing Velero using Helm](#step-1---installing-velero-using-helm)
- [Step 2 - Namespace Backup and Restore Example](#step-2---namespace-backup-and-restore-example)
  - [Creating the Ambassador Namespace Backup](#creating-the-ambassador-namespace-backup)
  - [Deleting the Ambassador Namespace and Resources](#deleting-the-ambassador-namespace-and-resources)
  - [Restoring the Ambassador Namespace Backup](#restoring-the-ambassador-namespace-backup)
  - [Checking the Ambassador Namespace Restoration](#checking-the-ambassador-namespace-restoration)
- [Step 3 - Backup and Restore Whole Cluster Example](#step-3---backup-and-restore-whole-cluster-example)
  - [Creating the DOKS Cluster Backup](#creating-the-doks-cluster-backup)
  - [Re-creating the DOKS Cluster and Restoring Applications](#re-creating-the-doks-cluster-and-restoring-applications)
  - [Checking DOKS Cluster Applications State](#checking-doks-cluster-applications-state)
- [Step 4 - Scheduled Backups](#step-4---scheduled-backups)
  - [Verifying the Scheduled Backup state](#verifying-the-scheduled-backup-state)
  - [Restoring the Scheduled Backup](#restoring-the-scheduled-backup)
- [Step 5 - Deleting Backups](#step-5---deleting-backups)
  - [Manually Deleting a Backup](#manually-deleting-a-backup)
  - [Automatic Backup Deletion via TTL](#automatic-backup-deletion-via-ttl)
- [Conclusion](#conclusion)

## Prerequisites

To complete this tutorial, you need the following:

1. A [DO Spaces Bucket](https://docs.digitalocean.com/products/spaces/how-to/create/) and `access` keys. Save the `access` and `secret` keys in a safe place for later use.
2. A DigitalOcean [API token](https://docs.digitalocean.com/reference/api/create-personal-access-token/) for `Velero` to use.
3. A [Git](https://git-scm.com/downloads) client, to clone the `Starter Kit` repository.
4. [Helm](https://www.helms.sh), for managing `Velero` releases and upgrades.
5. [Doctl](https://github.com/digitalocean/doctl/releases), for `DigitalOcean` API interaction.
6. [Kubectl](https://kubernetes.io/docs/tasks/tools), for `Kubernetes` interaction.
7. [Velero](https://velero.io/docs/v1.6/basic-install/#install-the-cli) client, to manage `Velero` backups.

## Step 1 - Installing Velero using Helm

In this step, you will deploy `Velero` and all the required components, so that it will be able to perform backups for your `Kubernetes` cluster resources (`PV's` as well). Backups data will be stored in the `DO Spaces` bucket created earlier in the [Prerequisites](#prerequisites) section.

Steps to follow:

1. First, clone the `Starter Kit` Git repository and change directory to your local copy:

    ```shell
    git clone https://github.com/digitalocean/Kubernetes-Starter-Kit-Developers.git

    cd Kubernetes-Starter-Kit-Developers
    ```

2. Next, add the `Helm` repository and list the available charts:

    ```shell
    helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts

    helm repo update vmware-tanzu

    helm search repo vmware-tanzu
    ```

    The output looks similar to the following:

    ```text
    NAME                    CHART VERSION   APP VERSION     DESCRIPTION
    vmware-tanzu/velero     2.29.7          1.8.1           A Helm chart for velero
    ```

    **Note:**

    The chart of interest is `vmware-tanzu/velero`, which will install `Velero` on the cluster. Please visit the [velero-chart](https://github.com/vmware-tanzu/helm-charts/tree/main/charts/velero) page for more details about this chart.
3. Then, open and inspect the Velero `Helm` values file provided in the `Starter Kit` repository, using an editor of your choice (preferably with `YAML` lint support). You can use [VS Code](https://code.visualstudio.com) for example:

    ```shell
    VELERO_CHART_VERSION="2.29.7"

    code 06-setup-backup-restore/assets/manifests/velero-values-v${VELERO_CHART_VERSION}.yaml
    ```

4. Next, please replace the `<>` placeholders accordingly for your DO Spaces `Velero` bucket (like: name, region and secrets). Make sure that you provide your DigitalOcean `API` token as well (`DIGITALOCEAN_TOKEN` key).
5. Finally, install `Velero` using `Helm`:

    ```shell
    VELERO_CHART_VERSION="2.29.7"

    helm install velero vmware-tanzu/velero --version "${VELERO_CHART_VERSION}" \
      --namespace velero \
      --create-namespace \
      -f 06-setup-backup-restore/assets/manifests/velero-values-v${VELERO_CHART_VERSION}.yaml
    ```

    **Note:**

    A `specific` version for the `Velero` Helm chart is used. In this case `2.29.7` is picked, which maps to the `1.8.1` version of the application (see the output from `Step 2.`). It’s good practice in general, to lock on a specific version. This helps to have predictable results, and allows versioning control via `Git`.

Now, please check your `Velero` deployment:

```shell
helm ls -n velero
```

The output looks similar to the following (`STATUS` column should display `deployed`):

```text
NAME    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART           APP VERSION
velero  velero          1               2022-06-09 08:38:24.868664 +0300 EEST   deployed        velero-2.29.7   1.8.1  
```

Next, verify that `Velero` is up and running:

```shell
kubectl get deployment velero -n velero
```

The output looks similar to the following (deployment pods must be in the `Ready` state):

```text
NAME     READY   UP-TO-DATE   AVAILABLE   AGE
velero   1/1     1            1           67s
```

**Notes:**

- If you’re interested in looking further, you can view Velero’s server-side components:

```shell
kubectl -n velero get all
```

- Explore `Velero` CLI help pages, to see what `comands` and `sub-commands` are available. You can get help for each, by using the `--help` flag:

    List all the available commands for `Velero`:

    ```shell
    velero --help
    ```

    List `backup` command options for `Velero`:

    ```shell
    velero backup --help
    ```

`Velero` uses a number of `CRD`'s (Custom Resource Definitions) to represent its own resources like `backups`, `backup schedules`, etc. You'll discover each in the next steps of the tutorial, along with some basic examples.

## Step 2 - Namespace Backup and Restore Example

In this step, you will learn how to perform a `one time backup` for an entire `namespace` from your `DOKS` cluster, and `restore` it afterwards making sure that all the resources are re-created. The namespace in question is `ambassador`.

Next, you will perform the following tasks:

- `Create` the `ambassador` namespace `backup`, using the `Velero` CLI.
- `Delete` the `ambassador` namespace.
- `Restore` the `ambassador` namespace, using the `Velero` CLI.
- `Check` the `ambassador` namespace restoration.

### Creating the Ambassador Namespace Backup

First, initiate the backup:

```shell
velero backup create ambassador-backup --include-namespaces ambassador
```

Next, check that the backup was created:

```shell
velero backup get
```

The output looks similar to:

```text
NAME                                       STATUS      ERRORS   WARNINGS   CREATED                          EXPIRES   STORAGE LOCATION   SELECTOR
ambassador-backup                          Completed   0        0          2021-08-25 19:33:03 +0300 EEST   29d       default            <none>
```

Then, after a few moments, you can inspect it:

```shell
velero backup describe ambassador-backup --details
```

The output looks similar to:

```text
Name:         ambassador-backup
Namespace:    velero
Labels:       velero.io/storage-location=default
Annotations:  velero.io/source-cluster-k8s-gitversion=v1.21.2
              velero.io/source-cluster-k8s-major-version=1
              velero.io/source-cluster-k8s-minor-version=21

Phase:  Completed

Errors:    0
Warnings:  0

Namespaces:
  Included:  ambassador
  Excluded:  <none>
  ...
```

**Hints:**

- Look for the `Phase` line. It should say `Completed`.
- Check that no `Errors` are reported as well.
- A new Kubernetes `Backup` object is created:

  ```text
  ~ kubectl get backup/ambassador-backup -n velero -o yaml

  apiVersion: velero.io/v1
  kind: Backup
  metadata:
  annotations:
    velero.io/source-cluster-k8s-gitversion: v1.21.2
    velero.io/source-cluster-k8s-major-version: "1"
    velero.io/source-cluster-k8s-minor-version: "21"
  ...
  ```

Finally, take a look at the `DO Spaces` bucket - there's a new folder named `backups`, which contains the assets created for your `ambassador-backup`:

![DO Spaces Velero Backups](assets/images/velero-backup-space-2.png)

### Deleting the Ambassador Namespace and Resources

First, simulate a disaster, by intentionally deleting the `ambassador` namespace:

```shell
kubectl delete namespace ambassador
```

Next, check that the namespace was deleted (namespaces listing should not print `ambassador`):

```shell
kubectl get namespaces
```

Finally, verify that the `echo` and `quote` backend services `endpoint` is `DOWN` (please refer to [Creating the Ambassador Edge Stack Backend Services](../03-setup-ingress-controller/ambassador.md#step-4---creating-the-ambassador-edge-stack-backend-services)), regarding the `backend applications` used in the `Starter Kit` tutorial). You can use `curl` to test (or you can use your web browser):

```shell
curl -Li http://quote.starter-kit.online/quote/

curl -Li http://echo.starter-kit.online/echo/
```

### Restoring the Ambassador Namespace Backup

First, restore the `ambassador-backup`:

```shell
velero restore create --from-backup ambassador-backup
```

**Important note:**

When you delete the `ambassador` namespace, the load balancer resource associated with the ambassador service will be deleted as well. So, when you restore the `ambassador` service, the `LB` will be recreated by `DigitalOcean`. The issue is that you will get a `NEW IP` address for your `LB`, so you will need to `adjust` the `A records` for getting `traffic` into your domains hosted on the cluster.

### Checking the Ambassador Namespace Restoration

First, check the `Phase` line from the `ambassador-backup` restore command output. It should say `Completed` (also, please take a note of the `Warnings` section - it tells if something went bad or not):

```shell
velero restore describe ambassador-backup
```

Next, verify that all the resources were restored for the `ambassador` namespace (look for the `ambassador` pods, `services` and `deployments`):

```shell
kubectl get all --namespace ambassador
```

The output looks similar to:

```text
NAME                                    READY   STATUS    RESTARTS   AGE
pod/ambassador-5bdc64f9f6-9qnz6         1/1     Running   0          18h
pod/ambassador-5bdc64f9f6-twgxb         1/1     Running   0          18h
pod/ambassador-agent-bcdd8ccc8-8pcwg    1/1     Running   0          18h
pod/ambassador-redis-64b7c668b9-jzxb5   1/1     Running   0          18h

NAME                       TYPE           CLUSTER-IP       EXTERNAL-IP      PORT(S)                      AGE
service/ambassador         LoadBalancer   10.245.74.214    159.89.215.200   80:32091/TCP,443:31423/TCP   18h
service/ambassador-admin   ClusterIP      10.245.204.189   <none>           8877/TCP,8005/TCP            18h
service/ambassador-redis   ClusterIP      10.245.180.25    <none>           6379/TCP                     18h

NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/ambassador         2/2     2            2           18h
deployment.apps/ambassador-agent   1/1     1            1           18h
deployment.apps/ambassador-redis   1/1     1            1           18h

NAME                                          DESIRED   CURRENT   READY   AGE
replicaset.apps/ambassador-5bdc64f9f6         2         2         2       18h
replicaset.apps/ambassador-agent-bcdd8ccc8    1         1         1       18h
replicaset.apps/ambassador-redis-64b7c668b9   1         1         1       18h
```

Ambassador `Hosts`:

```shell
kubectl get hosts -n ambassador
```

The output looks similar to (`STATE` should be `Ready`, as well as the `HOSTNAME` column pointing to the fully qualified host name):

```text
NAME         HOSTNAME                   STATE   PHASE COMPLETED   PHASE PENDING   AGE
echo-host    echo.starter-kit.online    Ready                                     11m
quote-host   quote.starter-kit.online   Ready                                     11m
```

Ambassador `Mappings`:

```shell
kubectl get mappings -n ambassador
```

The output looks similar to (notice the `echo-backend` which is mapped to the `echo.starter-kit.online` host and `/echo/` source prefix, same for `quote-backend`):

```text
NAME                          SOURCE HOST                SOURCE PREFIX                               DEST SERVICE     STATE   REASON
ambassador-devportal                                     /documentation/                             127.0.0.1:8500
ambassador-devportal-api                                 /openapi/                                   127.0.0.1:8500
ambassador-devportal-assets                              /documentation/(assets|styles)/(.*)(.css)   127.0.0.1:8500
ambassador-devportal-demo                                /docs/                                      127.0.0.1:8500
echo-backend                  echo.starter-kit.online    /echo/                                      echo.backend
quote-backend                 quote.starter-kit.online   /quote/                                     quote.backend
```

Finally, after reconfiguring your `LoadBalancer` and DigitalOcean `domain` settings, please verify that the `echo` and `quote` backend services `endpoint` is `UP` (please refer to [Creating the Ambassador Edge Stack Backend Services](../03-setup-ingress-controller/ambassador.md#step-4---creating-the-ambassador-edge-stack-backend-services)). For example, you can use `curl` to test each endpoint:

```shell
curl -Li https://quote.starter-kit.online/quote/

curl -Li https://echo.starter-kit.online/echo/
```

In the next step, you will simulate a disaster by intentionally deleting your `DOKS` cluster (the `Starter Kit` DOKS cluster).

## Step 3 - Backup and Restore Whole Cluster Example

In this step, you will simulate a `disaster recovery` scenario. The whole `DOKS` cluster will be deleted, and then restored from a previous backup.

Next, you will perform the following tasks:

- `Create` the `DOKS` cluster `backup`, using `Velero` CLI.
- `Delete` the `DOKS` cluster, using `doctl`.
- `Restore` the `DOKS` cluster important applications, using `Velero` CLI.
- `Check` the `DOKS` cluster applications state.

### Creating the DOKS Cluster Backup

First, create a backup for the whole `DOKS` cluster:

```shell
velero backup create all-cluster-backup
```

Next, check that the backup was created and it's not reporting any errors. The following command lists all the available backups:

```shell
velero backup get
```

The output looks similar to:

```text
NAME                                       STATUS      ERRORS   WARNINGS   CREATED                          EXPIRES   STORAGE LOCATION   SELECTOR
all-cluster-backup                         Completed   0        0          2021-08-25 19:43:03 +0300 EEST   29d       default            <none>
```

Finally, inspect the backup state and logs (check that no errors are reported):

```shell
velero backup describe all-cluster-backup

velero backup logs all-cluster-backup
```

### Re-creating the DOKS Cluster and Restoring Applications

An important aspect to keep in mind is that whenever you destroy a `DOKS` cluster without specifying the `--dangerous` flag to the `doctl` command and then restore it, the same `Load Balancer` with the same `IP` is created. This means that you don't need to update your DigitalOcean DNS `A records`. When the `--dangerous` flag is supplied to the `doctl` command, the existing `Load Balancer` will be destroyed and a new `Load Balancer` with a new external `IP` is created as well when `Velero` restores your `ingress` controller. So, please make sure to update your DigitalOcean DNS `A records` accordingly.

First, delete the whole `DOKS` cluster (make sure to replace the `<>` placeholders accordingly):

```shell
doctl kubernetes cluster delete <DOKS_CLUSTER_NAME>
```

to delete the kubernetes cluster without destroying the associated `Load Balancer` or

```shell
doctl kubernetes cluster delete <DOKS_CLUSTER_NAME> --dangerous
```

to delete the kubernetes cluster and also destroying the associated `Load Balancer`.

Next, re-create the cluster, as described in [Section 1 - Set up DigitalOcean Kubernetes](../01-setup-DOKS/README.md). Please make sure the new `DOKS` cluster node count is `equal or greater` with to the original one - this is important!

Then, install Velero `CLI` and `Server`, as described in the [Prerequisites](#prerequisites) section, and [Step 1 - Installing Velero using Helm](#step-1---installing-velero-using-helm) respectively. Please make sure to use the `same Helm Chart version` - this is important!

Finally, `restore` everything by using  below command:

```shell
velero restore create --from-backup all-cluster-backup
```

### Checking DOKS Cluster Applications State

First, check the `Phase` line from the `all-cluster-backup` restore describe command output (please replace the `<>` placeholders accordingly). It should say `Completed` (also, please take a note of the `Warnings` section - it tells if something went bad or not):

```shell
velero restore describe all-cluster-backup-<timestamp>
```

An important aspect to keep in mind is that whenever you destroy a `DOKS` cluster without specifying the `--dangerous` flag to the `doctl` command and then restore it, the same `Load Balancer` with the same `IP` is created. This means that you don't need to update your DigitalOcean DNS `A records`. When the `--dangerous` flag is supplied to the `doctl` command, the existing `Load Balancer` will be destroyed and a new `Load Balancer` with a new external `IP` is created as well when `Velero` restores your `ingress` controller. So, please make sure to update your DigitalOcean DNS `A records` accordingly.

Next, an important aspect to keep in mind is that whenever you destroy a `DOKS` cluster without specifying the `--dangerous` flag to the `doctl` command and then restore it, the same `Load Balancer` with the same `IP` is created. When the `--dangerous` flag is supplied to the `doctl` command, the existing `Load Balancer` will be destroyed and a new `Load Balancer` with a new external `IP` is created as well when `Velero` restores your `ingress` controller. You have to make sure that `DNS` records will be `updated` as well, to reflect the change.

Now, verify all cluster `Kubernetes` resources (you should have everything in place):

```shell
kubectl get all --all-namespaces
```

Finally, the `backend applications` should respond to `HTTP` requests as well (please refer to [Creating the Ambassador Edge Stack Backend Services](../03-setup-ingress-controller/ambassador.md#step-4---creating-the-ambassador-edge-stack-backend-services)), regarding the `backend applications` used in the `Starter Kit` tutorial):

```shell
curl -Li http://quote.starter-kit.online/quote/

curl -Li http://echo.starter-kit.online/echo/
```

In the next step, you will learn how to perform scheduled (or automatic) backups for your `DOKS` cluster applications.

## Step 4 - Scheduled Backups

Taking backups automatically based on a schedule, is a really useful feature to have. It allows you to `rewind back time`, and restore the system to a previous working state if something goes wrong.

Creating a scheduled backup is a very straightforward process. An example is provided below for a `1 minute` interval (the `kube-system` namespace was picked).

First, create the schedule:

```shell
velero schedule create kube-system-minute-backup --schedule="@every 1m" --include-namespaces kube-system
```

**Hint:**

Linux cronjob format is supported also:

```text
schedule="*/1 * * * *"
```

Next, verify that the schedule was created:

```shell
velero schedule get
```

The output looks similar to:

```text
NAME                        STATUS    CREATED                          SCHEDULE    BACKUP TTL   LAST BACKUP   SELECTOR
kube-system-minute-backup   Enabled   2021-08-26 12:37:44 +0300 EEST   @every 1m   720h0m0s     32s ago       <none>
```

Then, inspect all the backups, after one minute or so:

```shell
velero backup get
```

The output looks similar to:

```text
NAME                                       STATUS      ERRORS   WARNINGS   CREATED                          EXPIRES   STORAGE LOCATION   SELECTOR
kube-system-minute-backup-20210826093916   Completed   0        0          2021-08-26 12:39:20 +0300 EEST   29d       default            <none>
kube-system-minute-backup-20210826093744   Completed   0        0          2021-08-26 12:37:44 +0300 EEST   29d       default            <none>
```

### Verifying the Scheduled Backup state

First, check the `Phase` line from one of the backups (please replace the `<>` placeholders accordingly) - it should say `Completed`:

```shell
velero backup describe kube-system-minute-backup-<timestamp>
```

Finally, take a note of possible `Erros` and `Warnings` from the above command output as well - it tells if something went bad or not.

### Restoring the Scheduled Backup

To restore one of the `minute` backups, please follow the same steps as you learned in the previous steps of this tutorial. This is a good way to exercise and test your experience accumulated so far.

In the next step, you will learn how to manually or automatically delete specific backups you created over time.

## Step 5 - Deleting Backups

When you decide that some older backups are not needed anymore, you can free up some resources both on the `Kubernetes` cluster, as well as on the Velero `DO Spaces` bucket.

In this step, you will learn how to use one of the following methods to delete `Velero` backups:

1. `Manually` (or by hand), using `Velero` CLI.
2. `Automatically`, by setting backups `TTL` (Time To Live), via `Velero` CLI.

### Manually Deleting a Backup

First, pick a one minute backup for example, and issue the following command (please replace the `<>` placeholders accordingly):

```shell
velero backup delete kube-system-minute-backup-<timestamp>
```

Now, check that it's gone from the `velero backup get` command output. It should be deleted from the `DO Spaces` bucket as well.

Next, you will learn how to delete `multiple` backups at once, by using a `selector`. The `velero backup delete` subcommand provides a flag called `--selector`. It allows you to delete `multiple` backups at once based on `Kubernetes Labels`. The same rules apply as for [Kubernetes Label Selectors](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#label-selectors).

First, list the available backups:

```shell
velero backup get
```

The output looks similar to:

```text
NAME                                       STATUS      ERRORS   WARNINGS   CREATED                          EXPIRES   STORAGE LOCATION   SELECTOR
ambassador-backup                          Completed   0        0          2021-08-25 19:33:03 +0300 EEST   23d       default            <none>
backend-minute-backup-20210826094116       Completed   0        0          2021-08-26 12:41:16 +0300 EEST   24d       default            <none>
backend-minute-backup-20210826094016       Completed   0        0          2021-08-26 12:40:16 +0300 EEST   24d       default            <none>
backend-minute-backup-20210826093916       Completed   0        0          2021-08-26 12:39:16 +0300 EEST   24d       default            <none>
backend-minute-backup-20210826093816       Completed   0        0          2021-08-26 12:38:16 +0300 EEST   24d       default            <none>
backend-minute-backup-20210826093716       Completed   0        0          2021-08-26 12:37:16 +0300 EEST   24d       default            <none>
backend-minute-backup-20210826093616       Completed   0        0          2021-08-26 12:36:16 +0300 EEST   24d       default            <none>
backend-minute-backup-20210826093509       Completed   0        0          2021-08-26 12:35:09 +0300 EEST   24d       default            <none>
```

Next, say that you want to delete all the `backend-minute-backup-*` assets. Pick a backup from the list, and inspect the `Labels`:

```shell
velero describe backup backend-minute-backup-20210826094116
```

The output looks similar to (notice the `velero.io/schedule-name` label value):

```text
Name:         backend-minute-backup-20210826094116
Namespace:    velero
Labels:       velero.io/schedule-name=backend-minute-backup
              velero.io/storage-location=default
Annotations:  velero.io/source-cluster-k8s-gitversion=v1.21.2
              velero.io/source-cluster-k8s-major-version=1
              velero.io/source-cluster-k8s-minor-version=21

Phase:  Completed

Errors:    0
Warnings:  0

Namespaces:
Included:  backend
Excluded:  <none>
...
```

Next, you can delete `all` the backups that `match` the `backend-minute-backup` value of the `velero.io/schedule-name` label:

```shell
velero backup delete --selector velero.io/schedule-name=backend-minute-backup
```

Finally, check that all the `backend-minute-backup-*` assets disappeared from the `velero backup get` command output, as well as from the `DO Spaces` bucket.

### Automatic Backup Deletion via TTL

When you create a backup, you can specify a `TTL` (Time To Live), by using the `--ttl` flag. If `Velero` sees that an existing backup resource is expired, it removes:

- The `Backup` resource
- The backup `file` from cloud object `storage`
- All `PersistentVolume` snapshots
- All associated `Restores`

The `TTL` flag allows the user to specify the backup retention period with the value specified in hours, minutes and seconds in the form `--ttl 24h0m0s`. If not specified, a default `TTL` value of `30 days` will be applied.

Next, you will create a short lived backup for the `ambassador` namespace, with a `TTL` value set to `3 minutes`.

First, create the `ambassador` backup, using a `TTL` value of `3 minutes`:

```shell
velero backup create ambassador-backup-3min-ttl --ttl 0h3m0s --include-namespaces ambassador
```

Next, inspect the `ambassador` backup:

```shell
velero backup describe ambassador-backup-3min-ttl
```

The output looks similar to (notice the `Namespaces -> Included` section - it should display `ambassador`, and `TTL` field is set to `3ms0`):

```text
Name:         ambassador-backup-3min-ttl
Namespace:    velero
Labels:       velero.io/storage-location=default
Annotations:  velero.io/source-cluster-k8s-gitversion=v1.21.2
              velero.io/source-cluster-k8s-major-version=1
              velero.io/source-cluster-k8s-minor-version=21

Phase:  Completed

Errors:    0
Warnings:  0

Namespaces:
Included:  ambassador
Excluded:  <none>

Resources:
Included:        *
Excluded:        <none>
Cluster-scoped:  auto

Label selector:  <none>

Storage Location:  default

Velero-Native Snapshot PVs:  auto

TTL:  3m0s
...
```

A new folder should be created in the `DO Spaces` Velero bucket as well, named `ambassador-backup-3min-ttl`.

Finally, after three minutes or so, the backup and associated resources should be automatically deleted. You can verify that the backup object was destroyed, using: `velero backup describe ambassador-backup-3min-ttl`. It should fail with an error, stating that the backup doesn't exist anymore. The corresponding `ambassador-backup-3min-ttl` folder from the `DO Spaces` Velero bucket, should be gone as well.

Going further, you can explore all the available `velero backup delete` options, via:

```shell
velero backup delete --help
```

## Conclusion

In this tutorial, you learned how to perform `one time`, as well as `scheduled` backups, and to restore everything back. Having `scheduled` backups in place, is very important as it allows you to revert to a previous snapshot in time, if something goes wrong along the way. You walked through a disaster recovery scenario, as well.

You can learn more about `Velero`, by following below topics:

- [Backup Command Reference](https://velero.io/docs/v1.6/backup-reference)
- [Restore Command Reference](https://velero.io/docs/v1.6/restore-reference/)
- [Backup Hooks](https://velero.io/docs/v1.6/backup-hooks/)
- [Cluster Migration](https://velero.io/docs/v1.6/migration-case/)
- [Velero Troubleshooting](https://velero.io/docs/v1.6/troubleshooting)

Next, you will learn how to set up `Alerts` and `Notifications` using `AlertManager`, to give you real time notifications (e.g. `Slack`), if something bad happens in your `DOKS` cluster.

Go to [Section 7 - Alerts and Notifications](../07-alerting-and-notification/README.md).
