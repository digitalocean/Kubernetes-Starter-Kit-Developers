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

Why `S3`? Because it `scales` very well and it's `cheaper` than `PVs`, which rely on `Block Storage`. On the other hand, you don't have to worry anymore about running out of `disk space`, as it happens when relying on the `PV` implementation. More than that, you don't have to worry about `PV` sizing and doing the extra math.
In terms of performance, `S3` is not that good compared to `Block Storage`, but it doesn't matter very much in this case when doing queries, because `Loki` does a good job in general.

In terms of storage details, the setup used in this tutorial is relying on the default implementation, namely the [BoltDB Shipper](https://grafana.com/docs/loki/latest/operations/storage/boltdb-shipper/) for logs retention. This is the `preferred` and recommended way for `Loki`. In the next steps you're going to set `BoltDB` to use a remote storage instead - `DO Spaces`, to persist the data.

**Setting persistent storage via DO Spaces**

Below is an example for using remote storage via `DO Spaces`:

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

* `schema_config` - defines a storage `type` and a schema `version`, which is required when doing migrations (schemas can `differ` between `Loki` installations, so `consistency` is they key here). In this case, `BoltDB Shipper` is specified as the storage implementation and a `v11` schema version. The `24h` period for the index is the default and preferred value, so please don't change it. Please visit [Schema Configs](https://grafana.com/docs/loki/latest/storage/#schema-configs) for more details.
* `storage_config` - tells `Loki` about `storage configuration` details, like setting `BoltDB Shipper` parameters. It also informs `Loki` about the `aws` compatible `S3` storage parameters (`bucket` name, `credentials`, `region`, etc).

In the next part, you're going to tell `Helm` how to configure `Loki` to access the `DO Spaces` storage, as well as setting the correct `schema`.

Steps to follow:

1. Change directory to where this repository was cloned.
2. Open the [loki-values.yaml](res/manifests/loki-values.yaml#L7) sample file provided with this `Git` repository, using a text editor of your choice and preferrably with `YAML` linting support.
3. Uncomment the corresponding sections for `schema_config` and `storage_config`. Also, make sure to replace the `<>` placeholders accordingly in the `aws` subsection.
4. Upgrade the `Loki` stack to use the new storage settings via `Helm`:

    ```shell
      helm upgrade loki grafana/loki-stack --version 2.4.1 \
        --namespace=monitoring \
        --create-namespace \
        -f 5-setup-loki-stack/res/manifests/loki-values.yaml
      ```
5. Check that the main `Loki` application pod is up and running (it may take up to `1 minute` or so to start, so please be patient):

    ```shell
    kubectl get pods -n monitoring -l app=loki
    ```
    The output looks similar to:

    ```
    NAME     READY   STATUS    RESTARTS   AGE
    loki-0   1/1     Running   0          13m
    ```

    **Hints:**

    The main application `Pod` is called `loki-0`. You can check the configuration file using the following command (before displaying it, please note that it contains `sensitive` information):

    ```shell
    kubectl exec -it loki-0 -n monitoring -- /bin/cat /etc/loki/loki.yaml
    ```

    You can also check the logs while waiting. It's also good practice in general to check the application logs to see if something goes bad or not.

    ```shell
    kubectl logs -n monitoring -l app=loki
    ```

If everything goes well, you should see the `DO Spaces` bucket containing the `index` and `chunks` folders (the `chunks` folder is called `fake`, which is a strange name, but this is by design when not running in `multi-tenant` mode).

![Loki DO Spaces Storage](res/img/loki_storage_do_spaces.png)

For more advanced options and fine tuning the `storage` for `Loki`, please visit the [Loki Storage](https://grafana.com/docs/loki/latest/operations/storage/) documentation page.

**Setting Loki storage retention**

`Retention` is a very important aspect as well when it comes to storage setup, because `storage is finite`. While `S3` storage is not expensive and is somewhat `infinte` (it makes you think like that), it is good practice to have a retention policy set.

Retention options available for `Loki` rely on either the [Table Manager](https://grafana.com/docs/loki/latest/operations/storage/retention/#table-manager) or the [Compactor](https://grafana.com/docs/loki/latest/operations/storage/retention/#Compactor). Please visit the official page for more details about the implementation.

The default `Loki` installation from this tutorial relies on the `Table Manager`, which works very well with `S3` storage. Although `S3` is very scalable and you don't have to worry about `disk space` issues, it's `OK` to have a `retention policy` in place. This way, really old data can be deleted if not needed.

`S3` compatible storage has its own set of policies and rules for retention settings. In the `S3` terminology, it is called `object lifecycle`. More details can be found on the DO Spaces [bucket lifecycle](https://docs.digitalocean.com/reference/api/spaces-api/#configure-a-buckets-lifecycle-rules) page.

**Hint:**

`S3CMD` is a really good utility to have in order to inspect how many objects are present, as well as the size of the `DO Spaces` bucket. It will also help you to see if the retention policies set so far are working or not. Please follow the `DigitalOcean` guide for installing and setting up [s3cmd](https://docs.digitalocean.com/products/spaces/resources/s3cmd/).

Setting the lifecycle for the Loki storage bucket can be done very easy via `s3cmd`. Below is a sample configuration for the `fake/` and `index/` paths:

```
<LifecycleConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Rule>
    <ID>Expire old fake data</ID>
    <Prefix>fake/</Prefix>
    <Status>Enabled</Status>
    <Expiration>
      <Days>10</Days>
    </Expiration>
  </Rule>

  <Rule>
    <ID>Expire old index data</ID>
    <Prefix>index/</Prefix>
    <Status>Enabled</Status>
    <Expiration>
      <Days>10</Days>
    </Expiration>
  </Rule>
</LifecycleConfiguration>
```
What the above `lifecycle` configuration will do, is to automatically `delete` after `10 days` all the objects from the `fake/` and `index/` paths from the `Loki` storage bucket.

How to configure a `S3` bucket lifecycle:

1. Change directory where this repository was cloned.
2. Edit the provided [loki_do_spaces_lifecycle.xml](res/manifests/loki_do_spaces_lifecycle.xml) file and adjust according to your needs.
3. Set the `lifecycle` policy using the provided file (please replace the `<>` placeholders accordingly):

    ```shell
    s3cmd setlifecycle 5-setup-loki-stack/res/manifests/loki_do_spaces_lifecycle.xml s3://<LOKI_STORAGE_BUCKET_NAME>
    ```
4. Check that the `policy` was set (please replace the `<>` placeholders accordingly):

    ```shell
    s3cmd getlifecycle s3://<LOKI_STORAGE_BUCKET_NAME>
    ```

After finishing the above steps, you can `inspect` the bucket `size` and `number` of objects via the `du` subcommand (the name is borrowed from the `Linux Disk Usage` utility). Please replace the `<>` placeholders accordingly:

```shell
s3cmd du -H s3://<LOKI_DO_SPACES_BUCKET_NAME>
```

The output looks similar to the following:

```
19M    2799 objects s3://loki-storage-test/
```

That's it. `DO Spaces` S3 implementation will take care of the rest, and `clean` the `old` objects from the bucket `automatically`. You can always go back end edit the policy if needed later on, by uploading a new one.

**Next steps**

This concludes the `Loki` setup. For more details and in depth explanations please visit the [Loki](https://grafana.com/docs/loki/latest) official documentation page. 

In the next section, you will learn how to perform backups of your system as well as doing restores via `Velero`.

Go to [Section 6 - Backup Using Velero](../6-setup-velero)
