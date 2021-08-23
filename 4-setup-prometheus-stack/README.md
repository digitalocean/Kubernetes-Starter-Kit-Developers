## Prometheus Monitoring Stack

### Installing Prometheus Stack

We will install the `kube-prometheus` stack using `Helm`, which is an opinionated full monitoring stack for `Kubernetes`. It includes the `Prometheus Operator`, `kube-state-metrics`, pre-built manifests, `Node Exporters`, `Metrics API`, the `Alerts Manager` and `Grafana`. 

`Helm` chart: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack

Update the `Helm` repo:

```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

Download the `values.yaml` file:

```bash
curl https://raw.githubusercontent.com/prometheus-community/helm-charts/main/charts/kube-prometheus-stack/values.yaml -o prom-stack-values.yaml
```

Modify the `prom-stack-values.yaml` file to disable metrics for `etcd` and `kubeScheduler` (set their corresponding values to `false`). Those components are managed by `DOKS` and are not accessible to `Prometheus`. Note that we're keeping the `storage` to be `emptyDir`. It means the **storage will be gone** if `Prometheus` pods restart.

Install `kube-prometheus-stack`:

```
helm install kube-prom-stack prometheus-community/kube-prometheus-stack -n monitoring -f prom-stack-values.yaml --create-namespace --wait
```

Now you can connect to `Grafana` (`admin/prom-operator`, see `prom-stack-values.yaml`) by port forwarding to local machine. Once in, you can go to dashboards - manage, and choose different dashboards.  You should NOT expose grafana to public network (eg. create an ingress mapping or LB service) with default login/password.

```
kubectl --namespace monitoring port-forward svc/kube-prom-stack-grafana 3000:80
```

Grafana install comes with a number of dashboards. Review those by going to Grafana -> Dashboards -> Manage.

Please keep the `prom-stack-values.yaml` file because it reflects the current state of the deployment (we need it later on as well).

### Configure Prometheus and Grafana

We already deployed `Prometheus` and `Grafana` into the cluster as explained in the [Prometheus Monitoring Stack](#PROM) chapter.

So, why `Prometheus` in the first place? Because it supports `multidimensional data collection` and `data queuing`, it's reliable and allows customers to quickly diagnose problems. Since each server is independent, it can be leaned on when other infrastructure is damaged, without requiring additional infrastructure. It also integrates very well with the `Kubernetes` model and way of working and that's a big plus as well.

`Prometheus` follows a `pull` model when it comes to metrics gathering meaning that it expects a `/metrics` endpoint to be exposed by the service in question for scraping. 

In the next steps you'll configure `Prometheus` to monitor the `AES` stack. You'll configure `Grafana` as well to visualise metrics.

In the end, this is how the setup will look like (`AES` + `Prometheus` + `Grafana`):

![AES with Prometheus & Grafana](../images/arch_aes_prometheus_grafana.jpg)

Luckily for us the `Ambassador Edge Stack` deployment created earlier in the tutorial provides the `/metrics` endpoint by default on port `8877` via a `Kubernetes` service.

The service in question is called `ambassador-admin` from the `ambassador` namespace as seen below:

```bash
kubectl get svc -n ambassador
```

The output looks similar to the following:

```
NAME               TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)                      AGE
ambassador         LoadBalancer   10.245.39.13   68.183.252.190   80:31499/TCP,443:30759/TCP   3d3h
ambassador-admin   ClusterIP      10.245.68.14   <none>           8877/TCP,8005/TCP            3d3h
ambassador-redis   ClusterIP      10.245.9.81    <none>           6379/TCP                     3d3h
```

Then it's just a matter of invoking the `port-forward` subcommand of `kubectl` for the corresponding `Kubernetes Service`:

```bash
kubectl port-forward svc/ambassador-admin 8877:8877 -n ambassador
```

The exposed metrics can be fetched using the web browser on [localhost](http://localhost:8877/metrics) or via a simple `curl` command like this:

```
curl -s http://localhost:8877/metrics
```

The output looks similar to the following:

```
# TYPE envoy_cluster_assignment_stale counter
envoy_cluster_assignment_stale{envoy_cluster_name="cluster_127_0_0_1_8500_ambassador"} 0
envoy_cluster_assignment_stale{envoy_cluster_name="cluster_127_0_0_1_8877_ambassador"} 0
envoy_cluster_assignment_stale{envoy_cluster_name="cluster_echo_backend_ambassador"} 0
envoy_cluster_assignment_stale{envoy_cluster_name="cluster_extauth_127_0_0_1_8500_ambassador"} 0
envoy_cluster_assignment_stale{envoy_cluster_name="cluster_quote_backend_ambassador"} 0
envoy_cluster_assignment_stale{envoy_cluster_name="cluster_quote_default_default"} 0
envoy_cluster_assignment_stale{envoy_cluster_name="xds_cluster"} 0
```

Great! But how do we tell `Prometheus` about this new target? There are several ways of achieving this:
* [<static_config>](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#static_config) - allows specifying a list of targets and a common label set for them.
* [<kubernetes_sd_config>](https://prometheus.io/docs/prometheus/latest/configuration/configuration/#kubernetes_sd_config) - allows retrieving scrape targets from `Kubernetes' REST API` and always staying synchronized with the cluster state.
* [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator) - simplifies `Prometheus` monitoring inside a `Kubernetes` cluster via `CRDs`.

