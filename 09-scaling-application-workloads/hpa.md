# Scaling Applications using the HorizontalPodAutoscaler

## Introduction

In a real world scenario you want to have resiliency for your applications. On the other hand, you want to be more efficient on resources and cut down costs as well. You need something that can scale your application on demand.

Most of the time you used application `Deployments` with a fixed `ReplicaSet` number. But, in production environments which are variably put under load by external users, it is not always that simple. It is inefficient to just go ahead and change some static values every time your web application deployments are put under load and start to misbehave, based on a specific period of the day, holidays or other special events, when many users come and visit your shopping site. Then, when the crowded period is over, you must go back and scale down your web deployments to avoid waste of resources, and reduce infrastructure costs.

This is were [Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale) kicks in, and provides a solution for more efficient resource usage, as well as reducing costs. It is a closed loop system that automatically grows or shrinks resources (e.g. application Pods), based on current needs. You create a `HorizontalPodAutoscaler` (or `HPA`) resource for each application deployment that needs autoscaling, and let it take care of the rest for you automatically.

Horizontal scaling means increasing the number of replicas for an application, as opposed to vertical scaling, which deals with adding more hardware resources such as CPU and/or RAM for Pods running your application.

### How Horizontal Pod Autoscaling Works

At a high level, each `HPA` does the following:

1. Keeps an eye on resource requests metrics coming from your application workloads (Pods), by querying the metrics server.
2. Compares the target threshold value that you set in the HPA definition with the average resource utilization observed on your application  workloads (CPU and memory).
3. If the target threshold is reached, then HPA will scale up your application deployment to meet demands. Otherwise, if below the threshold, it will scale down the deployment.

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
- [Step 2 - Creating a HPA based Deployment](#step-2---creating-a-hpa-based-deployment)
- [Step 3 - Testing the HPA based Deployment](#step-3---testing-the-hpa-based-deployment)
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

## Step 2 - Creating a HPA Deployment

By far the most used type of application `Deployment` is the one using a static or a fixed number for the `ReplicaSet` field. This may suffice for some simple deployments, or development environments. In this step you will learn how to automatically scale up or down your application based on current needs.

In a HPA based setup you let the `HorizontalPodAutoscaler` take control over the application replica count field. Typical HPA CRD manifest looks like below:

```yaml
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: python-load-test
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: python-load-test
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
```

## Step 3 - Testing the HPA Deployment

## Conclusion

Go to [Section 14 - Starter Kit Resource Usage](../14-starter-kit-resource-usage/README.md).
