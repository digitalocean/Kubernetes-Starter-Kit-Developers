## Backup using Velero <a name="VELE"></a>

For a detailed step-by-step tutorial, follow this community guide - [Installing the Velero Client](https://www.digitalocean.com/community/tutorials/how-to-back-up-and-restore-a-kubernetes-cluster-on-digitalocean-using-velero).

- [Prerequisites](#prerequisites)
- [Credentials setup](#credentials-setup)
- [Velero installation](#velero-installation)
- [Snapshot configuration](#snapshot-configuration)
- [Backup and restore example](#backup-and-restore-example)
- [Build the plugin](#build-the-plugin)

### Prerequisites

* Download and install velero client (1.2.0).
* Download the latest stable velero release (1.0.0) from [Velero GitHub](https://github.com/digitalocean/velero-plugin/releases/tag/v1.0.0)
* Create a Space bucket and access keys. You can do so from your DigitalOcean cloud console, follow API, and then Spaces acccess keys. You should have an access key name and a secret. We will use those in step 2 in the section below. 
* You should have an DO API token. If not, create one for velero from the cloud console, follow API, and then API token.


### Velero installation

We will use velero client (on our laptop) to install velero plugin (downloaded from Github onto our laptop) onto the cluster. But before doing that, we need to change the required credentials for velero to use.

1. Make sure to complete the Prerequisites steps mentioned above.
   
2. Unzip the velero-plugin downloaded as part of prerequisites. `cd` into the `examples` directory and edit the `cloud-credentials` file. The file will look like this:

    ```
    [default]
    aws_access_key_id=<AWS_ACCESS_KEY_ID>
    aws_secret_access_key=<AWS_SECRET_ACCESS_KEY>
    ```

Edit the `<AWS_ACCESS_KEY_ID>` and `<AWS_SECRET_ACCESS_KEY>` placeholders to use your DigitalOcean Spaces key name and secret. 

![Dashboard location for snapshot image](../images/velero-backup-space.png)

3. In the `examples` directory, edit the `01-velero-secret.patch.yaml` file. It should look like this:

    ```
    ---
    apiVersion: v1
    kind: Secret
    stringData:
    digitalocean_token: <DIGITALOCEAN_API_TOKEN>
    type: Opaque
    ```

   * Change the entire `<DIGITALOCEAN_API_TOKEN>` portion to use your DigitalOcean personal API token. The line should look something like `digitalocean_token: 18a0d730c0e0....`


4. Install Velero, and configure the snapshot storage location to work with backups. Ensure that you edit each of the following settings to match your Spaces configuration before running the `velero install` command:
   
   * `--bucket velero-backups` - Ensure you change the `velero-backups` value to match the name of your Space.
   * `--backup-location-config s3Url=https://nyc3.digitaloceanspaces.com,region=nyc3` - Change the URL and region to match your Space's settings. Specifically, edit the `nyc3` portion in both to match the region where your Space is hosted. Use one of `nyc3`, `sfo2`, `sgp1`, or `fra1` depending on your region.

5. Now run the install command:

    ```
    velero install \
      --provider velero.io/aws \
      --bucket starterkit-velero-backups \
      --plugins velero/velero-plugin-for-aws:v1.0.0,digitalocean/velero-plugin:v1.0.0 \
      --backup-location-config s3Url=https://fra1.digitaloceanspaces.com,region=fra1 \
      --use-volume-snapshots=false \
      --use-restic \
      --secret-file ./velero-plugin-1.0.0/examples/cloud-credentials
    ```
Explanation above configuration:

* provider aws instructs Velero to utilize S3 storage (DigitalOcean Spaces).
* secret-file is our DO credentials
* use-restic flag ensures Velero knows to deploy restic for persistentvolume backups
* s3Url value is the address of the DO service that is only resolvable from within the Kubernetes cluster.

### Snapshot configuration

1. Enable the `digitalocean/velero-plugin:v1.0.0` snapshot provider. This command will configure Velero to use the plugin for persistent volume snapshots.

    ```
    velero snapshot-location create default --provider digitalocean.com/velero
    ```

2. Patch the `cloud-credentials` Kubernetes Secret object that the `velero install` command installed in the cluster. This command will add your DigitalOcean API token to the `cloud-credentials` object so that this plugin can use the DigitalOcean API:


    ```
    kubectl patch secret cloud-credentials -p "$(cat 01-velero-secret.patch.yaml)" --namespace velero
    ```

3. Patch the `velero` Kubernetes Deployment to expose your API token to the Velero pod(s). Velero needs this change in order to authenticate to the DigitalOcean API when manipulating snapshots:

    ```
    kubectl patch deployment velero -p "$(cat 02-velero-deployment.patch.yaml)" --namespace velero
    ```


### Backup and Restore Example

1. Ensure that your Ambassador Deployment is running and there is a Service with an `EXTERNAL-IP` (`kubectl get service --namespace ambassador`). Browse the IP a few times to write some log entries to the persistent volume. Then create a backup with Velero:

    ```
    velero backup create ambassador-backup --include-namespaces ambassador
    velero backup describe ambassador-backup --details
    ```
    Let's look at deeply structure of backups by using below command.
    ```
    ~ kubectl get backup/ambassador-backup -n velero -o yaml

    apiVersion: velero.io/v1
    kind: Backup
    metadata:
      annotations:
        velero.io/source-cluster-k8s-gitversion: v1.21.2
        velero.io/source-cluster-k8s-major-version: "1"
        velero.io/source-cluster-k8s-minor-version: "21"
      creationTimestamp: "2021-08-18T17:11:14Z"
      generation: 5
      labels:
        velero.io/storage-location: default
      name: ambassador-backup
      namespace: velero
      resourceVersion: "1870184"
      uid: 1163afa8-4521-4b6c-bc9c-2856666fd2e1
    spec:
      defaultVolumesToRestic: false
      hooks: {}
      includedNamespaces:
      - ambassador
      storageLocation: default
      ttl: 720h0m0s
      volumeSnapshotLocations:
      - default
    status:
      completionTimestamp: "2021-08-18T17:11:19Z"
      expiration: "2021-09-17T17:11:14Z"
      formatVersion: 1.1.0
      phase: Completed
      progress:
        itemsBackedUp: 86
        totalItems: 86
      startTimestamp: "2021-08-18T17:11:14Z"
      version: 1
    ```
    When you look at the result,please check `includedNamespaces` is ambassador and also you can confuse when you see .*velero.io/storage-location: default* . Default means that `starterkit-velero-backups` .
    ```
    ~# velero backup-location get
    
    NAME      PROVIDER        BUCKET/PREFIX               PHASE       LAST VALIDATED                  ACCESS MODE   DEFAULT
    default   velero.io/aws   starterkit-velero-backups   Available   2021-08-18 17:22:44 +0000 UTC   ReadWrite     true

    ```
    

Check below image for understanding of backup process better.

![Dashboard location for backup image](../images/velero-backup-space-2.png)


2. The various backup files will be in your Spaces bucket. A snapshot of the persistent volume will be listed in the DigitalOcean control panel under the *Images* link. Now you can simulate a disaster by deleting the  ambassador` namespace.

    ```
    kubectl delete namespace ambassador
    ```

3. Once the delete finishes, restore the `ambassador-backup` backup:

    ```
    velero restore create --from-backup ambassador-backup
    ```

4. Check the restored PersistentVolume, Deployment, and Service are back using `kubectl`:
    ```
    kubectl get persistentvolume --namespace ambassador
    kubectl get service --namespace ambassador
    kubectl get deployment --namespace ambassador
    ```
### Backup and Restore Whole NameSpaces

1. Create a backup after ensuring all services running without adding namespace at the end of the command.
   
   ```
   velero backup create all-cluster
   ```
2. Delete everything without velero namespace(or you can separate backup service and target services in a different cluster).
   
   ```
   kubectl delete ns --namespace=velero --all

   ```
3. Restore everything by using the below simple command. When you call  `kubectl get all --all-namespaces` you will see only velero and default services but be sure, recovering whole system takes time (~30s).

   ```
   velero restore create --from-backup all-cluster
   ```



### Backup and Restore All Cluster


1. Create a backup after ensuring all services running without adding namespace at the end of the command.
   
   ```
   velero backup create all-cluster
   ```
2. Delete whole cluster via below code.This command deletes the specified `Kubernetes clusters` and the `Droplets` associated with them.
   
   ```
    doctl kubernetes cluster delete

   ```
3. Restore everything by using the below simple command. When you call  `kubectl get all --all-namespaces` you will see nothing. But After restoring like below.When you call the same command ,you will see all services running.

   ```
   velero restore create --from-backup all-cluster
   ```




### Some Useful Command for Helping Better Understanding 
The output of the following commands will help us better understand what's going on: (Pasting long output into a GitHub gist or other pastebin is fine.)
```
kubectl logs deployment/velero -n velero
velero backup describe <backupname> or kubectl get backup/<backupname> -n velero -o yaml
velero backup logs <backupname>
velero restore describe <restorename> or kubectl get restore/<restorename> -n velero -o yaml
velero restore logs <restorename>
```
#### Delete SnapShot

```
kubectl delete volumesnapshotlocation.velero.io -n velero starterkit-velero-backups
```
#### About Backups
When you decide to check under the hood, you can use the below code to understand better what is going on in your backup process.

```
velero backup get
velero backup delete backupname
velero get snapshot-location

```

Go to [Section 14 - Estimate resources for startup kit](../14-starter-kit-resource-usage)
