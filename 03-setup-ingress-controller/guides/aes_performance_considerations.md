# Performance Considerations for the Ambassador Edge Stack

## Table of contents

- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Adjusting Deployment Replica Count](#adjusting-deployment-replica-count)
- [Adjusting Resource Requests](#adjusting-resource-requests)

## Introduction

The performance of `Ambassador Edge Stack` control plane can be characterized along a number of different `dimensions`. The following list contains each `dimension` that has an impact at the application level:

- The number of `TLSContext` resources.
- The number of `Host` resources.
- The number of `Mapping` resources per Host resource.
- The number of `unconstrained Mapping resources` (these will apply to all `Host` resources).

Taking each key factor from above into consideration and mapping it to the Kubernetes realm, it means that you need to adjust the `requests` and `limits` for the deployment pods, and/or the `replica` count.

Talking about resource usage limits, `Kubernetes` will generally kill an `Ambassador Edge Stack` pod for one of two reasons:

- Exceeding `memory` limits.
- Failed `liveness/readiness` probes.

`Ambassador Edge Stack` can `grow` in terms of `memory usage`, so it's very likely to get the application pods killed because of `OOM` issues.

In general you should try to keep AES `memory usage` below `50%` of the pod's `limit`. This may seem like a generous safety margin, but when reconfiguration occurs, `Ambassador Edge Stack` requires `additional memory to avoid disrupting active connections`.

Going further, what you can do on the `Kubernetes` side, is to adjust deployment `replica count`, and resource `requests` for pods.

## Prerequisites

To complete this guide, you will need:

1. A [Git](https://git-scm.com/downloads) client, to clone the `Starter Kit` repository.
2. [Helm](https://www.helms.sh), for managing `Ambassador` releases and upgrades.
3. [Kubectl](https://kubernetes.io/docs/tasks/tools), for `Kubernetes` interaction.

## Adjusting Deployment Replica Count

Based on our findings, a value of `2` should suffice in case of small `development` environments.

Next, you're going to scale the `Ambassador Edge Stack` deployment, and adjust the `replicaCount` value, via the [ambassador-values.yaml](../assets/manifests/ambassador-values-v7.2.2.yaml) file provided in the `Starter Kit` Git repository.

Steps to follow:

1. First, change directory where the `Starter Kit` Git repository was cloned.
2. Next, open and inspect the `replicaCount` section, from the `03-setup-ingress-controller/assets/manifests/ambassador-values-v7.2.2.yaml` file provided in the `Starter Kit` repository, using a text editor of your choice (preferably with `YAML` lint support). It has the required values already set for you to use. For example, you can use [VS Code](https://code.visualstudio.com):

   ```shell
   code 03-setup-ingress-controller/assets/manifests/ambassador-values-v7.2.2.yaml
   ```

3. Then, apply changes using `Helm` upgrade:

    ```shell
    AMBASSADOR_CHART_VERSION="7.2.2"

    helm upgrade ambassador datawire/ambassador --version "$AMBASSADOR_CHART_VERSION" \
        --namespace ambassador \
        -f "03-setup-ingress-controller/assets/manifests/ambassador-values-v${AMBASSADOR_CHART_VERSION}.yaml"
    ```

4. Finally, check the `ambassador` deployment `replica count` (it should scale to `2`):

    ```shell
    kubectl get deployments -n ambassador
    ```

    The output looks similar to:

    ```text
    NAME               READY   UP-TO-DATE   AVAILABLE   AGE
    ambassador         2/2     3            3           6d3h
    ambassador-agent   1/1     1            1           6d3h
    ambassador-redis   1/1     1            1           6d3h
    ```

## Adjusting Resource Requests

In this section, you're going to adjust resource requests via `Helm`, and tune the `memory` requests value to a reasonable value, by using the [ambassador-values.yaml](../assets/manifests/ambassador-values-v7.2.2.yaml) file provided in the `Starter Kit` Git repository.

Based on our findings, the memory requests should be adjusted to a value of `200m`, which satisfies most development needs in general.

Steps to follow:

1. First, change directory where the `Starter Kit` Git repository was cloned.
2. Next, open and inspect the `resources` section, from the `03-setup-ingress-controller/assets/manifests/ambassador-values-v7.2.2.yaml` file provided in the `Starter Kit` repository, using a text editor of your choice (preferably with `YAML` lint support). It has the required values already set for you to use. For example, you can use [VS Code](https://code.visualstudio.com):

   ```shell
   code 03-setup-ingress-controller/assets/manifests/ambassador-values-v7.2.2.yaml
   ```

3. Then, run a `Helm` upgrade to apply changes:

    ```shell
    HELM_CHART_VERSION="7.2.2"

    helm upgrade ambassador datawire/ambassador --version "$HELM_CHART_VERSION" \
        --namespace ambassador \
        -f "03-setup-ingress-controller/assets/manifests/ambassador-values-v${HELM_CHART_VERSION}.yaml"
    ```

4. Finally, check the `memory requests` new `value` - it should say `200Mi` (look in the `Containers` section, from below command output):

    ```shell
    kubectl describe deployment ambassador -n ambassador
    ```

    The output looks similar to:

    ```text
    ...
    Containers:
      ambassador:
       Image:       docker.io/datawire/aes:1.13.10
       Ports:       8080/TCP, 8443/TCP, 8877/TCP
       Host Ports:  0/TCP, 0/TCP, 0/TCP
       Limits:
         cpu:     1
         memory:  600Mi
       Requests:
         cpu:      200m
         memory:   200Mi
    ...
    ```

Another way of finding and setting the right values for requests/limits, is to evaluate `Ambassador` for a period of time (a few days or so). Then, you can run `statistical` queries via `Prometheus` and find the best `values` for your `use case`. A good article to read on this topic, can be found [here](https://blog.kubecost.com/blog/requests-and-limits).

For more information about performance tuning please visit the [AES Performance and Scaling](https://www.getambassador.io/docs/edge-stack/latest/topics/running/scaling) official documentation page.
