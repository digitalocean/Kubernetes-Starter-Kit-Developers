# How to Perform Backup and Restore Using TrilioVault for Kubernetes

## Introduction

In this tutorial, you will learn how to deploy `TrilioVault for Kubernetes` (or `TVK`) to your `DOKS` cluster, create `backups`, and `recover` from a backup if something goes wrong. You can back up your `entire` cluster, or optionally choose a `namespace` or `label` based backups. `Helm Releases` backup is supported as well, which is a nice addition for the `Starter Kit` where every installation is `Helm` based.

Advantages of using `Trilio`:

- Take `full` (or `incremental`) backups of your cluster and `restore` in case of data loss.
- `Migrate` from one cluster to another.
- `Helm` release backups are supported.
- Run `pre` and `post hooks` for backup and restore operations.
- Web management console, that allows you to inspect your backup/restore operations state in detail (and many other features).
- Define `retention policies` for your backups.
- Application lifecycle (meaning, TVK itself) can be managed via a dedicated `TrilioVault Operator` if desired.
- `Velero` integration (Trilio supports monitoring Velero backups, restores, and backup/snapshot locations via the web management console).
- You can backup and restore `Operator` based applications.

### How TrilioVault for Kubernetes Works

`TVK` follows a `cloud native` architecture, meaning that it has several components that together form the `Control Plane` and `Data Plane` layers. Everything is managed via `CRDs`, thus making it fully `Kubernetes` native. What is nice about `Trilio` is the clear separation of concerns, and how effective it handles backup and restore operations.

Each `TrilioVault` application consists of a bunch of `Controllers` and the associated `CRDs`. Every time a `CRD` is created or updated, the responsible controller is notified and performs cluster reconciliation. Then, the controller in charge spawns `Kubernetes` jobs that perform the real operation (like `backup`, `restore`, etc) in parallel.

`Control Plane` consists of:

- `Target Controller`, defines the `storage` backend (`S3`, `NFS`, etc) via specific CRDs.
- `BackupPlan Controller`, defines the components to backup, automated backups schedule, retention strategy, etc via specific CRDs.
- `Restore Controller`, defines restore operations via specific CRDs.

`Data Plane` consists of:

- `Datamover` Pods, responsible with transferring data between persistent volumes and backup media (or `Target`). `TrilioVault` works with `Persistent Volumes` (PVs) using the `CSI` interface. For each `PV` that needs to be backed up, an ephemeral `Datamover Pod` is created. After each operation finishes, the associated pod is destroyed.
- `Metamover` Pods, responsible with transferring `Kubernetes API` objects data to backup media (or `Target`). `Metamover` pods are `ephemeral`, just like the `Datamover` ones.

### Understanding TrilioVault Application Scope

`TrilioVault` for Kubernetes works based on `application scope`, meaning you can have a `Namespaced` or a `Cluster` type of installation.

A `Namespaced` installation allows you to `backup` and `restore` at the `namespace` level only. In other words, the backup is meant to protect a set of applications that are bound to a namespace that you own. This is how a `BackupPlan` and the corresponding `Backup` CRD works. You cannot mutate those CRDs in other namespaces, they must be created in the same namespace where the application to be backed up is located.

On the other hand, a cluster type of backup is not scoped or bound to any namespace or a set of applications. You define cluster type backups via the `ClusterBackupPlan` and `ClusterBackup` CRDs. Cluster type backups are a little bit more flexible, in the sense that you are not tied to a specific namespace or set of applications to backup and restore. You can have the `ClusterBackupPlan` and `ClusterBackup` created in the same namespace where `TVK` is installed for example, and control backup/restore operations of any Kubernetes resource from there.

In order to make sure that `application scope` and `rules` are followed correctly, `TrilioVault` is using an `Admission Controller`. It `intercepts` and `validates` each `CRD` that you want to push for `TVK`, before it is actually created. In case TVK application scope is not followed, the admission controller will reject CRD creation in the cluster.

Another important thing to consider and remember is that a TVK `License` is application specific. In other words, you need to generate one type of license for either a `Namespaced` or a `Cluster` type installation.

`Namespaced` vs `Cluster` application scope - when to use one or the other? It all depends on the use case. For example, a `Namespaced` application scope is a more appropriate option when you don't have access to the whole Kubernetes cluster, only to specific namespaces. Most of the cases you want to protect only the applications tied to a specific namespace that you own. On the other hand, a cluster scoped application type works at the global level, meaning it can trigger backup/restore operations for any namespace or resource from a Kubernetes cluster.

### Backup and Restore Workflow

