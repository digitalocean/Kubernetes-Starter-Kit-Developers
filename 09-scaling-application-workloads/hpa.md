# Scaling Applications using the HorizontalPodAutoscaler

## Introduction

In a real world scenario you want to have resiliency for your applications. On the other hand, you want to be more efficient on resources and cut down costs as well. You need something that can scale your application on demand.

Most of the time you used application `Deployments` with a fixed `ReplicaSet` number. But, in production environments which are variably put under load by external users, it is not always that simple. It is inefficient to just go ahead and change some static values every time your web application deployments are put under load and start to misbehave, based on a specific period of the day, holidays or other special events, when many users come and visit your shopping site. Then, when the crowded period is over, you must go back and scale down your web deployments to avoid waste of resources, and reduce infrastructure costs.

This is were [Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale) kicks in, and provides a solution for more efficient resource usage, as well as reducing costs. It is a closed loop system that automatically grows or shrinks resources (application Pods), based on current needs. You create a `HorizontalPodAutoscaler` (or `HPA`) resource for each application deployment that needs autoscaling, and let it take care of the rest for you automatically.

Horizontal pod scaling deals with adjusting replicas for application Pods, whereas vertical pod scaling deals with resource requests and limits for containers within Pods.

### How Horizontal Pod Autoscaling Works

At a high level, each `HPA` does the following:

