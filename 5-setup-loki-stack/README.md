## Logs Aggregation via Loki Stack

### Table of contents

- [Overview](#overview)
- [Installing LOKI](#installing-loki)
- [Configure Grafana with Loki](#configure-grafana-with-loki)
- [Promtail](#promtail)
- [LogQL](#logql)
- [Setting Persistent Storage for Loki](#setting-persistent-storage-for-loki)


### Overview

What is `Loki`?

> Loki is a `horizontally-scalable`, `highly-available`, `multi-tenant` log aggregation system inspired by `Prometheus`.

Why use `Loki` in the first place? The main reasons are (some were already highlighted above):

* `Horizontally scalable`
* `High availabilty`
* `Multi-tenant` mode available
* `Stores` and `indexes` data in a very `efficient` way
* `Cost` effective
* `Easy` to operate
* `LogQL` DSL (offers the same functionality as `PromQL` from `Prometheus`, which is a plus if you're already familiar with it)

This is how the main setup looks like after completing this tutorial:

![Loki Setup](res/img/arch_aes_prom_loki_grafana.jpg)


### Installing LOKI

We need [Loki](https://github.com/grafana/helm-charts/tree/main/charts/loki-stack) for logs. `Loki` runs on the cluster itself as a `StatefulSet`. Logs are `aggregated` and `compressed` by `Loki`, then sent to the configured `storage`. Then, you can connect `Loki` data source to `Grafana` and view the logs.

Steps to follow:

1. Add the `Helm` repo and list the available charts:

    ```shell
    helm repo add grafana https://grafana.github.io/helm-charts

    helm search repo grafana
    ```

    The output looks similar to the following:

    ```
    NAME                                            CHART VERSION   APP VERSION     DESCRIPTION                                       
    grafana/grafana                                 6.16.2          8.1.2           The leading tool for querying and visualizing t...
    grafana/enterprise-metrics                      1.5.0           v1.5.0          Grafana Enterprise Metrics                        
    grafana/fluent-bit                              2.3.0           v2.1.0          Uses fluent-bit Loki go plugin for gathering lo...
    grafana/loki                                    2.4.1           v2.1.0          Loki: like Prometheus, but for logs.
    ...
    ```

    **Note:**

    The chart of interes is `grafana/loki-stack`, which will install standalone `Loki` on the cluster. Please visit the [loki-stack](https://github.com/grafana/helm-charts/tree/main/charts/loki-stack) page for more details about this chart.

2. Fetch and inspect the values file:

    ```shell
    helm show values grafana/loki-stack --version 2.4.1 > loki-values.yaml
    ```

    **Hint:**

    It's good practice in general to fetch the values file and inspect it to see what options are available. This way, you can keep for example only the features that you need for your project and disable others to save on resource usage.

3. Install the stack. The following command will take care of everything for you:

    ```shell
    helm install loki grafana/loki-stack --version 2.4.1 \
      --namespace=monitoring \
      --create-namespace \
      --set loki.enabled=true \
      --set grafana.enabled=false \
      --set prometheus.enabled=false \
      --set promtail.enabled=true
    ``` 

    **Notes:**

    * A `specific` version for the `Helm` chart is used. In this case `2.4.1` was picked, which maps to the `2.3.0` release of `Loki` (see the output from `Step 1.`). It's good practice in general to lock on a specific version or range (e.g. `^2.4.1`). This helps to avoid future issues caused by breaking changes introduced in major version releases. On the other hand, it doesn't mean that a future major version ugrade is not an option. You need to make sure that the new version is tested first. Having a good strategy in place for backups and snapshots becomes handy here (covered in more detail in [Section 6 - Backup Using Velero](../6-setup-velero)).
    * `Promtail` is needed so it will be enabled (explained in [Promtail](#promtail) section).
    * `Prometheus` and `Grafana` installation is disabled because [Section 4 - Set up Prometheus Stack](../4-setup-prometheus-stack) took care of it already.

In the next part you will configure `Grafana` to use the `Loki` datasource so that you can query for logs.


### Configure Grafana with Loki

You already have `Loki` and `Grafana` installed. Now it's time to connect things together to benefit from both worlds.

Let's add the `Loki` data source to `Grafana`. Go to the `Grafana` web console and follow these steps: 

1. Click the `Settings` gear from the left panel.
2. Select `Data sources`.
3. Click the `Add data source` blue button.
4. Select `Loki` from the list and add `Loki` url `http://loki:3100`. 
5. Save and test.

If everything went well a green label message will appear saying `Data source connected and labels found.`

Now you can access logs from the `Explore` tab of `Grafana`. Make sure to select `Loki` as the data source. Use `Help` button for log search cheat sheet.

In the next section you will discover `Promtail`, which is the agent responsible with `fetching` the logs and `labeling` the data.


### Promtail

`Promtail` is an `agent` which ships the contents of local logs to a private `Loki` instance. It is usually deployed to every machine that has applications needed to be monitored. It comes bundled with the [Loki Stack](#installing-loki) stack you deployed earlier and it was enabled via the `<promtail.enabled>` Helm value.

What `Promtail` does is:

* `Discovers` targets
* `Attaches labels` to `log streams`
* `Pushes` them to the `Loki` instance.

**Log file discovery:**

Before `Promtail` can ship any data from log files to `Loki`, it needs to find out information about its environment. Specifically, this means discovering applications emitting log lines to files that need to be monitored.

`Promtail` borrows the same service discovery mechanism from `Prometheus`, although it currently only supports `Static` and `Kubernetes` service discovery. This limitation is due to the fact that `Promtail` is deployed as a daemon to every local machine and, as such, does not discover label from other machines. `Kubernetes` service discovery fetches required labels from the `Kubernetes API` server while `Static` usually covers all other use cases.

As with every `monitoring agent` you need to have a way for it to be up all the time. The `Loki` stack `Helm` deployment already makes this possible via a `DaemonSet`, as seen below:

```shell
kubectl get ds -n monitoring
```

The output looks similar to the following (notice the `loki-promtail` line):

```
NAME                                       DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
kube-prom-stack-prometheus-node-exporter   2         2         2       2            2           <none>          7d4h
loki-promtail                              2         2         2       2            2           <none>          5h6m
```

This is great! But how does it discover `Kubernetes` pods and assigns labels? Let's have a look at the associated `ConfigMap`:

```shell
kubectl get cm loki-promtail -n monitoring -o yaml
```

The output looks similar to the following:

```
scrape_configs:
  - job_name: kubernetes-pods-name
    pipeline_stages:
      - docker: {}
    kubernetes_sd_configs:
    - role: pod
    relabel_configs:
    - action: replace
      source_labels:
      - __meta_kubernetes_namespace
      target_label: namespace
```

As seen above in the `scrape_configs` section, there's a `kubernetes-pods-name` job, which:

* Helps with `service discovery` on the `Kubernetes` side via `kubernetes_sd_configs` (works by using the `Kubernetes API` from the node that the `loki-prommtail DaemonSet` runs on).
* Re-labels `__meta_kubernetes_namespace` to `namespace` in the `relabel_configs` section.

For more features and in depth explanations please visit the [Promtail](https://grafana.com/docs/loki/latest/clients/promtail) official page.

In the next section you'll be introduced to `LogQL` which is the `PromQL` brother, but for logs. Some basic features of `LogQL` will be presented as well.


### LogQL

`Loki` comes with its very own language for querying the logs called `LogQL`. `LogQL` can be considered a `distributed grep` with `labels` for filtering.

A basic `LogQL` query consists of two parts: the `log stream selector` and a `filter` expression. Due to Loki’s design, all `LogQL` queries are required to contain a `log stream selector`.

The `log stream selector` will reduce the number of log streams to a manageable volume. Depending on how many labels you use to filter down the log streams it will affect the relative performance of the query’s execution. The filter expression is then used to do a distributed grep over the retrieved log streams.

Let's move to a practical example now and query `Ambassador` logs from the `AES` deployment. Please follow the steps below:

1. Get access to `Grafana` web interface:

    ```shell
    kubectl port-forward svc/kube-prom-stack-grafana 3000:80 -n monitoring
    ```
2. Open the [web console](http://localhost:3000) and navigate to the `Explore` tab from the left panel. Select `Loki` from the data source menu and run this query:
    
    ```
    {container="ambassador",namespace="ambassador"}
    ```

    The output looks similar to the following:

    ![LogQL Query Example](res/img/lql_first_example.png)
3. Let's query again, but this time filter the results to include only `warning` messages:

    ```
    {container="ambassador",namespace="ambassador"} |= "warning"
    ```

    The output looks similar to the following (notice the `warning` word being highlighted in the results window):

    ![LogQL Query Example](res/img/lql_second_example.png)

As seen in the above examples, each query is composed of:

* A `log stream` selector `{container="ambassador",namespace="ambassador"}` which targets the `ambassador container` from the `ambassador namespace`.
* A `filter` like `|= "warning"`, which will filter out lines that contain only the `warning` word

More complex queries can be created using `aggregation` operators. For more details on that and other advanced topics, please visit the official [LogQL](https://grafana.com/docs/loki/latest/logql) page.

Another feature of `Loki` that is worth mentioning is [Labels](https://grafana.com/docs/loki/latest/getting-started/labels). `Labels` allows us to organize streams. In other words, `labels` add `metadata` to a log stream in order to distinguish it later. Essentially, they are `key-value` pairs that can be anything you want as long as they have a meaning for the data that is being tagged. 

The picture down below will highlight this feature in the `Log labels` sub-window from the query page (namely the: `filename`, `pod` and `product`):

![LogQL Labels Example](res/img/LQL.png)

Let's simplify it a little bit by taking the example from the above picture:

```
{namespace="ambassador"}
```

The `label` in question is called `namespace` - remember that labels are `key-value` pairs ? You can see it right there inside the curly braces. This tells `LogQL` that you want to fetch all the log streams that are tagged with the label called `namespace` and has the value equal to `ambassador`.


### Setting Persistent Storage for Loki

The default `Helm` install method used in the [Loki Install](#installing-loki) step doesn't configure `persistent` storage for `Loki`. It just uses the default [emptyDir](https://kubernetes.io/docs/concepts/storage/volumes/#emptydir) volume for storage which is ephemeral. To `preserve` indexed log data across Pod restarts, `Loki` can be set up to use `S3` compatible storage instead.

In terms of storage details, the setup used in this tutorial is relying on the default implementation, namely the [BoltDB Shipper](https://grafana.com/docs/loki/latest/operations/storage/boltdb-shipper/) for logs retention. This is the `preferred` and recommended way for `Loki`. In the next steps you're going to set `BoltDB` to use a remote storage instead - `DO Spaces`, to persist the data.

**Setting persistent storage via DO Spaces**

Below is an example for using remote storage via `DO Spaces` (similar to `AWS` implementatin):

```
schema_config:
  configs:
    - from: "2020-10-24"
      store: boltdb-shipper
      object_store: aws
      schema: v11
      index:
        prefix: index_
        period: 24h
storage_config:
  boltdb_shipper:
    active_index_directory: /data/loki/boltdb-shipper-active
    cache_location: /data/loki/boltdb-shipper-cache
    cache_ttl: 24h # Can be increased for faster performance over longer query periods, uses more disk space
    shared_store: aws
  aws:
    bucketnames: <DO_SPACES_BUCKET_NAME>
    endpoint: <DO_SPACES_BUCKET_ENDPOINT>  # format: <region>.digitaloceanspaces.com
    region: <DO_SPACES_BUCKET_REGION>
    access_key_id: <DO_SPACES_ACCESS_KEY>
    secret_access_key: <DO_SPACES_SECRET_KEY>
    s3forcepathstyle: true
```

Explanations for the above configuration:

* `schema_config` - defines a storage `type`, schema `version` and other details required when doing migrations (schemas can `differ` between `Loki` installations, so `consistency` is required). In this case, `BoltDB Shipper` is specified as the storage implementation and a `v11` schema version. The `24h` period for the index is the default and preferred value, so please don't change it. Please visit [Schema Configs](https://grafana.com/docs/loki/latest/storage/#schema-configs) for more details.
* `storage_config` - tells `Loki` about storage `configuration` details, like where data is stored and what kind of storage is used (`aws` type, which is the default implementation for `DO Spaces` as well).
* `aws` - tells `Loki` about the `remote` storage details (`bucket` name, `credentials`, `region`, etc).

In the next part, you're going to tell `Helm` how to configure the new `remote` storage and `schema`.

Steps to follow:

1. Change directory to where this repository was cloned.
2. Edit the [loki-values.yaml](res/manifests/loki-values.yaml#L26) sample file provided with this `Git` repository, and uncomment the lines for `DO Spaces` remote storage setup. Also, make sure to replace the `<>` placeholders accordingly in the `aws` subsection.
3. Upgrade the `Loki` stack to use the new storage settings via `Helm`:

    ```shell
      helm upgrade loki grafana/loki-stack --version 2.4.1 \
        --namespace=monitoring \
        --create-namespace \
        -f 5-setup-loki-stack/res/manifests/loki-values.yaml
      ```
4. Check that the main `Loki` application pod is up and running (it may take up to `1 minute` or so to start, so please be patient):

    ```shell
    kubectl get pods -n monitoring -l app=loki
    ```
    The output looks similar to:

    ```
    NAME     READY   STATUS    RESTARTS   AGE
    loki-0   1/1     Running   0          13m
    ```

    **Hint:**

    You can also check the logs while waiting. It's also good practice to check the application logs to see if something goes bad or not.

    ```shell
    kubectl logs -n monitoring -l app=loki
    ```
5. If everything goes well, you should also be able to see the `DO Spaces` bucket containing the `index` and `chunks` folders (the `chunks` folder is called `fake` - this is by design when not running in `multi-tenant` mode).

    ![Loki DO Spaces Storage](res/img/loki_storage_do_spaces.png)

For more advanced options and fine tuning the `storage` setup for `Loki`, please visit the [Loki Storage](https://grafana.com/docs/loki/latest/operations/storage/) documentation page.

#### **Setting Loki storage retention**

`Retention` is a very important aspect as well when it comes to storage setup, because `storage is finite`. While `storage` is `not expensive` in general, it can become if retention is not handled properly or not at all. In the next part, a simple overview of the `retention options` available for `Loki` is presented, as well as a `basic` configuration example.

Retention in `Loki` is achieved either through the [Table Manager](https://grafana.com/docs/loki/latest/operations/storage/retention/#table-manager) or the [Compactor](https://grafana.com/docs/loki/latest/operations/storage/retention/#Compactor).

In the next part, you'll discover both options, based on the installed `Loki` application `version`.

#### **Retention via Compactor**

**Important note:**

Before upgrading, please check if the deployed `Loki` application version is `>=2.3.0`. The features that you will configure next, work only if at least version `2.3.0` is used. The `2.4.1` version of the stack deployed in this tutorial, may use an older version for the `Loki` applicatiom, like `2.2.0`. Please follow the next steps in order to check if it's true or not.

Steps to follow to check if `Loki` application version is `>=2.3.0`, in order to benefit from new `Compactor` retention functionality:

1. Check the image version used by the Loki `StatefulSet`:

    ```shell
    kubectl describe sts loki -n monitoring
    ```
2. In the `Containers` section check the `Image` key. If it says `grafana/loki:2.3.0` or higher, please proceed with the next steps. Otherwise, go to [Retention via Table Manager](#retention-via-table-manager).

The `Compactor` is the preferred way because it offers many options and advantages over the `Table Manager`, such as more `fine grained` retention configuration and `multi-cluster` setup support. On the other hand, the `Compactor` method will have `long term support`, so it's best to stick with it. More details and explanations about which one to use over the other is provided in the [Loki Storage Retention](https://grafana.com/docs/loki/latest/operations/storage/retention/#loki-storage-retention) official page.

In this section, main focus is on the `Compactor` implementation, because this is the `preferred` way for `Loki`, as stated above. The basic configuration, and recommended way to start with, looks like below:

```
compactor:
  working_directory: /data/loki/boltdb-shipper-compactor
  shared_store: aws
  compaction_interval: 10m
  retention_enabled: true
  retention_delete_delay: 2h
  retention_delete_worker_count: 150
```

Explanation for the above configuration:

* `retention_enabled` - set to true. Without this, the `Compactor` will only compact tables.
* `working_directory` - the directory where marked chunks and temporary tables will be saved.
* `compaction_interval` - defines how often compaction and/or retention is applied. If the `Compactor` falls behind, compaction and/or retention occur as soon as possible. A `10m` value is recommended to start with, as per official documentation.
* `retention_delete_delay` - the delay after which the compactor will delete marked chunks. A `2h` value is recommended to start with, as per official documentation.
* `retention_delete_worker_count` - specifies the maximum quantity of goroutine workers instantiated to delete chunks. A value of `150` is recommended to start with, as per official documentation.

**Note:**

Retention is only available if the [index period](res/manifests/loki-values.yaml#L34) from `schema_config` is set to `24h`.

The [loki-values.yaml](res/manifests/loki-values.yaml) sample file provided with this tutorial contains sample retention settings for `Compactor`. Edit the `5-setup-loki-stack/res/manifests/loki-values.yaml` file by uncommenting the required section for the [Compactor](res/manifests/loki-values.yaml#L7). Then, apply the changes with:

```
helm upgrade loki grafana/loki-stack --version 2.4.1 \
  --namespace=monitoring \
  --create-namespace \
  -f 5-setup-loki-stack/res/manifests/loki-values.yaml
```

Inspect the `logs` for the main `Loki` application and check if there are no errors:

```shell
  kubectl logs -n monitoring -l app=loki
```

**Hint:**

`S3CMD` is a really good utility to have in order to inspect how many objects are present, as well as the size of the `DO Spaces` bucket. It will also help you to see if the retention policies set so far are working or not. Please follow the `DigitalOcean` guide for installing and setting up [s3cmd](https://docs.digitalocean.com/products/spaces/resources/s3cmd/).

After finishing the above, you can inspect the bucket `size` and `number` of objects via the `du` subcommand (the name is borrowed from the `Linux Disk Usage` utility). Please replace the `<>` placeholders accordingly:

```shell
s3cmd du -H s3://<LOKI_DO_SPACES_BUCKET_NAME>
```

The output looks similar to the following:

```
19M    2799 objects s3://loki-storage-test/
```

After a while, you can run some queries in `Grafana` and see if there are logs older than the specified retention interval. If the above configuration was applied succesfully, there should be only the new data persisted.

For more details, please visit the [Compactor](https://grafana.com/docs/loki/latest/operations/storage/retention/#compactor) implementation page.

#### **Retention via Table Manager**

If the `Loki` application version is `2.2.0` or lower, retention can be achieved by [Table Manager](https://grafana.com/docs/loki/v2.2.0/operations/storage/table-manager).  In order to enable the `retention support`, the `Table Manager` needs to be configured to `enable deletions` and a `retention period`. Please refer to the [table_manager_config](https://grafana.com/docs/loki/v2.2.0/configuration#table_manager_config) section of the Loki configuration reference for all available options.

**WARNING:**

The `retention period` must be a `multiple` of the `index` and `chunks` table period, configured in the `period_config` block. See the [Table Manager](https://grafana.com/docs/loki/v2.2.0/operations/storage/table-manager#retention) documentation for more information.

You can enable the data retention explicitly enabling it in the configuration and setting a `retention_period` greater than zero. Below is a `24h` example configuration (in a production environment you will want more, of course):

```
table_manager:
  retention_deletes_enabled: true
  retention_period: 24h
chunk_store_config:
  max_look_back_period: 24h
```

**Note:**

To avoid querying of data beyond the retention period, `max_look_back_period` config in `chunk_store_config` must be set to a value less than or equal to what is set in `table_manager.retention_period`.

The `Table Manager` implements the retention deleting the entire tables whose data exceeded the `retention_period`. This design allows to have `fast` delete operations, at the cost of having a retention granularity controlled by the table’s period.

Given each table contains data for period of time and that the entire table is deleted, the `Table Manager` keeps the last tables alive using this formula:

```
number_of_tables_to_keep = floor(retention_period / table_period) + 1
```

**Note:**

Due to the internal implementation, the `table period` and `retention_period` must be `multiples` of `24h` in order to get the expected behavior.

The [loki-values.yaml](res/manifests/loki-values.yaml) sample file provided with this tutorial contains sample retention settings for `Table Manager`. Edit the `5-setup-loki-stack/res/manifests/loki-values.yaml` file by uncommenting the required section for the [Table Manager](res/manifests/loki-values.yaml#L18). Then, apply the changes with:

```
helm upgrade loki grafana/loki-stack --version 2.4.1 \
  --namespace=monitoring \
  --create-namespace \
  -f 5-setup-loki-stack/res/manifests/loki-values.yaml
```

Inspect the `logs` for the main `Loki` application and check if there are no errors:

```shell
  kubectl logs -n monitoring -l app=loki
```

After a while, you can run some queries in `Grafana` and see if there are logs older than the specified retention interval. If the above configuration was applied succesfully, there should be only the new data persisted.

**Setting DO Spaces retention policies**

Another important thing to take into consideration is that the `Loki` storage retention settings configured so far, will not apply to the remote storage itself - in this case, `DO Spaces`. It only works at the filesystem level. 

Why? Because `S3` compatible storage has its own set of policies and rules for retention settings. So, it's the `S3 implementation` responsibility to handle objects `lifecycle`. More details can be found in the DO Spaces [bucket lifecycle](https://docs.digitalocean.com/reference/api/spaces-api/#configure-a-buckets-lifecycle-rules) configuration page.

Setting the lifecycle for the Loki storage bucket can be done very easy via `s3cmd` (if you don't have it installed, please follow the [s3cmd](https://docs.digitalocean.com/products/spaces/resources/s3cmd/) installation steps).

Below is a sample configuration for the `fake/` and `index/` paths:

```
<LifecycleConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Rule>
    <ID>Expire old fake data</ID>
    <Prefix>fake/</Prefix>
    <Status>Enabled</Status>
    <Expiration>
      <Days>1</Days>
    </Expiration>
  </Rule>

  <Rule>
    <ID>Expire old index data</ID>
    <Prefix>index/</Prefix>
    <Status>Enabled</Status>
    <Expiration>
      <Days>1</Days>
    </Expiration>
  </Rule>
</LifecycleConfiguration>
```
What the above lifecycle configuration will do, is to `expire` after `1 day` all the objects from the `fake/` and `index/` paths of the `Loki` storage bucket. After the expiration period passed, the objects will be automatically deleted from the bucket.

Steps to follow:

1. Change directory where this repository was cloned.
2. Edit the provided [loki_do_spaces_lifecycle.xml](res/manifests/loki_do_spaces_lifecycle.xml) file and adjust according to your needs.
3. Set the lifecycle policy using the provided file (please replace the `<>` placeholders accordingly):

    ```shell
    s3cmd setlifecycle 5-setup-loki-stack/res/manifests/loki_do_spaces_lifecycle.xml s3://<LOKI_STORAGE_BUCKET_NAME>
    ```
4. Check that the policy was set (please replace the `<>` placeholders accordingly):

    ```shell
    s3cmd getlifecycle s3://<LOKI_STORAGE_BUCKET_NAME>
    ```

After running the last step, `s3cmd` should print the same content as the one set in the policy file.

That's it. `DO Spaces` S3 implementation will take care of the rest and clean the old objects from the bucket automatically. You can always go back end edit the policy if needed later on, by uploading a new one.

**Next steps**

This concludes the `Loki` setup. For more details and in depth explanations please visit the [Loki](https://grafana.com/docs/loki/latest) official documentation page. 

In the next section, you will learn how to perform backups of your system as well as doing restores via `Velero`.

Go to [Section 6 - Backup Using Velero](../6-setup-velero)