Whenever you want to `backup` an application, you start by creating a `BackupPlan` (or `ClusterBackupPlan`) CRD, followed by a `Backup` (or `ClusterBackup`) object. Trilio `Backup Controller` is notified about the change and performs backup object inspection and validation (i.e. whether it is `cluster` backup, `namespace` backup, etc.). Then, it spawns worker pods (`Metamover`, `Datamover`) responsible with moving the actual data (Kubernetes metadata, PVs data) to the backend storage (or `Target`), such as `DigitalOcean Spaces`.

Similarly whenever you create a `Restore` object, the `Restore Controller` is notified to restore from a `Backup` object. Then, Trilio `Restore Controller` spawns worker nodes (`Metamover`, `Datamover`), responsible with moving backup data out of the `DigitalOcean Spaces` storage (Kubernetes metadata, PVs data). Finally, the restore process is initiated from the particular backup object.

Below is a diagram that shows the `Backup/Restore` workflow for `TVK`:

![Trilio Backup/Restore Workflow](assets/images/trilio_bk_res_wf.png)

`Trilio` is ideal for the `disaster` recovery use case, as well as for `snapshotting` your application state, prior to performing `system operations` on your `cluster`, like `upgrades`. For more details on this topic, please visit the [Trilio Features](https://docs.trilio.io/kubernetes/overview/features-and-use-cases) and [Trilio Use Case](https://docs.trilio.io/kubernetes/overview/use-cases) official page.

After finishing this tutorial, you should be able to:

- Configure `DO Spaces` storage backend for `Trilio` to use.
- `Backup` and `restore` your `applications`
- `Backup` and `restore` your entire `DOKS` cluster.
- Create `scheduled` backups for your applications.
- Create `retention policies` for your backups.

## Table of Contents

- [Introduction](#introduction)
  - [How TrilioVault for Kubernetes Works](#how-triliovault-for-kubernetes-works)
  - [Understanding TrilioVault Application Scope](#understanding-triliovault-application-scope)
  - [Backup and Restore Workflow](#backup-and-restore-workflow)
- [Prerequisites](#prerequisites)
- [Step 1 - Installing TrilioVault for Kubernetes](#step-1---installing-triliovault-for-kubernetes)
  - [Installing TrilioVault using Helm](#installing-triliovault-using-helm)
  - [TrilioVault Application Licensing](#triliovault-application-licensing)
- [Step 2 - Creating a TrilioVault Target to Store Backups](#step-2---creating-a-triliovault-target-to-store-backups)
- [Step 3 - Namespace Backup and Restore Example](#step-3---namespace-backup-and-restore-example)
  - [Creating the Ambassador Namespace Backup](#creating-the-ambassador-namespace-backup)
  - [Deleting the Ambassador Namespace and Resources](#deleting-the-ambassador-namespace-and-resources)
  - [Restoring the Ambassador Namespace Backup](#restoring-the-ambassador-namespace-backup)
- [Step 4 - Backup and Restore Whole Cluster Example](#step-4---backup-and-restore-whole-cluster-example)
- [Step 5 - Scheduled Backups](#step-5---scheduled-backups)
- [Step 6 - Backups Retention Policy](#step-6---backups-retention-policy)
- [Conclusion](#conclusion)

## Prerequisites

To complete this tutorial, you need the following:

1. A [DO Spaces Bucket](https://docs.digitalocean.com/products/spaces/how-to/create/) and `access` keys. Save the `access` and `secret` keys in a safe place for later use.
2. A [Git](https://git-scm.com/downloads) client, to clone the `Starter Kit` repository.
3. [Helm](https://www.helms.sh), for managing `TrilioVault Operator` releases and upgrades.
4. [Doctl](https://github.com/digitalocean/doctl/releases), for `DigitalOcean` API interaction.
5. [Kubectl](https://kubernetes.io/docs/tasks/tools), for `Kubernetes` interaction.

**Important note:**

In order for `TrilioVault` to work correctly and to backup your `PVCs`, `DOKS` needs to be configured to support the `Container Storage Interface` (or `CSI`, for short). By default it comes with the driver already installed and configured. You can check using below command:

```shell
kubectl get storageclass
```

The output should look similar to (notice the provisioner is [dobs.csi.digitalocean.com](https://github.com/digitalocean/csi-digitalocean)):

```text
NAME                         PROVISIONER                 RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
do-block-storage (default)   dobs.csi.digitalocean.com   Delete          Immediate           true                   10d
```

## Step 1 - Installing TrilioVault for Kubernetes

In this step, you will learn how to deploy `TrilioVault` for DOKS, and manage `TVK` installations via `Helm`. Backups data will be stored in the `DO Spaces` bucket created earlier in the [Prerequisites](#prerequisites) section.

`TrilioVault` application can be installed many ways:

- Via the [tvk-oneclick](https://github.com/trilioData/tvk-plugins/blob/main/docs/tvk-oneclick/README.md) `krew` plugin. It has some interesting features, like: checking Kubernetes cluster prerequisites, post install validations, automatic licensing of the product (using the free basic license), applicationupgrades management, etc. `Starter Kit` is using `Helm` to manage application releases, so the main focus will be around Helm.
- Via the `TrilioVault Operator` (installable via `Helm`). You define a `TrilioVaultManager` CRD, which tells `TrilioVault` operator how to handle the `installation`, `post-configuration` steps, and future `upgrades` of the `Trilio` application components.
- Fully managed by `Helm`, via the `K8s-TrilioVault` chart (covered in this tutorial).

`TrilioVault` is `free` of charge for `Kubernetes` clusters with up to `10 nodes`. You can use all of its features, no limitations. You can read more about the licensing model on the official [Trilio Licensing](https://docs.trilio.io/kubernetes/overview/licensing) page. The free basic license should suffice for most development needs.

### Installing TrilioVault using Helm

**Important note**:

`Starter Kit` tutorial is using the `Cluster` installation type for the `TVK` application (`applicationScope` Hem value is set to `"Cluster"`). All examples from this tutorial rely on this type of installation to function properly.

Please follow the steps below, to install `TrilioVault` via `Helm`:

1. First, clone the `Starter Kit` Git repository and change directory to your local copy:

    ```shell
    git clone https://github.com/digitalocean/Kubernetes-Starter-Kit-Developers.git

    cd Kubernetes-Starter-Kit-Developers
    ```

2. Next, add the `TrilioVault` Helm repository, and list the available charts:

    ```shell
    helm repo add triliovault http://charts.k8strilio.net/trilio-stable/k8s-triliovault

    helm search repo triliovault
    ```

    The output looks similar to the following:

    ```text
    NAME                                    CHART VERSION   APP VERSION     DESCRIPTION                                       
    triliovault/k8s-triliovault             2.6.2           2.6.2           K8s-TrilioVault provides data protection and re...
    triliovault/k8s-triliovault-operator    0.9.0           0.9.0           K8s-TrilioVault-Operator is an operator designe...
    ```

    **Note:**

    The chart of interest is `triliovault/k8s-triliovault `, which will install `TrilioVault for Kubernetes` on the cluster. You can run `helm show values triliovault/k8s-triliovault --version 2.6.2`, and export to a file to see all the available options.
3. Then, open and inspect the TrilioVault `Helm` values file file provided in the `Starter kit` repository, using an editor of your choice (preferably with `YAML` lint support). You can use [VS Code](https://code.visualstudio.com), for example:

    ```shell
    TRILIOVAULT_CHART_VERSION="2.6.2"

    code 06-setup-backup-restore/assets/manifests/triliovault-values-v${TRILIOVAULT_CHART_VERSION}.yaml
    ```

4. Finally, install `TrilioVault for Kubernetes` using `Helm`:

    ```shell
    TRILIOVAULT_CHART_VERSION="2.6.2"

    helm install triliovault triliovault/k8s-triliovault --version "${TRILIOVAULT_CHART_VERSION}" \
      --namespace tvk \
      --create-namespace \
      -f 06-setup-backup-restore/assets/manifests/triliovault-values-v${TRILIOVAULT_CHART_VERSION}.yaml
    ```

    **Note:**

    A `specific` version for the `TrilioVault` Helm chart is used. In this case `2.6.2` is picked, which maps to the `2.6.2` version of the application (see the output from `Step 2.`). It’s good practice in general, to lock on a specific version. This helps to have predictable results, and allows versioning control via `Git`.

Now, please check your `TVK` deployment:

```shell
helm ls -n tvk
```

The output looks similar to the following (`STATUS` column should display `deployed`):

```text
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
triliovault     tvk             1               2021-11-23 14:13:41.465225 +0200 EET    deployed        k8s-triliovault-2.6.2   2.6.2
```

Next, verify that `TrilioVault` is up and running:

```shell
kubectl get deployments -n tvk
```

The output looks similar to the following (all deployments pods must be in the `Ready` state):

```text
NAME                                READY   UP-TO-DATE   AVAILABLE   AGE
k8s-triliovault-admission-webhook   1/1     1            1           32m
k8s-triliovault-control-plane       1/1     1            1           32m
k8s-triliovault-exporter            1/1     1            1           32m
k8s-triliovault-ingress-gateway     1/1     1            1           32m
k8s-triliovault-web                 1/1     1            1           32m
k8s-triliovault-web-backend         1/1     1            1           32m
```

If the output looks like above, you installed `TVK` successfully. Next, you will learn how to check license type and validity, as well as how to renew.

### TrilioVault Application Licensing

**Important note:**

`Starter Kit` examples rely on a `Cluster` license type to function properly.

By default, when installing `TVK` via `Helm`, a `Free Trial` license is generated and activated automatically. A free trial license lets you run `TVK` for `one month` on `unlimited` cluster nodes. You can always go to the `Trilio` website and generate a new [license](https://www.trilio.io/plans) for your cluster that suits your needs (for example, you can pick the `basic license` type that lets you run `TrilioVault` indefinetly if your `cluster capacity` doesn't exceed `10 nodes`).

Please run below command to see what license is available for your cluster (it is managed via a `License` CRD):

```shell
kubectl get license -n tvk
```

The output looks similar to (notice the `STATUS` which should be `Active`, as well as the license type in the `EDITION` column and `EXPIRATION TIME`):

```text
NAME             STATUS   MESSAGE                                   CURRENT NODE COUNT   EDITION     CAPACITY   EXPIRATION TIME        MAX NODES
test-license-1   Active   Cluster License Activated successfully.   2                    FreeTrial   1000       2021-12-23T00:00:00Z   2
```

The license is managed via a special `CRD`, namely the `License` object. You can inspect it by running below command:

```shell
kubectl describe license test-license-1 -n tvk 
```

The output looks similar to (notice the `Message` and `Capacity` fields, as well as the `Edition`):

```yaml
Name:         test-license-1
Namespace:    tvk
Labels:       <none>
Annotations:  generation: 2
              triliovault.trilio.io/creator: test.cluster@myemail.org
              triliovault.trilio.io/instance-id: d9f7422b-6636-490a-add1-61e9647e2e02
API Version:  triliovault.trilio.io/v1
Kind:         License
Metadata:
  Creation Timestamp:  2021-11-22T08:59:51Z
...
Current Node Count:    2
  Max Nodes:           2
  Message:             Cluster License Activated successfully.
  Properties:
    Active:                        true
    Capacity:                      1000
    Company:                       TRILIO-KUBERNETES-LICENSE-GEN-FREE_TRIAL
    Creation Timestamp:            2021-11-22T00:00:00Z
    Edition:                       FreeTrial
    Expiration Timestamp:          2021-12-23T00:00:00Z
    Maintenance Expiry Timestamp:  2021-12-23T00:00:00Z
    Number Of Users:               -1
    Purchase Timestamp:            2021-11-22T00:00:00Z
    Scope:                         Cluster
...
```

The above output will also tell you when the license is going to expire in the `Expiration Timestamp` field, and the `Scope` (`Cluster` based in this case). You can opt for a `cluster` wide license type, or for a `namespace` based license. More details can be found on the [Trilio Licensing](https://docs.trilio.io/kubernetes/overview/licensing) documentation page.

To renew the license, you will have to request a new one from the `Trilio` website, by navigating to the [licensing](https://www.trilio.io/plans) page. After completing the form, you should receive the `License` YAML manifest, which can be applied to your cluster using `kubectl`. Below commands assume that TVK is installed in the default `tvk` namespace (please replace the `<>` placeholders accordingly, where required):

```shell
kubectl apply -f <YOUR_LICENSE_FILE_NAME>.yaml -n tvk
```

Then, you can check the new license status as you already learned via:

```shell
# List available TVK licenses first from the `tvk` namespace
kubectl get license -n tvk

# Get information about a specific license from the `tvk` namespace
kubectl describe license <YOUR_LICENSE_NAME_HERE> -n tvk 
```

In the next step, you will learn how to define the storage backend for `TrilioVault` to store backups, called a `target`.

## Step 2 - Creating a TrilioVault Target to Store Backups

`TrilioVault` needs to know first where to store your backups. TrilioVault refers to the storage backend by using the `target` term, and it's managed via a special `CRD` named `Target`. The following target types are supported: `S3` and `NFS`. For `DigitalOcean` and the purpose of the `Starter Kit`, it makes sense to rely on the `S3` storage type because it's `cheap` and `scalable`. To benefit from an enhanced level of protection you can create multiple target types (for both `S3` and `NFS`), so that your data is kept safe in multiple places, thus achieving backup redundancy.

Typical `Target` definition looks like below:

```yaml
apiVersion: triliovault.trilio.io/v1
kind: Target
metadata:
  name: trilio-s3-target
  namespace: tvk
spec:
  type: ObjectStore
  vendor: Other
  objectStoreCredentials:
    bucketName: <YOUR_DO_SPACES_BUCKET_NAME_HERE>
    region: <YOUR_DO_SPACES_BUCKET_REGION_HERE>           # e.g.: nyc1
    url: "https://<YOUR_DO_SPACES_BUCKET_ENDPOINT_HERE>"  # e.g.: nyc1.digitaloceanspaces.com
    credentialSecret:
      name: trilio-s3-target
      namespace: tvk
  thresholdCapacity: 10Gi
```

Explanation for the above configuration:

- `spec.type`: Type of target for backup storage (S3 is an object store).
- `spec.vendor`: Third party storage vendor hosting the target (for `DigitalOcean Spaces` you need to use `Other` instead of `AWS`).
- `spec.objectStoreCredentials`: Defines required `credentials` (via `credentialSecret`) to access the `S3` storage, as well as other parameters such as bucket region and name.
- `spec.thresholdCapacity`: Maximum threshold capacity to store backup data.

To access `S3` storage, each target needs to know bucket credentials. A `Kubernetes Secret` must be created as well:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: trilio-s3-target
  namespace: tvk
type: Opaque
stringData:
  accessKey: <YOUR_DO_SPACES_ACCESS_KEY_ID_HERE> # value must be base64 encoded
  secretKey: <YOUR_DO_SPACES_SECRET_KEY_HERE>    # value must be base64 encoded
```

Notice that the secret name is `trilio-s3-target`, and it's referenced by the `spec.objectStoreCredentials.credentialSecret` field of the `Target` CRD explained earlier. The `secret` can be in the same `namespace` where `TrilioVault` was installed (defaults to `tvk`), or in another namespace of your choice. Just make sure that you reference the namespace correctly. On the other hand, please make sure to `protect` the `namespace` where you store `TrilioVault` secrets via `RBAC`, for `security` reasons.

Steps to create a `Target` for `TrilioVault`:

1. First, change directory where the `Starter Kit` Git repository was cloned on your local machine:

    ```shell
    cd Kubernetes-Starter-Kit-Developers
    ```

2. Next, create the Kubernetes secret containing your target S3 bucket credentials (please replace the `<>` placeholders accordingly):

    ```shell
    kubectl create secret generic trilio-s3-target \
      --namespace=tvk \
      --from-literal=accessKey="<YOUR_DO_SPACES_ACCESS_KEY_HERE>" \
      --from-literal=secretKey="<YOUR_DO_SPACES_SECRET_KEY_HERE>"
    ```

3. Then, open and inspect the `Target` manifest file provided in the `Starter Kit` repository, using an editor of your choice (preferably with `YAML` lint support), You can use [VS Code](https://code.visualstudio.com), for example:

    ```shell
    code 06-setup-backup-restore/assets/manifests/triliovault-s3-target.yaml
    ```

4. Now, please replace the `<>` placeholders accordingly for your DO Spaces `Trilio` bucket, like: `bucketName`, `region`,  `url` and `credentialSecret`.
5. Finally, save the manifest file and create the `Target` object using `kubectl`:

    ```shell
    kubectl apply -f 06-setup-backup-restore/assets/manifests/triliovault-s3-target.yaml
    ```

What happens next is, `TrilioVault` will spawn a `worker job` named `trilio-s3-target-validator` responsible with validating your S3 bucket (like availability, permissions, etc.). If the job finishes successfully, the bucket is considered to be healthy or available and the `trilio-s3-target-validator` job resource is deleted afterwards. If something bad happens, the S3 target validator job is left up and running so that you can inspect the logs and find the possible issue.

Now, please go ahead and check if the `Target` resource created earlier is `healthy`:

```shell
kubectl get target trilio-s3-target  -n tvk
```

The output looks similar to (notice the `STATUS` column value - should be `Available`, meaning it's in a `healthy` state):

```text
NAME               TYPE          THRESHOLD CAPACITY   VENDOR   STATUS      BROWSING ENABLED
trilio-s3-target   ObjectStore   10Gi                 Other    Available
```

If the output looks like above, then you configured the S3 target object successfully.

**Hint:**

In case the target object fails to become healthy, you can inspect the logs from the `trilio-s3-target-validator` Pod to find the issue:

```shell
# First, you need to find the target validator
kubectl get pods -n tvk | grep trilio-s3-target-validator

# Output looks similar to:
# trilio-s3-target-validator-tio99a-6lz4q              1/1     Running     0          104s

# Now, fetch logs data
kubectl logs pod/trilio-s3-target-validator-tio99a-6lz4q -n tvk
```

The output looks similar to (notice the exception as an example):

```text
...
INFO:root:2021-11-24 09:06:50.595166: waiting for mount operation to complete.
INFO:root:2021-11-24 09:06:52.595772: waiting for mount operation to complete.
ERROR:root:2021-11-24 09:06:54.598541: timeout exceeded, not able to mount within time.
ERROR:root:/triliodata is not a mountpoint. We can't proceed further.
Traceback (most recent call last):
  File "/opt/tvk/datastore-attacher/mount_utility/mount_by_target_crd/mount_datastores.py", line 56, in main
    utilities.mount_datastore(metadata, datastore.get(constants.DATASTORE_TYPE), base_path)
  File "/opt/tvk/datastore-attacher/mount_utility/utilities.py", line 377, in mount_datastore
    mount_s3_datastore(metadata_list, base_path)
  File "/opt/tvk/datastore-attacher/mount_utility/utilities.py", line 306, in mount_s3_datastore
    wait_until_mount(base_path)
  File "/opt/tvk/datastore-attacher/mount_utility/utilities.py", line 328, in wait_until_mount
    base_path))
Exception: /triliodata is not a mountpoint. We can't proceed further.
...
```

Next, you will learn how to perform backup and restore operations for specific use cases, like:

- Specific `namespace(s)` backup and restore.
- Whole `cluster` backup and restore.

## Step 3 - Namespace Backup and Restore Example

In this step, you will learn how to `backup` an entire `namespace` from your `DOKS` cluster, and `restore` it afterwards making sure that all the resources are re-created. The namespace in question is `ambassador`.

Next, you will perform the following tasks:

- `Create` the `ambassador` namespace `backup`, using a `ClusterBackupPlan` and `ClusterBackup` CRDs.
- `Delete` the `ambassador` namespace.
- `Restore` the `ambassador` namespace, using a `ClusterRestore` CRD.
- `Check` the `ambassador` namespace restoration.

### Creating the Ambassador Namespace Backup

In this step, you will learn how to perform a `one time backup` via dedicated `TVK` CRDs for the `ambassador` ingress namespace. To perform backups, a `ClusterBackupPlan` CRD is required first. A `ClusterBackupPlan` allows you to:

- Specify a `target` where backups should be `stored`.
- Define a set of resources to backup via `Include` or `Exclude` directives (e.g.: `namespace` based backups).
- `Encryption`, if you want to encrypt your backups on the target (this is a very nice feature for securing your backups data).
- Define `schedules` for `full` or `incremental` type backups.
- Define `retention` policies for your backups.

In other words a `ClusterBackupPlan` is a definition of `'what'`, `'where'`, `'to'` and `'how'` of the backup process, but it doesn't perform the actual backup. The `ClusterBackup` CRD is responsible with triggering the actual backup process, as dictated by the `ClusterBackupPlan` spec.

Typical `ClusterBackupPlan` CRD looks like below:

```yaml
apiVersion: triliovault.trilio.io/v1
kind: ClusterBackupPlan
metadata:
  name: ambassador-ns-backup-plan
  namespace: tvk
spec:
  backupConfig:
    target:
      name: trilio-s3-target
      namespace: tvk
  backupComponents:
    - namespace: ambassador
    - namespace: backend
```

Explanation for the above configuration:

- `spec.backupConfig.target.name`: Tells `TVK` what target `name` to use for storing backups.
- `spec.backupConfig.target.namespace`: Tells `TVK` in what namespace the target was created.
- `spec.backupComponents`: Defines a `list` of `namespaces` to back up.

Typical `ClusterBackup` CRD looks like below:

```yaml
apiVersion: triliovault.trilio.io/v1
kind: ClusterBackup
metadata:
  name: ambassador-ns-full-backup
  namespace: tvk
spec:
  type: Full
  clusterBackupPlan:
    name: ambassador-ns-backup-plan
    namespace: tvk
```

Explanation for the above configuration:

- `spec.type`: Specifies backup type (e.g. `Full` or `Incremental`).
- `spec.clusterBackupPlan`: Specifies the `ClusterBackupPlan` which this `ClusterBackup` should use.

Steps to initiate the `Ambassador` namespace backup:

1. First, make sure that the `Ambassador Edge Stack` is deployed in your cluster by following the steps from the [Ambassador Ingress](../03-setup-ingress-controller/ambassador.md#step-1---installing-the-ambassador-edge-stack) tutorial.
2. Next, change directory where the `Starter Kit` Git repository was cloned on your local machine:

    ```shell
    cd Kubernetes-Starter-Kit-Developers
    ```

3. Then, open and inspect the Ambassador `ClusterBackupPlan` and `ClusterBackup` manifest files provided in the `Starter Kit` repository, using an editor of your choice (preferably with `YAML` lint support), You can use [VS Code](https://code.visualstudio.com), for example:

    ```shell
    code 06-setup-backup-restore/assets/manifests/ambassador-ns-backup-plan.yaml

    code 06-setup-backup-restore/assets/manifests/ambassador-ns-backup.yaml
    ```

4. Finally, create the `ClusterBackupPlan` and `ClusterBackup` resources, using the `manifests` provided by the `Starter Kit`:

    ```shell
    kubectl apply -f 06-setup-backup-restore/assets/manifests/ambassador-ns-backup-plan.yaml

    kubectl apply -f 06-setup-backup-restore/assets/manifests/ambassador-ns-backup.yaml
    ```

Now, inspect the `ClusterBackupPlan` status (targeting the `ambassador` namespace), using `kubectl`:

```shell
kubectl get clusterbackupplan ambassador-ns-backup-plan -n tvk
```

The output looks similar to (notice the `STATUS` column value which should be set to `Available`):

```text
NAME                        TARGET             ...   STATUS
ambassador-ns-backup-plan   trilio-s3-target   ...   Available
```

Next, check the `ClusterBackup` status, using `kubectl`:

```shell
kubectl get clusterbackup ambassador-ns-full-backup -n tvk
```

The output looks similar to (notice the `STATUS` column value which should be set to `InProgress`, as well as the `BACKUP TYPE` set to `Full`):

```text
NAME                        BACKUPPLAN                  BACKUP TYPE   STATUS       ...
ambassador-ns-full-backup   ambassador-ns-backup-plan   Full          InProgress   ...                                  
```

After a while, when all the `ambassador` namespace `Kubernetes objects` finish uploading to the `S3` target, you should get below result:

```shell
# Inspect the cluster backup status again for the `ambassador` namespace
kubectl get clusterbackup ambassador-ns-full-backup -n tvk

# The output looks similar to (notice that the `STATUS` changed to `Available`, and `PERCENTAGE` is `100`)
NAME                        BACKUPPLAN                  BACKUP TYPE   STATUS      ...   PERCENTAGE   ...
ambassador-ns-full-backup   ambassador-ns-backup-plan   Full          Available   ...   100          ...
```

If the output looks like above, you successfully backed up the `ambassador` namespace. You can go ahead and see how TrilioVault stores Kubernetes metadata by listing the `TrilioVault S3 Bucket` contents. For example, you can use [s3cmd](https://docs.digitalocean.com/products/spaces/resources/s3cmd):

```shell
s3cmd ls s3://trilio-starter-kit --recursive
```

The output looks similar to (notice that the listing contains the json manifests and UIDs, representing Kubernetes objects):

```text
2021-11-25 07:04           28  s3://trilio-starter-kit/6c68af15-5392-45bb-a70b-b26a93605bd9/
2021-11-25 07:04           28  s3://trilio-starter-kit/6c68af15-5392-45bb-a70b-b26a93605bd9/5ebfffb5-442a-455c-b0de-1db98e18b425/
2021-11-25 07:04          311  s3://trilio-starter-kit/6c68af15-5392-45bb-a70b-b26a93605bd9/5ebfffb5-442a-455c-b0de-1db98e18b425/backup-namespace.json.manifest.00000004
2021-11-25 07:04          302  s3://trilio-starter-kit/6c68af15-5392-45bb-a70b-b26a93605bd9/5ebfffb5-442a-455c-b0de-1db98e18b425/backup.json.manifest.00000004
2021-11-25 07:04          305  s3://trilio-starter-kit/6c68af15-5392-45bb-a70b-b26a93605bd9/5ebfffb5-442a-455c-b0de-1db98e18b425/backupplan.json.manifest.00000004
2021-11-25 07:04           28  s3://trilio-starter-kit/6c68af15-5392-45bb-a70b-b26a93605bd9/5ebfffb5-442a-455c-b0de-1db98e18b425/custom/
2021-11-25 07:04           28  s3://trilio-starter-kit/6c68af15-5392-45bb-a70b-b26a93605bd9/5ebfffb5-442a-455c-b0de-1db98e18b425/custom/metadata-snapshot/
2021-11-25 07:04          330  s3://trilio-starter-kit/6c68af15-5392-45bb-a70b-b26a93605bd9/5ebfffb5-442a-455c-b0de-1db98e18b425/custom/metadata-snapshot/metadata.json.manifest.00000002
...
```

### Deleting the Ambassador Namespace and Resources

Now, go ahead and simulate a disaster, by intentionally deleting the `ambassador` namespace:

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

**Important notes:**

- If restoring into the same namespace, ensure that the original application components have been removed. Especially the PVC of application are deleted.
- If restoring to another cluster (migration scenario), ensure that TrilioVault for Kubernetes is running in the remote namespace/cluster as well. To restore into a new cluster (where the Backup CR does not exist), `source.type` must be set to `location`. Please refer to the [Custom Resource Definition Restore Section](https://docs.trilio.io/kubernetes/architecture/apis-and-command-line-reference/custom-resource-definitions-application-1/triliovault-crds#example-5-restore-from-specific-location-migration-scenario) to view a `restore` by `location` example.
- When you delete the `ambassador` namespace, the load balancer resource associated with the ambassador service will be deleted as well. So, when you restore the `ambassador` service, the `LB` will be recreated by `DigitalOcean`. The issue is that you will get a `NEW IP` address for your `LB`, so you will need to `adjust` the `A records` for getting `traffic` into your domains hosted on the cluster.

To restore a specific `ClusterBackup`, you need to create a `ClusterRestore` CRD. Typical `ClusterRestore` CRD looks like below:

```yaml
apiVersion: triliovault.trilio.io/v1
kind: ClusterRestore
metadata:
  name: ambassador-ns-cluster-restore
  namespace: tvk
spec:
  source:
    type: ClusterBackup
    clusterBackup:
      name: ambassador-ns-full-backup
      namespace: tvk
  components:
    - backupNamespace: ambassador
      restoreNamespace: ambassador
    - backupNamespace: backend
      restoreNamespace: backend
  globalConfig:
    restoreFlags:
      skipIfAlreadyExists: true
```

Explanation for the above configuration:

- `spec.source.type`: Specifies what backup type to restore from.
- `spec.source.clusterBackup`: Contains a reference to the cluster backup object to restore from.
- `spec.source.components`: A list of components (i.e. `namespaces`) to restore.
- `spec.globalConfig.restoreFlags.skipIfAlreadyExists`: Specifies whether to skip restore of a resource if it already exists in the namespace restored.

`ClusterRestore` allows you to restore the last successful `ClusterBackup` based on a `ClusterBackupPlan`. It is used to restore `multiple namespaces` protected by the `ClusterBackup`. The `ClusterBackup` is identified by name `ambassador-ns-full-backup`. It also provides a flag to cleanup in case of a failure.

First, inspect the `ClusterRestore` CRD example from the `Starter Kit` Git repository:

```shell
code 06-setup-backup-restore/assets/manifests/ambassador-ns-restore.yaml
```

Then, create the `ClusterRestore` resource using `kubectl`:

```shell
kubectl apply -f 06-setup-backup-restore/assets/manifests/ambassador-ns-restore.yaml
```

Finally, inspect the `ClusterRestore` status:

```shell
kubectl get clusterrestore ambassador-ns-cluster-restore -n tvk
```

The output looks similar to (notice the STATUS column set to `Completed`, as well as the `PERCENTAGE COMPLETED` set to `100`):

```text
NAME                            STATUS      DATA SIZE   START TIME             END TIME               PERCENTAGE COMPLETED   DURATION
ambassador-ns-cluster-restore   Completed   0           2021-11-25T15:06:52Z   2021-11-25T15:07:35Z   100                    43.524191306s
```

If the output looks like above, then the `ambassador` namespace `restoration` completed successfully.

Check that all the `ambassador` namespace `resources` are in place and running:

```shell
kubectl get all -n ambassador
```

The output looks similar to:

```text
NAME                                    READY   STATUS    RESTARTS   AGE
pod/ambassador-5bdc64f9f6-42wzr         1/1     Running   0          9m58s
pod/ambassador-5bdc64f9f6-nrkzd         1/1     Running   0          9m58s
pod/ambassador-agent-bcdd8ccc8-ktmcv    1/1     Running   0          9m58s
pod/ambassador-redis-64b7c668b9-69drs   1/1     Running   0          9m58s

NAME                       TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)                      AGE
service/ambassador         LoadBalancer   10.245.173.90    157.245.23.93   80:30304/TCP,443:30577/TCP   9m59s
service/ambassador-admin   ClusterIP      10.245.217.211   <none>          8877/TCP,8005/TCP            9m59s
service/ambassador-redis   ClusterIP      10.245.77.142    <none>          6379/TCP                     9m59s

NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/ambassador         2/2     2            2           9m59s
deployment.apps/ambassador-agent   1/1     1            1           9m59s
deployment.apps/ambassador-redis   1/1     1            1           9m59s

NAME                                          DESIRED   CURRENT   READY   AGE
replicaset.apps/ambassador-5bdc64f9f6         2         2         2       9m59s
replicaset.apps/ambassador-agent-bcdd8ccc8    1         1         1       9m59s
replicaset.apps/ambassador-redis-64b7c668b9   1         1         1       9m59s
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

Now, you need to update your DNS `A records`, because the DigitalOcean load balancer resource was recreated, and it has a new external `IP` assigned.

Finally, check if the `backend applications` respond to `HTTP` requests as well (please refer to [Creating the Ambassador Edge Stack Backend Services](../03-setup-ingress-controller/ambassador.md#step-4---creating-the-ambassador-edge-stack-backend-services)), regarding the `backend applications` used in the `Starter Kit` tutorial):

```shell
curl -Li http://quote.starter-kit.online/quote/

curl -Li http://echo.starter-kit.online/echo/
```

Next step deals with whole cluster backup and restore, thus simulating a disaster recovery use case.

## Step 4 - Backup and Restore Whole Cluster Example

## Step 5 - Scheduled Backups

## Step 6 - Backups Retention Policy

## Conclusion
