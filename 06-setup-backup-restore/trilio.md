# How to Perform Backup and Restore Using TrilioVault for Kubernetes

## Introduction

In this tutorial, you will learn how to deploy `TrilioVault for Kubernetes` (or `TVK`) to your `DOKS` cluster, create `backups`, and `recover` from a backup if something goes wrong. You can back up your `entire` cluster, or optionally choose a `namespace` or `label` based backups. `Helm Releases` backups is supported as well, which is a nice addition for the `Starter Kit` where every installation is `Helm` based.

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

`TrilioVault` for Kubernetes works based on `scope`, meaning you can have a `Namespaced` or a `Cluster` type of installation.

A `Namespaced` installation allows you to `backup` and `restore` at the `namespace` level only. In other words, the backup is meant to protect a set of applications that are bound to a namespace that you own. This is how a `BackupPlan` and the corresponding `Backup` CRD works. You cannot mutate those CRDs in other namespaces, they must be created in the same namespace where the application to be backed up is located.

On the other hand, a `Cluster` type installation is not scoped or bound to any namespace or a set of applications. You define cluster type backups via the `Cluster` prefixed `CRDs`, like: `ClusterBackupPlan`, `ClusterBackup`, etc. Cluster type backups are a little bit more flexible, in the sense that you are not tied to a specific namespace or set of applications to backup and restore. You can perform backup/restore operations for multiple namespaces and applications at once, including `PVs` as well (you can also backup `etcd` databased content).

In order to make sure that TVK application `scope` and `rules` are followed correctly, `TrilioVault` is using an `Admission Controller`. It `intercepts` and `validates` each `CRD` that you want to push for `TVK`, before it is actually created. In case TVK application scope is not followed, the admission controller will reject CRD creation in the cluster.

Another important thing to consider and remember is that a TVK `License` is application scope specific. In other words, you need to generate one type of license for either a `Namespaced` or a `Cluster` type installation.

`Namespaced` vs `Cluster` TVK application scope - when to use one or the other? It all depends on the use case. For example, a `Namespaced` scope is a more appropriate option when you don't have access to the whole Kubernetes cluster, only to specific namespaces and applications. Most of the cases you want to protect only the applications tied to a specific namespace that you own. On the other hand, a cluster scoped installation type works at the global level, meaning it can trigger backup/restore operations for any namespace or resource from a Kubernetes cluster (including `PVs` and the `etcd` database).

To summarize:

- If you are a cluster administrator, then you will most probably want to perform `cluster` level `operations` via corresponding CRDs, like: `ClusterBackupPlan`, `ClusterBackup`, `ClusterRestore`, etc.
- If you are a regular user, then you will usually perform `namespaced` only operations (application centric) via corresponding CRDs, like: `BackupPlan`, `Backup`, `Restore`, etc.

The application interface is very similar or uniform when comparing the two types: `Cluster` vs `non-Cluster` prefixed `CRDs`. So, if you're familiar with one type, it's pretty straightforward to use the counterpart.