As we can see there are many ways to tell `Prometheus` to scrape an endpoint, so which one should you pick? Because we're on the Kubernetes side, the best way is to **"speak its language"**, right? This means that we should always pick an option that fits best with the toolset. So which one is a perfect match if not a `Kubernetes Operator` ?
Good news is that we already have access to the `Prometheus Operator` because it comes bundled into the [Prometheus Monitoring Stack](#PROM) configured earlier. So we're going to focus on it in the next steps and see how easy it is to add a new scraping endpoint for `Prometheus` to use. On top of that, managing the [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) via `Helm` simplifies things even more.
A really cool feature of `Prometheus Operator` is the `ServiceMonitor` CRD which lets us define a new target for monitoring.

Let's configure it right now and see how it works. We're going to use the *prom-stack-values.yaml* file downloaded in the [Prometheus Monitoring Stack](#PROM) section. Open it using a text editor of your choice (it's recommended to have one that has `YAML` linting support).

There are only two steps needed in order to add a new service for monitoring:

1. Add a new `ServiceMonitor` in the `additionalServiceMonitors` section. Make sure to adjust the YAML indentation, and remove the replace additionalServiceMonitors: [] section, which is blank.
    ```
    additionalServiceMonitors:
      - name: "ambassador-monitor"
        selector:
          matchLabels:
            service: "ambassador-admin"
        namespaceSelector:
          matchNames:
            - ambassador
        endpoints:
        - port: "ambassador-admin"
          path: /metrics
          scheme: http
    ```

    Important configuration elements to be highlighted here:

    * `matchLabel` - tells what pods the deployment will apply to.
    * `selector` - specifies the resource to match (service, deployment, etc), according to the label key-pair from the `matchLabels` key.
    * `port` - can be a literal port `number` as defined in the `ambassador-metrics` service or a reference to the port `name`. 
    * `namespaceSelector` - here we want to match the namespace of the `Ambassador Metrics Service` we have just created via the `matchNames` key.
2. Apply the changes via `Helm`:
   
    ```bash
    helm upgrade kube-prom-stack prometheus-community/kube-prometheus-stack -n monitoring -f prom-stack-values.yaml
    ```
      **Important note:**

      If the `Helm` upgrade process fails, then there's either a mistake in the `prom-stack-values.yaml` file or the `kube-prometheus-stack` chart was updated. This happens when using `helm repo update`. `Helm` will always use the latest chart available if no version is specified. Things may break because some `Helm` chart versions are **not backwards compatible**.

      In order to fix this we have to find what version was deployed via:

      ```bash
      helm ls -n monitoring
      ```

      The output looks similar to the following:

      ```
      NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                           APP VERSION
      kube-prom-stack monitoring      2               2021-08-14 00:08:16.520902 +0300 EEST   deployed        kube-prometheus-stack-17.1.3    0.49.0 
      ```

      Looking at the `CHART` column we can see that the deployed version is `17.1.3` in this case, so we add the `--version` flag to the `upgrade` command:

      ```bash
      helm upgrade kube-prom-stack prometheus-community/kube-prometheus-stack -n monitoring --version 17.1.3 -f prom-stack-values.yaml
      ```

### Seeing the Results

That's it! We can inspect now the `Ambassador` target that was added to `Prometheus` for scraping. But first, let's do a `port-forward` so that we can see it the web interface:

```bash
kubectl port-forward svc/kube-prom-stack-kube-prome-prometheus 9090:9090 -n monitoring
```

Navigating to the `Status -> Targets` page should give the following result (notice the `serviceMonitor/monitoring/ambassador-monitor/0` path):

![Ambassador Prometheus Target](../images/prom_amb_target.png)

**Note:**

There are **3 entries** under the discovered target because the `AES` deployment consists of 3 `Pods`. Verify it via:

```bash
kubectl get deployments -n ambassador
```

The output looks similar to the following (notice the `ambassador` line):

```
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
ambassador         3/3     3            3           3d3h
ambassador-agent   1/1     1            1           3d3h
ambassador-redis   1/1     1            1           3d3h
```

### PromQL (Prometheus Query Language)

Another powerful feature of `Prometheus` that is worth mentioning is `PromQL` or the `Prometheus Query Language`. In this section we'll cover just some basics and a practical example later on. For more in depth explanations and features, please visit the official [PromQL](https://prometheus.io/docs/prometheus/latest/querying/basics/) page.

What is `PromQL` in the first place? It's a `DSL` or `Domain Specific Language` that is specifically built for `Prometheus` and allows us to query for metrics. Because it’s a `DSL` built upon `Go`, you’ll find that `PromQL` has a lot in common with the language. But it’s also a `NFL` or `Nested Functional Language`, where data appears as nested expressions within larger expressions. The outermost, or overall, expression defines the final value, while nested expressions represent values for arguments and operands.

Let's move to a practical example now. We're going to inspect one of the `Ambassador Edge Static` exposed metrics, namely the `ambassador_edge_stack_promhttp_metric_handler_requests_total`, which represents the total of `HTTP` requests `Prometheus` performed for the `AES` metrics endpoint.

Steps:

1. Get access to the `Prometheus` web interface:

    ```
    kubectl port-forward svc/kube-prom-stack-kube-prome-prometheus 9090:9090 -n monitoring
    ```
2. Open the [expression browser](http://localhost:9090/graph).
3. In the query input field paste `ambassador_edge_stack_promhttp_metric_handler_requests_total` and hit `Enter`. The ouput looks similar to the following:

    ```
    ambassador_edge_stack_promhttp_metric_handler_requests_total{code="200", container="ambassador", endpoint="ambassador-admin", instance="10.244.0.196:8877", job="ambassador-admin", namespace="ambassador", pod="ambassador-bcb5b8d67-k6q4v", service="ambassador-admin"} 21829
    ambassador_edge_stack_promhttp_metric_handler_requests_total{code="200", container="ambassador", endpoint="ambassador-admin", instance="10.244.0.228:8877", job="ambassador-admin", namespace="ambassador", pod="ambassador-bcb5b8d67-8v9nn", service="ambassador-admin"} 21829
    ambassador_edge_stack_promhttp_metric_handler_requests_total{code="200", container="ambassador", endpoint="ambassador-admin", instance="10.244.0.32:8877", job="ambassador-admin", namespace="ambassador", pod="ambassador-bcb5b8d67-rlqwm", service="ambassador-admin"}  21832
    ambassador_edge_stack_promhttp_metric_handler_requests_total{code="500", container="ambassador", endpoint="ambassador-admin", instance="10.244.0.196:8877", job="ambassador-admin", namespace="ambassador", pod="ambassador-bcb5b8d67-k6q4v", service="ambassador-admin"} 0
    ambassador_edge_stack_promhttp_metric_handler_requests_total{code="500", container="ambassador", endpoint="ambassador-admin", instance="10.244.0.228:8877", job="ambassador-admin", namespace="ambassador", pod="ambassador-bcb5b8d67-8v9nn", service="ambassador-admin"} 0
    ambassador_edge_stack_promhttp_metric_handler_requests_total{code="500", container="ambassador", endpoint="ambassador-admin", instance="10.244.0.32:8877", job="ambassador-admin", namespace="ambassador", pod="ambassador-bcb5b8d67-rlqwm", service="ambassador-admin"}  0
    ambassador_edge_stack_promhttp_metric_handler_requests_total{code="503", container="ambassador", endpoint="ambassador-admin", instance="10.244.0.196:8877", job="ambassador-admin", namespace="ambassador", pod="ambassador-bcb5b8d67-k6q4v", service="ambassador-admin"} 0
    ambassador_edge_stack_promhttp_metric_handler_requests_total{code="503", container="ambassador", endpoint="ambassador-admin", instance="10.244.0.228:8877", job="ambassador-admin", namespace="ambassador", pod="ambassador-bcb5b8d67-8v9nn", service="ambassador-admin"} 0
    ambassador_edge_stack_promhttp_metric_handler_requests_total{code="503", container="ambassador", endpoint="ambassador-admin", instance="10.244.0.32:8877", job="ambassador-admin", namespace="ambassador", pod="ambassador-bcb5b8d67-rlqwm", service="ambassador-admin"}  0
    ```
4. `PromQL` groups similar data in what's called a `vector`. As seen above, each `vector` has a set of `attributes` which differentiates it from one another. What we can do then is to group results based on an attribute of interest. For example, if we care only about `HTTP` requests that ended with a `200` response code then it's just a matter of writing this in the query field:

    ```
    ambassador_edge_stack_promhttp_metric_handler_requests_total{code="200"}
    ```

  The output looks similar to the following (note that it selects only the results that match our criteria):
  ```
  ambassador_edge_stack_promhttp_metric_handler_requests_total{code="200", container="ambassador", endpoint="ambassador-admin", instance="10.244.0.196:8877", job="ambassador-admin", namespace="ambassador", pod="ambassador-bcb5b8d67-k6q4v", service="ambassador-admin"} 21843
  ambassador_edge_stack_promhttp_metric_handler_requests_total{code="200", container="ambassador", endpoint="ambassador-admin", instance="10.244.0.228:8877", job="ambassador-admin", namespace="ambassador", pod="ambassador-bcb5b8d67-8v9nn", service="ambassador-admin"} 21843
  ambassador_edge_stack_promhttp_metric_handler_requests_total{code="200", container="ambassador", endpoint="ambassador-admin", instance="10.244.0.32:8877", job="ambassador-admin", namespace="ambassador", pod="ambassador-bcb5b8d67-rlqwm", service="ambassador-admin"}  21845
  ```

 **Note:**

  The above result shows the total requests for each `Pod` from the `AES` deployment (which consists of `3` as seen in the `kubectl get deployments -n ambassador` command output). Each `Pod` exposes the same `/metrics` endpoint and the `Kubernetes` service makes sure that the requests are distributed to each `Pod`. Numbers at the end of each line represent the total `HTTP` requests, so we can see that is roughly the same: `21843`, `21843`, `21845`. This demonstrates the `Round Robin` method being used by the service.

This is just a very simple introduction to what `PromQL` is and what it's capable of. But it can do much more than that, like: counting metrics, computing the rate over a predefined interval, etc. Please visit the official [PromQL](https://prometheus.io/docs/prometheus/latest/querying/basics/) page for more features of the language.

### Grafana

Although `Prometheus` has some support for visualising data built in, a better way of doing it is via `Grafana` which is an open-source platform for monitoring and observability that lets you visualize and explore the state of your systems.

On the official page is described as being able to:

> Query, visualize, alert on, and understand your data no matter where it’s stored.

Why use `Grafana`? Because it's the leading open source monitoring and analytics platform available nowadays for visualising data coming from a vast number of data sources, including `Prometheus` as well. It offers some advanced features for organising the graphs and it supports real time testing for queries. Not to mention that you can customize the views and make some beautiful panels which can be rendered on big screens so you never miss a single data point.

No extra steps are needed for installation because the [Prometheus Monitoring Stack](#PROM) deployed earlier did it already for us. All we have to do is a port forwarding like below and get immediate access to the dashboards (default credentials: `admin/prom-monitor`):

```
kubectl --namespace monitoring port-forward svc/kube-prom-stack-grafana 3000:80
```

In order to see all the `Ambassador Edge Stack` metrics, we're going to add this well-designed [dashboard](https://grafana.com/grafana/dashboards/4698) from the `Grafana` community.

Creating the above dashboard is easy:
1. Navigate to the [dashboard import](http://localhost:3000/dashboard/import) section (or hover the mouse on the `+` sign from the left pane, then click `Import`).
2. In the `Import via grafana.com` section just paste the ID: `4698`, then click `Load`.
3. The final step would be to select a data source - `Prometheus` in this case, then hit the `Import` button.

The picture down below shows the available options:

![Grafana Ambassador Setup](../images/grafana_amb_setup.png)

Fields description:
* `Name` - the dashboard name (defaults to `Ambassador`).
* `Folder` - the folder name where to store this dashboard (defaults to `General`).
* `Prometheus` - the `Prometheus` instance to use (we have only one in this example).
* `Listener port` - the `Envoy listener port` (defaults to `8080`).

After clicking `Import`, it will create the following dashboard as seen below:

![Grafana Ambassador Dashboard](../images/amb_grafana_dashboard.jpg)

In the next part we want to monitor the number of `API` calls for our `quote` backend service created earlier in the [Ambassador Edge Stack - Backend Services](#AMBA_BK_SVC) section. The graph of interest is: `API Response Codes`.

If you call the service 2 times, you will see 4 responses being plotted. This is normal behavior because the `API Gateway` (from the `Ambassador Edge Stack`) is hit first and then the real service. Same thing happens when a reply is being sent back so we have a total of: `2 + 2 = 4` responses being plotted in the `API Response Codes` graph as seen in the above picture.

`CLI` command used for testing the above scenario:

```bash
curl -Lk https://quote.mandrakee.xyz/quote/
```

The output looks similar to the following:
```
{
    "server": "buoyant-pear-girnlk37",
    "quote": "A small mercy is nothing at all?",
    "time": "2021-08-11T18:18:56.654108372Z"
}
```
This concludes the `Grafana` setup. You can play around and add more panels for visualising other data sources, as well as group them together based on scope.

Go to [Section 5 - Loki setup](../5-setup-loki-stack)