1. Keeps an eye on resource requests metrics coming from your application workloads (Pods), by querying the metrics server.
2. Compares the target threshold value that you set in the HPA definition with the average resource utilization observed on your application  workloads (CPU and memory).
3. If the target threshold is reached, then HPA will scale up your application deployment to meet higher demands. Otherwise, if below the threshold, it will scale down the deployment. To see how HPA computes the final replica count, you can visit the [algorithm details](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#algorithm-details) page from the official documentation.

Under the hood, `HorizontalPodAutoscaler` is just another CRD (`Custom Resource Definition`) which drives a Kubernetes control loop implemented via a dedicated controller within the `Control Plane` of your cluster. Basically, you define a `HorizontalPodAutoscaler` YAML manifest targeting your application `Deployment`, and have the resource created in your cluster as usual, via `kubectl`. **Please bear in mind that you cannot target objects that cannot be scaled, such as a `DaemonSet` for example.**

In order to do its magic, HPA needs a metrics server available in your cluster to observe required metrics, such as average CPU and memory utilization. One popular option is the [Kubernetes Metrics Server](https://github.com/kubernetes-sigs/metrics-server). **Please bear in mind that the `Kubernetes Metrics Server` was created to provide CPU and memory utilization metrics only.**

For custom metrics (anything else than CPU and memory), you can use [Prometheus](https://prometheus.io) via a special adapter, named [prometheus-adapter](https://github.com/kubernetes-sigs/prometheus-adapter). This works because Kubernetes offers support for [custom metrics](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#scaling-on-custom-metrics) via the `custom.metrics.k8s.io` API specification.

In a nutshell, the `Kubernetes Metrics Server` works by collecting `resource metrics` from `Kubelets` and exposing them via the `Kubernetes API Server` to be consumed by `Horizontal Pod Autoscaler`. Metrics API can also be accessed by `kubectl top`, making it easier to debug autoscaling pipelines.

Please make sure to read and understand metrics server main purpose, by visiting the [Use Cases](https://github.com/kubernetes-sigs/metrics-server#use-cases) section from the main documentation (this is important as well).

This tutorial will show you how to:

- Deploy `Kubernetes Metrics Server` to your `DOKS` cluster for the `Horizontal Pod Autoscaler` to work.
- Create a `HPA`, targeting a sample `application deployment`.
- Test the HPA setup, by inducing `load` on the sample `application pods`.

For more in depth explanations, please visit the official documentation page for the [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale).

### Metrics Server and HPA Overview Diagram

Below diagram shows a high level overview of how HPA works in conjunction with metrics-server:

![K8S Metrics Server and HPA Overview](assets/images/arch_metrics_server_hpa.png)

## Table of Contents

- [Introduction](#introduction)
  - [How Horizontal Pod Autoscaling Works](#how-horizontal-pod-autoscaling-works)
  - [Metrics Server and HPA Overview Diagram](#metrics-server-and-hpa-overview-diagram)
- [Prerequisites](#prerequisites)
- [Step 1 - Installing the Kubernetes Metrics Server](#step-1---installing-the-kubernetes-metrics-server)
- [Step 2 - Getting to Know HPAs](#step-2---getting-to-know-hpas)
- [Step 3 - Creating and Testing HPAs](#step-3---creating-and-testing-hpas)
  - [Scenario 1 - Constant Load Test](#scenario-1---constant-load-test)
  - [Scenario 2 - Variable Load Test](#scenario-2---variable-load-test)
- [Scaling Applications using Custom Metrics](#scaling-applications-using-custom-metrics)
- [Conclusion](#conclusion)

## Prerequisites

To complete this tutorial, you will need:

1. A [Git](https://git-scm.com/downloads) client, to clone the `Starter Kit` repository.
2. [Helm](https://www.helm.sh), for managing `Kubernetes Metrics Server` releases and upgrades.
3. [Kubectl](https://kubernetes.io/docs/tasks/tools), for `Kubernetes` interaction. Kubectl must be configured and ready to use. Please, follow these [instructions](https://www.digitalocean.com/docs/kubernetes/how-to/connect-to-cluster/) to connect to your cluster with `kubectl`.

In the next step, you will learn how to deploy the `Kubernetes Metrics Server`, using the `Helm` package manager.

## Step 1 - Installing the Kubernetes Metrics Server

Kubernetes metrics server can be installed in two ways:

1. Via a single `kubectl` command, in high availability mode (which is recommended): `kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/high-availability.yaml`
2. Via `Helm`, by deploying [metrics-server](https://artifacthub.io/packages/helm/metrics-server/metrics-server) chart to your cluster.

This tutorial (as all tutorials from the Starter Kit) is using the `Helm` installation method, because it's more flexible and you can fine tune the release parameters later on if needed. High availability is a must, and can be set easily via the `replica` field from the `metrics-server` Helm chart.

Please bear in mind that the metrics server deployment requires some special permissions. For more information about all prerequisites, please read the official [requirements](https://github.com/kubernetes-sigs/metrics-server#requirements) page.

Steps to deploy metrics server via Helm:

1. First, clone the `Starter Kit` repository and change directory to your local copy.

    ```shell
    git clone https://github.com/digitalocean/Kubernetes-Starter-Kit-Developers.git

    cd Kubernetes-Starter-Kit-Developers
    ```

2. Next, add the `Helm` repo, and list the available `charts`:

    ```shell
    helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server

    helm repo update metrics-server

    helm search repo metrics-server
    ```

    The output looks similar to the following:

    ```text
    NAME                            CHART VERSION   APP VERSION     DESCRIPTION                                       
    metrics-server/metrics-server   3.8.2           0.6.1           Metrics Server is a scalable, efficient source ...
    ```

    **Note:**

    The chart of interest is `metrics-server/metrics-server`, which will install Kubernetes metrics server on the cluster. Please visit the [metrics-server](https://github.com/kubernetes-sigs/metrics-server/tree/master/charts/metrics-server) chart page, for more details.
3. Then, open and inspect the metrics-server Helm values file provided in the `Starter Kit` repository, using an editor of your choice (preferably with `YAML` lint support). For example, you can use [VS Code](https://code.visualstudio.com):

    ```shell
    code 09-scaling-application-workloads/assets/manifests/metrics-server-values-v3.8.2.yaml
    ```

4. Finally, install the `Kubernetes Metrics Server` using `Helm` (a dedicated `metrics-server` namespace will be created as well):

    ```shell
    HELM_CHART_VERSION="3.8.2"

    helm install metrics-server metrics-server/metrics-server --version "$HELM_CHART_VERSION" \
      --namespace metrics-server \
      --create-namespace \
      -f "09-scaling-application-workloads/assets/manifests/metrics-server-values-v${HELM_CHART_VERSION}.yaml"
    ```

    **Note:**

    A `specific` version for the metrics-server `Helm` chart is used. In this case `3.8.2` was picked, which maps to the `0.6.1` release of metrics-server (see the output from `Step 2.`). It’s good practice in general, to lock on a specific version. This helps to have predictable results, and allows versioning control via `Git`.

**Observations and results:**

You can verify `metrics-server` deployment status via:

```shell
helm ls -n metrics-server
```

The output looks similar to (notice that the `STATUS` column value is `deployed`):

```text
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
metrics-server  metrics-server  1               2022-02-24 14:58:23.785875 +0200 EET    deployed        metrics-server-3.8.2    0.6.1
```

Next check the Kubernetes resources status from the `metrics-server` namespace (notice the `deployment` and `replicaset` resources which should be healthy, and counting as 2):

```shell
kubectl get all -n metrics-server
```

The output looks similar to:

```text
NAME                                  READY   STATUS    RESTARTS   AGE
pod/metrics-server-694d47d564-9sp5h   1/1     Running   0          8m54s
pod/metrics-server-694d47d564-cc4m2   1/1     Running   0          8m54s

NAME                     TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/metrics-server   ClusterIP   10.245.92.63   <none>        443/TCP   8m54s

NAME                             READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/metrics-server   2/2     2            2           8m55s

NAME                                        DESIRED   CURRENT   READY   AGE
replicaset.apps/metrics-server-694d47d564   2         2         2       8m55s
```

Finally, check if the `kubectl top` subcommand works (displays `resource usage`, such as `CPU/Memory`). Below command will display current `resource usage` for all `Pods` in the `kube-system` namespace:

```shell
kubectl top pods -n kube-system
```

The output looks similar to (notice `CPU` measures expressed in `millicores`, as well as for `memory` in `Mebibytes`):

```text
NAME                               CPU(cores)   MEMORY(bytes)   
cilium-operator-5db58f5b89-7kptj   2m           35Mi            
cilium-r2n9t                       4m           150Mi           
cilium-xlqkp                       9m           180Mi           
coredns-85d9ccbb46-7xnkg           1m           21Mi            
coredns-85d9ccbb46-gxg6d           1m           20Mi            
csi-do-node-p6lq4                  1m           19Mi            
csi-do-node-rxd6m                  1m           21Mi            
do-node-agent-2z2bc                0m           15Mi            
do-node-agent-ppds8                0m           21Mi            
kube-proxy-l9ddv                   1m           25Mi            
kube-proxy-t6c29                   1m           30Mi            
```

If the output looks like above, then you configured metrics server correctly. In the next step, you will learn how to configure `HorizontalPodAutoscaling` resources for your application deployment.

## Step 2 - Getting to Know HPAs

By far the most used type of application `Deployment` is the one using a static or a fixed value for the `ReplicaSet` field. This may suffice for some simple deployments, or development environments. In this step you will learn how to automatically scale up or down your application based on current needs.

In a HPA based setup you let the `HorizontalPodAutoscaler` take control over the deployment replica count field. Typical HPA CRD manifest looks like below:

```yaml
apiVersion: autoscaling/v2beta2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app-deployment
  minReplicas: 1
  maxReplicas: 3
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
```

Explanations for the above configuration:

- `spec.scaleTargetRef`: Reference to scaled resource.
- `spec.minReplicas`: The lower limit for the number of replicas to which the autoscaler can scale down.
- `spec.maxReplicas`: The upper limit for the number of pods that can be set by the autoscaler.
- `spec.metrics.type`: Type of metric to use to calculate the desired replica count. Above example is using `Resource` type, which tells the autoscaler to `scale` the deployment based on `CPU` (or memory) average utilization (`averageUtilization` is set to a threshold value of `50`).

Next, you have two options to create a HPA for your deployment:

1. Use the `kubectl autoscale` subcommand on an existing deployment.
2. Create a HPA YAML manifest, targeting your deployment. Then, use `kubectl` as usual to apply the changes.

First option is for performing quick tests because you don't want to mess with YAML stuff yet. Assuming that an application deployment already exists, and it's called `my-python-app`. Below command will create a `HorizontalPodAutoscaler` resource, targeting your `my-python-app` deployment (`default` namespace is assumed):

```shell
kubectl autoscale deployment my-python-app --cpu-percent=50 --min=1 --max=3
```

Above action translates to: please create a HPA resource for me, to automatically scale my `my-python-app` deployment to a maximum of 3 replicas (and no less than 1 replica), whenever average cpu utilization hits 50% (based on resource requests metric). You can check if the HPA resource was created by running (`default` namespace is assumed):

```shell
kubectl get hpa
```

The output looks similar to (the `TARGETS` column shows a value of `50%` which is the average CPU utilization that the HPA needs to maintain, whereas `255%` is the current usage):

```text
NAME            REFERENCE                  TARGETS    MINPODS   MAXPODS   REPLICAS   AGE
my-python-app   Deployment/my-python-app   255%/50%   1         3         3          52s
```

**Note:**

The `TARGETS` column value may show `<unknown>/50%` for a while (around quarter a minute or so). This is normal, and it has to do with HPA fetching the specific metric, and computing the average value over time. By default, HPA checks metrics every 15 seconds.

You can also observe the events a HPA generates under the hood, via:

```shell
kubectl describe hpa my-python-app
```

The output looks similar to (notice in the `Events` list how the HPA is increasing the `replica count` automatically):

```text
Name:                                                  my-python-app
Namespace:                                             default
Labels:                                                <none>
Annotations:                                           <none>
CreationTimestamp:                                     Mon, 28 Feb 2022 10:10:50 +0200
Reference:                                             Deployment/my-python-app
Metrics:                                               ( current / target )
  resource cpu on pods  (as a percentage of request):  250% (50m) / 50%
Min replicas:                                          1
Max replicas:                                          3
Deployment pods:                                       3 current / 3 desired
...
Events:
  Type    Reason             Age   From                       Message
  ----    ------             ----  ----                       -------
  Normal  SuccessfulRescale  17s   horizontal-pod-autoscaler  New size: 2; reason: cpu resource utilization (percentage of request) above target
  Normal  SuccessfulRescale  37s   horizontal-pod-autoscaler  New size: 3; reason: cpu resource utilization (percentage of request) above target
```

In a real world scenario, you will want to use a dedicated YAML manifest to define each HPA. This way, you can track the changes by having the manifest committed in a Git repository for example, and come back to it later easily to perform changes.

Next, you're going to discover and test HPAs, by looking at two different scenarios: one where constant load is present, and the other one where variable load is created for the application under test.

## Step 3 - Creating and Testing HPAs

Following HPA experiments are based on two real world scenarios (more or less):

1. An application deployment that puts a constant load on the CPU (using some intensive computations).
2. A web application that creates variable load, by increasing/decreasing the number of HTTP requests in a short time.

### Scenario 1 - Constant Load Test

In this scenario, you will create a sample application deployment which performs some math computations via python code. The sample code is shown below:

```python
import math

while True:
  x = 0.0001
  for i in range(1000000):
    x = x + math.sqrt(x)
    print(x)
  print("OK!")
```

The above code can be deployed via the [constant-load-deployment-test](assets/manifests/constant-load-deployment-test.yaml) manifest from the `Starter Kit` repository. The deployment will fetch a docker image hosting the required python runtime, and then attach a `ConfigMap` to the application `Pod` containing the sample python script shown earlier.

First, please clone the [Starter Kit](https://github.com/digitalocean/Kubernetes-Starter-Kit-Developers) repository, and change directory to your local copy:

```shell
git clone https://github.com/digitalocean/Kubernetes-Starter-Kit-Developers.git

cd Kubernetes-Starter-Kit-Developers
```

Then, create the sample deployment for the first scenario via `kubectl` (a `separate namespace` is being created as well, for better observation):

```shell
kubectl create ns hpa-constant-load

kubectl apply -f 09-scaling-application-workloads/assets/manifests/constant-load-deployment-test.yaml -n hpa-constant-load
```

**Note:**

The sample [deployment](assets/manifests/constant-load-deployment-test.yaml#L37) provided in this repository, sets requests limits for the application Pods. This is important because HPA logic relies on having resource requests limits set for your Pods, and it won't work otherwise. In general, it is advised to set resource requests limits for all your application Pods, to avoid things running out of control in your cluster.

Verify that the deployment was created successfully, and that it's up and running:

```shell
kubectl get deployments -n hpa-constant-load
```

The output looks similar to (notice that there's only one Pod up and running in the deployment):

```text
NAME                            READY   UP-TO-DATE   AVAILABLE   AGE
constant-load-deployment-test   1/1     1            1           8s
```

Next, create the [constant-load-hpa-test](assets/manifests/constant-load-hpa-test.yaml) resource in your cluster, via `kubectl`:

```shell
kubectl apply -f 09-scaling-application-workloads/assets/manifests/constant-load-hpa-test.yaml -n hpa-constant-load
```

The above command will create a `HPA` resource, targeting the sample deployment created earlier. You can check the `HPA state` via:

```shell
kubectl get hpa -n hpa-constant-load
```

The output looks similar to (notice that it targets the `constant-load-deployment-test` in the `REFERENCE` column, and `TARGETS` column showing `current CPU usage/target threshold`):

```text
NAME                 REFERENCE                                  TARGETS    MINPODS   MAXPODS   REPLICAS   AGE
constant-load-test   Deployment/constant-load-deployment-test   255%/50%   1         3         3          49s
```

You can also notice in the above output that the `REPLICAS` column value `increased` from `1` to `3` for the sample application deployment, as stated in the HPA CRD spec. The process took a short time to complete, because the application used in this examples creates load in no time. Going further, you can also inspect the HPA events and see the actions taken, via: `kubectl describe hpa -n hpa-constant-load`.

### Scenario 2 - Variable Load Test

A more interesting and realistic scenario to test and study, is one where variable load is created for the application under test. For this experiment you're going to use a different namespace and set of manifests, to observe the final behavior in complete isolation from the previous scenario.

The application under test is a simple [quote of the moment](https://github.com/datawire/quote) server listening for HTTP requests. On each call it sends a different `quote` as a response. You create load on the service by sending HTTP requests very fast (each 1ms roughly). There's a [helper script](assets/scripts/quote_service_load_test.sh) to help you achieve this.

First, please create the [quote](assets/manifests/quote_deployment.yaml) application `deployment` and `service` using `kubectl` (also a dedicated `hpa-variable-load` namespace is created beforehand). Please make sure to change directory to `Kubernetes-Starter-Kit-Developers` first:

```shell
kubectl create ns hpa-variable-load

kubectl apply -f 09-scaling-application-workloads/assets/manifests/quote_deployment.yaml -n hpa-variable-load
```

Now, verify if the `deployment` and `services` are `OK`:

```shell
kubectl get all -n hpa-variable-load
```

The output looks similar to:

```text
NAME                             READY   STATUS    RESTARTS   AGE
pod/quote-dffd65947-s56c9        1/1     Running   0          3m5s

NAME            TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
service/quote   ClusterIP   10.245.170.194   <none>        80/TCP    3m5s

NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/quote       1/1     1            1           3m5s

NAME                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/quote-6c8f564ff        1         1         1       3m5s
```

Next, create the `HPA` for the `quote deployment` using `kubectl`:

```shell
kubectl apply -f 09-scaling-application-workloads/assets/manifests/quote-deployment-hpa-test.yaml -n hpa-variable-load
```

Now, check if the HPA resource is in place and alive:

```shell
kubectl get hpa -n hpa-variable-load
```

The output looks similar to:

```text
NAME                 REFERENCE          TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
variable-load-test   Deployment/quote   1%/20%    1         3         1          108s
```

Please note that in this case there's a different threshold value set for the CPU utilization resource metric, as well as a different scale down behavior. The new spec for the HPA CRD looks like below:

```yaml
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: quote
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 60
  minReplicas: 1
  maxReplicas: 3
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 20
```

The above configuration alters the `scaleDown.stabilizationWindowSeconds` behavior and sets it to a lower value of `60 seconds`. This is not really needed in practice, but in this case you may want to speed up things and quickly see how the autoscaler performs the scale down actions. By default, the `HorizontalPodAutoscaler` has a cool down period of `5 minutes` (or `300 seconds`). This is sufficient in most of the cases, and should avoid fluctuations in the replica scaling process.

In the final step, you will run the helper script provided in this repository to create load on the target (meaning the `quote server`). The script performs successive HTTP calls in a really short period of time, thus trying to simulate external load coming from the users (to some extent).

Please make sure to have two separate windows, in order to observe better the results (you can use [tmux](https://github.com/tmux/tmux/wiki), for example). Then, in one window please invoke the quote service load test shell script:

```shell
./09-scaling-application-workloads/assets/scripts/quote_service_load_test.sh
```

And in another window, create a `watch` for the `HPA` resource using `kubectl -w`

```shell
kubectl get hpa -n hpa-variable-load -w
```

Below animation will show you the results (notice how the autoscaler kicks in when load increases or decreases, and alters the quote server deployment replica set):

![quote HPA in action](assets/images/variable_load_testing.gif)

Next, you will learn how to scale applications based on other metrics such as custom metrics coming from Prometheus. As an example, you can scale based on the number of HTTP requests that an application receives, rather than CPU and/or memory utilization.

## Scaling Applications using Custom Metrics

## Conclusion

Go to [Section 14 - Starter Kit Resource Usage](../14-starter-kit-resource-usage/README.md).