For more information, please refer to the [TVK CRDs](https://docs.trilio.io/kubernetes/architecture/apis-and-command-line-reference/custom-resource-definitions-application-1) official documentation.

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
  - [Checking TVK Application Licensing](#checking-tvk-application-licensing)
  - [Creating/Renewing TVK Application License](#creatingrenewing-tvk-application-license)
- [Step 2 - Creating a TrilioVault Target to Store Backups](#step-2---creating-a-triliovault-target-to-store-backups)
- [Step 3 - Getting to Know the TVK Web Management Console](#step-3---getting-to-know-the-tvk-web-management-console)
  - [Getting Access to the TVK Web Management Console](#getting-access-to-the-tvk-web-management-console)
  - [Exploring the TVK Web Console User Interface](#exploring-the-tvk-web-console-user-interface)
- [Step 4 - Namespaced Backup and Restore Example](#step-4---namespaced-backup-and-restore-example)
  - [Creating the Ambassador Helm Release Backup](#creating-the-ambassador-helm-release-backup)
  - [Deleting the Ambassador Helm Release and Resources](#deleting-the-ambassador-helm-release-and-resources)
  - [Restoring the Ambassador Helm Release Backup](#restoring-the-ambassador-helm-release-backup)
  - [Verifying Applications Integrity after Restoration](#verifying-applications-integrity-after-restoration)
- [Step 5 - Backup and Restore Whole Cluster Example](#step-5---backup-and-restore-whole-cluster-example)
  - [Creating the DOKS Cluster Backup](#creating-the-doks-cluster-backup)
  - [Re-creating the DOKS Cluster and Restoring Applications](#re-creating-the-doks-cluster-and-restoring-applications)
  - [Checking DOKS Cluster Applications State](#checking-doks-cluster-applications-state)
- [Step 6 - Scheduled Backups](#step-6---scheduled-backups)
- [Step 7 - Backups Retention Policy](#step-7---backups-retention-policy)
  - [Using Retention Policies](#using-retention-policies)
  - [Using Cleanup Policies](#using-cleanup-policies)
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

In this step, you will learn how to deploy `TrilioVault` for `DOKS`, and manage `TVK` installations via `Helm`. Backups data will be stored in the `DO Spaces` bucket created earlier in the [Prerequisites](#prerequisites) section.

`TrilioVault` application can be installed many ways:

- Via the [tvk-oneclick](https://github.com/trilioData/tvk-plugins/blob/main/docs/tvk-oneclick/README.md) `krew` plugin. It has some interesting features, like: checking Kubernetes cluster prerequisites, post install validations, automatic licensing of the product (using the free basic license), application upgrades management, etc.
- Via the `TrilioVault Operator` (installable via `Helm`). You define a `TrilioVaultManager` CRD, which tells `TrilioVault` operator how to handle the `installation`, `post-configuration` steps, and future `upgrades` of the `Trilio` application components.
- Fully managed by `Helm`, via the [k8s-triliovault](http://charts.k8strilio.net/trilio-stable/k8s-triliovault) chart (covered in this tutorial).

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
    triliovault/k8s-triliovault             2.6.3           2.6.3           K8s-TrilioVault provides data protection and re...
    triliovault/k8s-triliovault-operator    0.9.0           0.9.0           K8s-TrilioVault-Operator is an operator designe...
    ```

    **Note:**

    The chart of interest is `triliovault/k8s-triliovault`, which will install `TrilioVault for Kubernetes` on the cluster. You can run `helm show values triliovault/k8s-triliovault --version 2.6.3`, and export to a file to see all the available options.
3. Then, open and inspect the TrilioVault `Helm` values file file provided in the `Starter kit` repository, using an editor of your choice (preferably with `YAML` lint support). You can use [VS Code](https://code.visualstudio.com) for example:

    ```shell
    TRILIOVAULT_CHART_VERSION="2.6.3"

    code 06-setup-backup-restore/assets/manifests/triliovault-values-v${TRILIOVAULT_CHART_VERSION}.yaml
    ```

4. Finally, install `TrilioVault for Kubernetes` using `Helm`:

    ```shell
    TRILIOVAULT_CHART_VERSION="2.6.3"

    helm install triliovault triliovault/k8s-triliovault --version "${TRILIOVAULT_CHART_VERSION}" \
      --namespace tvk \
      --create-namespace \
      -f 06-setup-backup-restore/assets/manifests/triliovault-values-v${TRILIOVAULT_CHART_VERSION}.yaml
    ```

    **Note:**

    A `specific` version for the `TrilioVault` Helm chart is used. In this case `2.6.3` is picked, which maps to the `2.6.3` version of the application (see the output from `Step 2.`). It’s good practice in general, to lock on a specific version. This helps to have predictable results, and allows versioning control via `Git`.

Now, please check your `TVK` deployment:

```shell
helm ls -n tvk
```

The output looks similar to the following (`STATUS` column should display `deployed`):

```text
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
triliovault     tvk             1               2021-11-23 14:13:41.465225 +0200 EET    deployed        k8s-triliovault-2.6.3   2.6.3
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

By default, when installing `TVK` via `Helm`, a `Free Trial` license is generated and activated automatically. A free trial license lets you run `TVK` for `one month` on `unlimited` cluster nodes. You can always go to the `Trilio` website and generate a new [license](https://www.trilio.io/plans) for your cluster that suits your needs (for example, you can pick the `basic license` type that lets you run `TrilioVault` indefinetly if your `cluster capacity` doesn't exceed `10 nodes`).

**Notes:**

- **TrilioVault is free of charge for Kubernetes clusters with up to 10000 nodes for DigitalOcean users.**
- `Starter Kit` examples rely on a `Cluster` license type to function properly.

### Checking TVK Application Licensing

Please run below command to see what license is available for your cluster (it is managed via the `License` CRD):

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

### Creating/Renewing TVK Application License

To create or renew the license, you will have to request a new one from the `Trilio` website, by navigating to the [licensing](https://www.trilio.io/plans) page. After completing the form, you should receive the `License` YAML manifest, which can be applied to your cluster using `kubectl`. Below commands assume that TVK is installed in the default `tvk` namespace (please replace the `<>` placeholders accordingly, where required):

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
  enableBrowsing: true
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
- `spec.enableBrowsing`: Enable browsing for the target.
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

3. Then, open and inspect the `Target` manifest file provided in the `Starter Kit` repository, using an editor of your choice (preferably with `YAML` lint support). You can use [VS Code](https://code.visualstudio.com) for example:

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

Next, you will discover the TVK web console which is a really nice and useful addition to help you manage backup and restore operations very easy, among many others.

## Step 3 - Getting to Know the TVK Web Management Console

While you can manage backup and restore operations from the `CLI` entirely via `kubectl` and `CRDs`, `TVK` provides a [Web Management Console](https://docs.trilio.io/kubernetes/management-console/user-interface) to accomplish the same operations via the GUI. The management console simplifies common tasks via point and click operations, provides better visualization and inspection of TVK cluster objects, as well as to create disaster recovery plans (or `DRPs`).

The Helm based installation covered in [Step 1 - Installing TrilioVault for Kubernetes](#step-1---installing-triliovault-for-kubernetes) already took care of installing the required components for the web management console.

### Getting Access to the TVK Web Management Console

To be able to access the console and explore the features it offers, you need to port forward the ingress gateway service for TVK.

First, you need to identify the `ingress-gateway` service from the `tvk` namespace:

```shell
kubectl get svc -n tvk
```

The output looks similar to (search for the `k8s-triliovault-ingress-gateway` line, and notice that it listens on port `80` in the `PORT(S)` column):

```text
NAME                                TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
k8s-triliovault-admission-webhook   ClusterIP   10.245.121.127   <none>        443/TCP                      22m
k8s-triliovault-ingress-gateway     NodePort    10.245.186.164   <none>        80:31872/TCP,443:30421/TCP   22m
k8s-triliovault-web                 ClusterIP   10.245.62.14     <none>        80/TCP                       22m
k8s-triliovault-web-backend         ClusterIP   10.245.69.118    <none>        80/TCP                       22m
trilio-s3-target-browser-u8wf5f     ClusterIP   10.245.7.116     <none>        80/TCP                       38s
```

`TVK` is using an `Nginx Ingress Controller` to route traffic to the management web console services. Routing is host based, and the host name is `tvk-doks.com` as defined in the `Helm` values file from the `Starter Kit`:

```yaml
# The host name to use when accessing the web console via the TVK ingress gateway
ingressConfig:
  host: "tvk-doks.com"
```

Having the above information at hand, please go ahead and edit the `/etc/hosts` file, and add this entry:

```text
127.0.0.1 tvk-doks.com
```

Next, create the port forward for the TVK ingress gateway service:

```shell
kubectl port-forward svc/k8s-triliovault-ingress-gateway 8080:80 -n tvk
```

Finally export the `kubeconfig` file for your DOKS cluster. This step is required so that the web console can authenticate you:

```shell
# List the available clusters
doctl k8s cluster list

# Save cluster configuration to YAML
doctl kubernetes cluster kubeconfig show <YOUR_CLUSTER_NAME_HERE> > config_<YOUR_CLUSTER_NAME_HERE>.yaml
```

**Hint:**

If you have only one cluster, the below command can be used:

```shell
DOKS_CLUSTER_NAME="$(doctl k8s cluster list --no-header --format Name)"

doctl kubernetes cluster kubeconfig show $DOKS_CLUSTER_NAME > config_${DOKS_CLUSTER_NAME}.yaml
```

After following the above presented steps, you can access the console in your web browser by navigating to: http://tvk-doks.com:8080. When asked for the `kubeconfig` file, please select the one that you created in the last command from above.

**Note:**

Please keep the generated `kubeconfig` file safe because it contains sensitive data.

### Exploring the TVK Web Console User Interface

The home page looks similar to:

![TVK Console Home Dashboard](assets/images/tvk_console_home.png)

Go ahead and explore each section from the left, like:

- `Home`: This is the main dashboard which gives you a general overview for whole cluster, like: Kubernetes clusters, discovered namespaces, Backup/Restore operations summary, etc.
- `Resource Management`: Lists all the available resources from your cluster (e.g. application namespaces), as well as settings for each, like: backup plans, retention policies, etc.
- `Disaster Recovery`: Allows you to manage and perform disaster recovery operations.

You can also see the S3 Target created earlier, by navigating to `Resource Management -> TVK Namespace -> Targets` (in case of `Starter Kit` the TVK Namespace is `tvk`):

![TVK Targets List](assets/images/tvk_target_list.png)

Going further, you can browse the target and list the available backups by clicking on the `Actions` button from the right, and then select `Launch Browser` option from the pop-up menu (for this to work the target must have the `enableBrowsing` flag set to `true`):

![TVK Target Browser](assets/images/tvk_target_browser.png)

For more information and available features, please consult the [TVK Web Management Console User Interface](https://docs.trilio.io/kubernetes/management-console/user-interface/overview) official documentation.

Next, you will learn how to perform backup and restore operations for specific use cases, like:

- Specific `namespace(s)` backup and restore.
- Whole `cluster` backup and restore.

## Step 4 - Namespaced Backup and Restore Example

In this step, you will learn how to create a `one-time backup` for an entire `namespace` from your `DOKS` cluster and `restore` it afterwards, making sure that all the resources are re-created. The namespace in question is `ambassador`. TVK has a neat feature that allows you to perform backups at a higher level than just namespaces, meaning: `Helm Releases`. You will learn how to accomplish such a task, in the steps to follow.

Next, you will perform the following tasks:

- `Create` the `ambassador` Helm release `backup`, via `BackupPlan` and `Backup` CRDs.
- `Delete` the `ambassador` Helm release.
- `Restore` the `ambassador` Helm release, via `Restore` CRD.
- `Check` the `ambassador` Helm release resources restoration.

### Creating the Ambassador Helm Release Backup

To perform backups for a single application at the namespace level (or Helm release), a `BackupPlan` followed by a `Backup` CRD is required. A `BackupPlan` allows you to:

- Specify a `target` where backups should be `stored`.
- Define a set of resources to backup (e.g.: `namespace` or `Helm releases`).
- `Encryption`, if you want to encrypt your backups on the target (this is a very nice feature for securing your backups data).
- Define `schedules` for `full` or `incremental` type backups.
- Define `retention` policies for your backups.

In other words a `BackupPlan` is a definition of `'what'`, `'where'`, `'to'` and `'how'` of the backup process, but it doesn't perform the actual backup. The `Backup` CRD is responsible with triggering the actual backup process, as dictated by the `BackupPlan` spec.

Typical `BackupPlan` CRD looks like below:

```yaml
apiVersion: triliovault.trilio.io/v1
kind: BackupPlan
metadata:
  name: ambassador-helm-release-backup-plan
  namespace: ambassador
spec:
  backupConfig:
    target:
      name: trilio-s3-target
      namespace: tvk
  backupPlanComponents:
    helmReleases:
      - ambassador
```

Explanation for the above configuration:

- `spec.backupConfig.target.name`: Tells `TVK` what target `name` to use for storing backups.
- `spec.backupConfig.target.namespace`: Tells `TVK` in what namespace the target was created.
- `spec.backupComponents`: Defines a `list` of `resources` to back up (can be `namespaces` or `Helm releases`).

Typical `Backup` CRD looks like below:

```yaml
apiVersion: triliovault.trilio.io/v1
kind: Backup
metadata:
  name: ambassador-helm-release-full-backup
  namespace: ambassador
spec:
  type: Full
  backupPlan:
    name: ambassador-helm-release-backup-plan
    namespace: ambassador
```

Explanation for the above configuration:

- `spec.type`: Specifies backup type (e.g. `Full` or `Incremental`).
- `spec.backupPlan`: Specifies the `BackupPlan` which this `Backup` should use.

Steps to initiate the `Ambassador` Helm release one time backup:

1. First, make sure that the `Ambassador Edge Stack` is deployed in your cluster by following the steps from the [Ambassador Ingress](../03-setup-ingress-controller/ambassador.md#step-1---installing-the-ambassador-edge-stack) tutorial.
2. Next, change directory where the `Starter Kit` Git repository was cloned on your local machine:

    ```shell
    cd Kubernetes-Starter-Kit-Developers
    ```

3. Then, open and inspect the Ambassador `BackupPlan` and `Backup` manifest files provided in the `Starter Kit` repository, using an editor of your choice (preferably with `YAML` lint support). You can use [VS Code](https://code.visualstudio.com) for example:

    ```shell
    code 06-setup-backup-restore/assets/manifests/ambassador-helm-release-backup-plan.yaml

    code 06-setup-backup-restore/assets/manifests/ambassador-helm-release-backup.yaml
    ```

4. Finally, create the `BackupPlan` and `Backup` resources, using `kubectl`:

    ```shell
    kubectl apply -f 06-setup-backup-restore/assets/manifests/ambassador-helm-release-backup-plan.yaml

    kubectl apply -f 06-setup-backup-restore/assets/manifests/ambassador-helm-release-backup.yaml
    ```

Now, inspect the `BackupPlan` status (targeting the `ambassador` Helm release), using `kubectl`:

```shell
kubectl get backupplan ambassador-helm-release-backup-plan -n ambassador
```

The output looks similar to (notice the `STATUS` column value which should be set to `Available`):

```text
NAME                                  TARGET             ...   STATUS
ambassador-helm-release-backup-plan   trilio-s3-target   ...   Available
```

Next, check the `Backup` object status, using `kubectl`:

```shell
kubectl get backup ambassador-helm-release-full-backup -n ambassador
```

The output looks similar to (notice the `STATUS` column value which should be set to `InProgress`, as well as the `BACKUP TYPE` set to `Full`):

```text
NAME                                  BACKUPPLAN                            BACKUP TYPE   STATUS       ...
ambassador-helm-release-full-backup   ambassador-helm-release-backup-plan   Full          InProgress   ...                                  
```

After all the `ambassador` Helm release components finish uploading to the `S3` target, you should get below results:

```shell
# Inspect the cluster backup status again for the `ambassador` namespace
kubectl get backup ambassador-helm-release-full-backup -n ambassador

# The output looks similar to (notice that the `STATUS` changed to `Available`, and `PERCENTAGE` is `100`)
NAME                                  BACKUPPLAN                            BACKUP TYPE   STATUS      ...   PERCENTAGE
ambassador-helm-release-full-backup   ambassador-helm-release-backup-plan   Full          Available   ...   100
```

If the output looks like above, you successfully backed up the `ambassador` Helm release. You can go ahead and see how `TrilioVault` stores `Kubernetes` metadata by listing the `TrilioVault S3 Bucket` contents. For example, you can use [s3cmd](https://docs.digitalocean.com/products/spaces/resources/s3cmd):

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

Finally, you can check that the backup is available in the web console as well, by navigating to `Resource Management -> ambassador -> Backup Plans` (notice that it's in the `Available` state, and that the `ambassador` Helm release was backed up in the `Component Details` sub-view):

![Ambassador Helm Release Backup](assets/images/ambassador_tvk_backup.png)

### Deleting the Ambassador Helm Release and Resources

Now, go ahead and simulate a disaster, by intentionally deleting the `ambassador` Helm release:

```shell
helm delete ambassador -n ambassador
```

Next, check that the namespace resources were deleted (listing should be empty):

```shell
kubectl get all -n ambassador
```

Finally, verify that the `echo` and `quote` backend services `endpoint` is `DOWN` (please refer to [Creating the Ambassador Edge Stack Backend Services](../03-setup-ingress-controller/ambassador.md#step-4---creating-the-ambassador-edge-stack-backend-services)), regarding the `backend applications` used in the `Starter Kit` tutorial). You can use `curl` to test (or you can use your web browser):

```shell
curl -Li http://quote.starter-kit.online/quote/

curl -Li http://echo.starter-kit.online/echo/
```

### Restoring the Ambassador Helm Release Backup

**Important notes:**

- If restoring into the same namespace, ensure that the original application components have been removed. Especially the PVC of application are deleted.
- If restoring to another cluster (migration scenario), ensure that TrilioVault for Kubernetes is running in the remote namespace/cluster as well. To restore into a new cluster (where the Backup CR does not exist), `source.type` must be set to `location`. Please refer to the [Custom Resource Definition Restore Section](https://docs.trilio.io/kubernetes/architecture/apis-and-command-line-reference/custom-resource-definitions-application-1/triliovault-crds#example-5-restore-from-specific-location-migration-scenario) to view a `restore` by `location` example.
- When you delete the `ambassador` namespace, the load balancer resource associated with the ambassador service will be deleted as well. So, when you restore the `ambassador` service, the `LB` will be recreated by `DigitalOcean`. The issue is that you will get a `NEW IP` address for your `LB`, so you will need to `adjust` the `A records` for getting `traffic` into your domains hosted on the cluster.

To restore a specific `Backup`, you need to create a `Restore` CRD. Typical `Restore` CRD looks like below:

```yaml
apiVersion: triliovault.trilio.io/v1
kind: Restore
metadata:
  name: ambassador-helm-release-restore
  namespace: ambassador
spec:
  source:
    type: Backup
    backup:
      name: ambassador-helm-release-full-backup
      namespace: ambassador
  skipIfAlreadyExists: true
```

Explanation for the above configuration:

- `spec.source.type`: Specifies what backup type to restore from.
- `spec.source.backup`: Contains a reference to the backup object to restore from.
- `spec.skipIfAlreadyExists`: Specifies whether to skip restore of a resource if it already exists in the namespace restored.

`Restore` allows you to restore the last successful `Backup` for an application. It is used to restore a single `namespaces` or `Helm release`, protected by the `Backup` CRD. The `Backup` CRD is identified by its name: `ambassador-helm-release-full-backup`.

First, inspect the `Restore` CRD example from the `Starter Kit` Git repository:

```shell
code 06-setup-backup-restore/assets/manifests/ambassador-helm-release-restore.yaml
```

Then, create the `Restore` resource using `kubectl`:

```shell
kubectl apply -f 06-setup-backup-restore/assets/manifests/ambassador-helm-release-restore.yaml
```

Finally, inspect the `Restore` object status:

```shell
kubectl get restore ambassador-helm-release-restore -n ambassador
```

The output looks similar to (notice the STATUS column set to `Completed`, as well as the `PERCENTAGE COMPLETED` set to `100`):

```text
NAME                              STATUS      DATA SIZE   START TIME             END TIME               PERCENTAGE COMPLETED   DURATION
ambassador-helm-release-restore   Completed   0           2021-11-25T15:06:52Z   2021-11-25T15:07:35Z   100                    43.524191306s
```

If the output looks like above, then the `ambassador` Helm release `restoration` process completed successfully.

### Verifying Applications Integrity after Restoration

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

Next step deals with whole cluster backup and restore, thus covering a disaster recovery scenario.

## Step 5 - Backup and Restore Whole Cluster Example

In this step, you will simulate a `disaster recovery` scenario. The whole `DOKS` cluster will be deleted, and then the important applications restored from a previous backup.

Next, you will perform the following tasks:

- `Create` the `multi-namespace backup`, using a `ClusterBackupPlan` CRD that targets `all important namespaces` from your `DOKS` cluster.
- `Delete` the `DOKS` cluster, using `doctl`.
- `Re-install` TVK and configure the S3 target (you're going to use the same S3 bucket, where your important backups are stored)
- `Restore` all the important applications by using the TVK web console.
- `Check` the `DOKS` cluster applications integrity.

### Creating the DOKS Cluster Backup

The main idea here is to perform a `DOKS` cluster `backup` by including `all important namespaces`, that hold your essential `applications` and `configurations`. Basically, we cannot name it a full cluster backup and restore, but rather a `multi-namespace` backup and restore operation. In practice this is all that's needed, because everything is `namespaced` in `Kubernetes`. You will also learn how to perform a cluster restore operation via `location` from the `target`. The same flow applies when you need to perform cluster migration.

Typical `ClusterBackupPlan` manifest targeting multiple namespaces looks like below:

```yaml
apiVersion: triliovault.trilio.io/v1
kind: ClusterBackupPlan
metadata:
  name: starter-kit-cluster-backup-plan
  namespace: tvk
spec:
  backupConfig:
    target:
      name: trilio-s3-target
      namespace: tvk
  backupComponents:
    - namespace: ambassador
    - namespace: backend
    - namespace: monitoring
```

Notice that `kube-system` (or other DOKS cluster related namespaces) is not included in the list. Usually, those are not required, unless there is a special case requiring some settings to be persisted at that level.

Steps to initiate a backup for all important namespaces in your DOKS cluster:

1. First, change directory where the `Starter Kit` Git repository was cloned on your local machine:

    ```shell
    cd Kubernetes-Starter-Kit-Developers
    ```

2. Then, open and inspect the `ClusterBackupPlan` and `ClusterBackup` manifest files provided in the `Starter Kit` repository, using an editor of your choice (preferably with `YAML` lint support). You can use [VS Code](https://code.visualstudio.com) for example:

    ```shell
    code 06-setup-backup-restore/assets/manifests/starter-kit-cluster-backup-plan.yaml

    code 06-setup-backup-restore/assets/manifests/starter-kit-cluster-backup.yaml
    ```

3. Finally, create the `ClusterBackupPlan` and `ClusterBackup` resources, using `kubectl`:

    ```shell
    kubectl apply -f 06-setup-backup-restore/assets/manifests/starter-kit-cluster-backup-plan.yaml

    kubectl apply -f 06-setup-backup-restore/assets/manifests/starter-kit-cluster-backup.yaml
    ```

Now, inspect the `ClusterBackupPlan` status, using `kubectl`:

```shell
kubectl get clusterbackupplan starter-kit-cluster-backup-plan -n tvk
```

The output looks similar to (notice the `STATUS` column value which should be set to `Available`):

```text
NAME                              TARGET             ...   STATUS
starter-kit-cluster-backup-plan   trilio-s3-target   ...   Available
```

Next, check the `ClusterBackup` status, using `kubectl`:

```shell
kubectl get clusterbackup starter-kit-cluster-backup -n tvk
```

The output looks similar to (notice the `STATUS` column value which should be set to `Available`, as well as the `PERCENTAGE COMPLETE` set to `100`):

```text
NAME                        BACKUPPLAN                        BACKUP TYPE   STATUS      ...   PERCENTAGE COMPLETE
starter-kit-cluster-backup  starter-kit-cluster-backup-plan   Full          Available   ...   100                               
```

If the output looks like above then all your important application namespaces were backed up successfully.

**Note:**

Please bear in mind that it may take a while for the full cluster backup to finish, depending on how many namespaces and associated resources are involved in the process.

You can also open the web console main dashboard and inspect the `multi-namespace` backup (notice how all the important namespaces that were backed up are highlighted in green color, in a honeycomb structure):

![TVK Multi-Namespace Backup Overview](assets/images/tvk_multi_ns_backup.png)

### Re-creating the DOKS Cluster and Restoring Applications

An important aspect to keep in mind is that whenever you destroy a `DOKS` cluster and then restore it, a new `Load Balancer` with a new external `IP` is created as well when `TVK` restores your `ingress` controller. So, please make sure to update your DigitalOcean DNS `A records` accordingly.

Now, delete the whole `DOKS` cluster (make sure to replace the `<>` placeholders accordingly):

```shell
doctl kubernetes cluster delete <DOKS_CLUSTER_NAME>
```

Next, re-create the cluster as described in [Section 1 - Set up DigitalOcean Kubernetes](../01-setup-DOKS/README.md).

To perform the restore operation, you need to install the `TVK` application as described in [Step 1 - Installing TrilioVault for Kubernetes](#step-1---installing-triliovault-for-kubernetes). Please make sure to use the `same Helm Chart version` - this is important!

After the installation finishes successfully, configure the `TVK` target as described in [Step 2 - Creating a TrilioVault Target to Store Backups](#step-2---creating-a-triliovault-target-to-store-backups), and point it to the same `S3 bucket` where your backup data is located. Also, please make sure that `target browsing` is enabled.

Next, verify and activate a new license as described in the [TrilioVault Application Licensing](#triliovault-application-licensing) section.

To get access to the web console user interface, please consult [Getting Access to the TVK Web Management Console](#getting-access-to-the-tvk-web-management-console) section.

Then, navigate to `Resource Management -> TVK Namespace -> Targets` (in case of `Starter Kit` the TVK Namespace is `tvk`):

![TVK Targets List](assets/images/tvk_target_list.png)

Going further, browse the target and list the available backups by clicking on the `Actions` button from the right. Then, select `Launch Browser` option from the pop-up menu (for this to work the target must have the `enableBrowsing` flag set to `true`):

![TVK Target Browser](assets/images/tvk_target_browser.png)

Now, click on the `starter-kit-cluster-backup-plan` item from the list, and then click and expand the `starter-kit-cluster-backup` item from the right sub-window:

![Multi-Namespace Restore Phase 1](assets/images/multi-ns-restore_phase_1.png)

To start the restore process, click on the `Restore` button. A progress window will be displayed similar to:

![Multi-Namespace Restore Phase 2](assets/images/multi-ns-restore_phase_2.png)

After a while, if the progress window looks like below, then the `multi-namespace` restore operation completed successfully:

![Multi-Namespace Restore Phase 3](assets/images/multi-ns-restore_phase_3.png)

### Checking DOKS Cluster Applications State

First, verify all cluster `Kubernetes` resources (you should have everything in place):

```shell
kubectl get all --all-namespaces
```

Then, make sure that your DNS A records are updated to point to your new load balancer external IP.

Finally, the `backend applications` should respond to `HTTP` requests as well (please refer to [Creating the Ambassador Edge Stack Backend Services](../03-setup-ingress-controller/ambassador.md#step-4---creating-the-ambassador-edge-stack-backend-services)), regarding the `backend applications` used in the `Starter Kit` tutorial):

```shell
curl -Li http://quote.starter-kit.online/quote/

curl -Li http://echo.starter-kit.online/echo/
```

In the next step, you will learn how to perform scheduled (or automatic) backups for your `DOKS` cluster applications.

## Step 6 - Scheduled Backups

Taking backups automatically based on a schedule, is a really useful feature to have. It allows you to `rewind back time`, and restore the system to a previous working state if something goes wrong. This section provides an example for an automatic backup on a `5 minute` schedule (the `kube-system` namespace was picked).

First, you need to create a `Policy` CRD of type `Schedule` that defines the backup schedule in `cron` format (same as `Linux` cron). Schedule polices can be used for either `BackupPlan` or `ClusterBackupPlan` CRDs. Typical schedule policy CRD looks like below (defines a `5 minute` schedule):

```yaml
kind: Policy
apiVersion: triliovault.trilio.io/v1
metadata:
  name: scheduled-backup-every-5min
  namespace: tvk
spec:
  type: Schedule
  scheduleConfig:
    schedule:
      - "*/5 * * * *" # trigger every 5 minutes
```

Next, you can apply the schedule policy to a `ClusterBackupPlan` CRD for example, as seen below:

```yaml
apiVersion: triliovault.trilio.io/v1
kind: ClusterBackupPlan
metadata:
  name: kube-system-ns-backup-plan-5min-schedule
  namespace: tvk
spec:
  backupConfig:
    target:
      name: trilio-s3-target
      namespace: tvk
    schedulePolicy:
      fullBackupPolicy:
        name: scheduled-backup-every-5min
        namespace: tvk
  backupComponents:
    - namespace: kube-system
    - namespace: backend
```

Looking at the above, you can notice that it's a basic `ClusterBackupPlan` CRD, referencing the `Policy` CRD defined earlier via the `spec.backupConfig.schedulePolicy` field. You can have separate policies created for `full` or `incremental` backups, hence the `fullBackupPolicy` or `incrementalBackupPolicy` can be specified in the spec.

Now, please go ahead and create the schedule `Policy`, using the sample manifest provided by the `Starter Kit` tutorial (make sure to change directory first, where the Starter Kit Git repository was cloned on your local machine):

```shell
kubectl apply -f 06-setup-backup-restore/assets/manifests/scheduled-backup-every-5min.yaml
```

Check that the policy resource was created:

```shell
kubectl get policies -n tvk
```

The output looks similar to (notice the `POLICY` type set to `Schedule`):

```text
NAME                          POLICY     DEFAULT
scheduled-backup-every-5min   Schedule   false
```

Finally, create the resources for the `kube-system` namespace scheduled backups:

```shell
# Create the backup plan first for kube-system namespace
kubectl apply -f 06-setup-backup-restore/assets/manifests/kube-system-ns-backup-plan-scheduled.yaml

# Create and trigger the scheduled backup for kube-system namespace
kubectl apply -f 06-setup-backup-restore/assets/manifests/kube-system-ns-backup-scheduled.yaml
```

Check the scheduled backup plan status for `kube-system`:

```shell
kubectl get clusterbackupplan kube-system-ns-backup-plan-5min-schedule -n tvk
```

The output looks similar to (notice the `FULL BACKUP POLICY` value set to the previously created `scheduled-backup-every-5min` policy resource, as well as the `STATUS` which should be `Available`):

```text
NAME                                       TARGET             ...   FULL BACKUP POLICY            STATUS
kube-system-ns-backup-plan-5min-schedule   trilio-s3-target   ...   scheduled-backup-every-5min   Available
```

Check the scheduled backup status for `kube-system`:

```shell
kubectl get clusterbackup kube-system-ns-full-backup-scheduled -n tvk
```

The output looks similar to (notice the `BACKUPPLAN` value set to the previously created backup plan resource, as well as the `STATUS` which should be `Available`):

```text
NAME                                   BACKUPPLAN                                 BACKUP TYPE   STATUS      ...
kube-system-ns-full-backup-scheduled   kube-system-ns-backup-plan-5min-schedule   Full          Available   ...
```

Now, you can check that backups are performed on a regular interval (5 minutes), by querying the cluster backup resource and inspect the `START TIME` column (`kubectl get clusterbackup -n tvk`). It should reflect the 5 minute delta, as highlighted in the picture below:

![TVK Every 5 Minute Backups](assets/images/tvk_scheduled_backups_5min.png)

In the next step, you will learn how to set up a retention policy for your backups.

## Step 7 - Backups Retention Policy

The retention policy allows you to define the `number` of backups to `retain` and the `cadence` to `delete` backups as per compliance requirements. The retention policy `CRD` provides a simple `YAML` specification to define the `number` of backups to retain in terms of `days`, `weeks`, `months`, `years`, latest etc.

### Using Retention Policies

Retention polices can be used for either `BackupPlan` or `ClusterBackupPlan` CRDs. Typical `Policy` manifest for the `Retention` type looks like below:

```yaml
apiVersion: triliovault.trilio.io/v1
kind: Policy
metadata:
  name: sample-policy
spec:
  type: Retention
  retentionConfig:
    latest: 2
    weekly: 1
    dayOfWeek: Wednesday
    monthly: 1
    dateOfMonth: 15
    monthOfYear: March
    yearly: 1
```

Explanation for the above configuration:

- `spec.type`: Defines policy type. Can be: `Retention` or `Schedule`.
- `spec.retentionConfig`: Describes retention configuration, like what interval to use for backups retention and how many.
- `spec.retentionConfig.latest`: Maximum number of latest backups to be retained.
- `spec.retentionConfig.weekly`: Maximum number of backups to be retained in a week.
- `spec.retentionConfig.dayOfWeek`: Day of the week to maintain weekly backups.
- `spec.retentionConfig.monthly`: Maximum number of backups to be retained in a month.
- `spec.retentionConfig.dateOfMonth`: Date of the month to maintain monthly backups.
- `spec.retentionConfig.monthOfYear`: Month of the backup to retain for yearly backups.
- `spec.retentionConfig.yearly`: Maximum number of backups to be retained in a year.

The above retention policy translates to:

- On a `weekly` basis, keep one backup each `Wednesday`.
- On a `monthly` basis, keep one backup in the `15th` day.
- On a `yearly` basis, keep one backup every `March`.
- `Overall`, I want to always have the `2 most recent` backups available.

The basic flow for creating a retention policy resource goes the same way as for scheduled backups. You need a `BackupPlan` or a `ClusterBackupPlan` CRD defined to reference the retention policy, and then have a `Backup` or `ClusterBackup` object to trigger the process.

Typical `ClusterBackupPlan` example configuration that has retention set, looks like below:

```yaml
apiVersion: triliovault.trilio.io/v1
kind: ClusterBackupPlan
metadata:
  name: kube-system-ns-backup-plan-5min-schedule
  namespace: tvk
spec:
  backupConfig:
    target:
      name: trilio-s3-target
      namespace: tvk
    retentionPolicy:
      fullBackupPolicy:
        name: ambassador-backups-retention-policy
        namespace: tvk
  backupComponents:
    - namespace: kube-system
    - namespace: backend
```

Notice that it uses a `retentionPolicy` field to reference the policy in question. Of course, you can have a backup plan that has both types of policies set, so that it is able to perform scheduled backups, as well as to deal with retention strategies.

### Using Cleanup Policies

Having so many TVK resources each responsible with various operations like: scheduled backups, retention, etc, it is very probable for things to go wrong at some point in time. It means that some of the previously enumerated operations might fail due to various reasons, like: inaccessible storage, network issues for NFS, etc. So, what happens is that your `DOKS` cluster will get `crowded` with many `Kubernetes objects` in a `failed state`.

You need a way to garbage collect all those objects in the end and release associated resources, to avoid trouble in the future. Meet the `Cleanup Policy` CRD:

```yaml
apiVersion: triliovault.trilio.io/v1
kind: Policy
metadata:
  name: garbage-collect-policy
spec:
  type: Cleanup
  cleanupConfig:
    backupDays: 5
```

The above cleanup policy must be defined in the `TVK` install namespace. Then, a `cron job` is created automatically for you that runs `every 30 mins`, and `deletes failed backups` based on the value specified for `backupdays` within the spec field.

This is a very neat feature that TVK provides to help you deal with this kind of situation.

## Conclusion

In this tutorial, you learned how to perform `one time`, as well as `scheduled` backups, and to restore everything back. Having `scheduled` backups in place, is very important as it allows you to revert to a previous snapshot in time, if something goes wrong along the way. You walked through a disaster recovery scenario, as well. Next, backups retention plays an important role as well, because storage is finite and sometimes it can get expensive if too many objects are implied.

All the basic tasks and operations explained in this tutorial, are meant to give you a basic introduction and understanding of what `TrilioVault for Kubernetes` is capable of. You can learn more about `TrilioVault for Kubernetes` and other interesting (or useful) topics, by following the links below:

- TVK [CRD API](https://docs.trilio.io/kubernetes/architecture/apis-and-command-line-reference/custom-resource-definitions-application-1) documentation.
- [How to Integrate Pre/Post Hooks for Backup Operations](https://docs.trilio.io/kubernetes/architecture/apis-and-command-line-reference/custom-resource-definitions-application-1/triliovault-crds#hooks), with examples given for various databases.
- [Immutable Backups](https://docs.trilio.io/kubernetes/architecture/apis-and-command-line-reference/custom-resource-definitions-application-1/triliovault-crds#immutability), which restrict backups on the target storage to be overwritten.
- [Helm Releases Backup](https://docs.trilio.io/kubernetes/architecture/apis-and-command-line-reference/custom-resource-definitions-application-1/triliovault-crds#type-helm-example-1-single-helm-release), which shows examples for Helm releases backup strategies.
- [Backups Encryption](https://docs.trilio.io/kubernetes/architecture/apis-and-command-line-reference/custom-resource-definitions-application-1/triliovault-crds#type-encryption), which explains how to encrypt and protect sensitive data on the target (storage).
- [Disaster Recovery Plan](https://docs.trilio.io/kubernetes/management-console/user-interface/use-cases-with-trilio/disaster-recovery-plan).
- [Multi-Cluster Management](https://docs.trilio.io/kubernetes/management-console/user-interface/use-cases-with-trilio/multicloud-management).
- [Restore Transforms](https://docs.trilio.io/kubernetes/overview/features-and-use-cases#restore-transforms).

Go to [Section 7 - Alerts and Notifications](../07-alerting-and-notification/README.md).
