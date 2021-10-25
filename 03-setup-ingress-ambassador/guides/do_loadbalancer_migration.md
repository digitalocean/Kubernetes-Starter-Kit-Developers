# Migrating DigitalOcean LoadBalancer for the Ambassador Edge Stack

## Table of Contents

- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Preparing the DigitalOcean LoadBalancer for Migration](#preparing-the-digitalocean-loadbalancer-for-migration)
- [Simulate a Disaster by Uninstalling the Ambassador Edge Stack](#simulate-a-disaster-by-uninstalling-the-ambassador-edge-stack)
- [Re-installing the Ambassador Edge Stack and Restoring CRDs](#re-installing-the-ambassador-edge-stack-and-restoring-crds)

## Introduction

When you want to expose a `Kubernetes Service` to the outside world, you will use a `LoadBalancer` service type. But, it's not quite handy to have a separate `LoadBalancer` for each `service` that you want to make `public`. One of the main issues with this kind of setup is - `costs`. In order to reduce costs, you will want to minimize the number of `LoadBalancers` by using an `Ingress Controller`.

**Ingress is not a Kubernetes Service, and a Kubernetes Service is not Ingress!**

It's very important to understand the above statement. `Ingress` is just another `API specification`, and it's handled by an `Ingress Controller`.
A `Kubernetes Service` is just a way to expose internal Kubernetes objects (like `Pods`, or an `Ingress Controller`) to the outside world.

`Ingress` acts like a small `router` inside your `Kubernetes` cluster. It's specialized in `HTTP` based path routing, thus operating at `layer 7`.

`Ambassador Edge Stack` can function as a fully-fledged `Ingress Controller`, making it easy to work with other `Ingress-oriented` tools within the `Kubernetes` ecosystem. But this kind of setup is recommended for power users only, and for really special cases.

`Ambassador` abstracts the `Ingress` spec even more, thus making it `easier` to work with, and adds more functionality on top. So, for most use cases you don't need to use the `Ingress Controller` functionality of `AES`. The recommended way of using AES is via the CRDs, like `Hosts` and `Mappings`.

You can expose `Ambassador Edge Stack` via the `LoadBalancer` service type, which is what happens in the default `Helm` installation used in the `Starter Kit` tutorial. But `Kubernetes` will set LoadBalancer `ownership` for the service in question. It means that, whenever the `LoadBalancer` service is `deleted` (e.g. when uninstalling `AES`), the `DigitalOcean LoadBalancer` is `deleted` as well. This is expected, and it's part of the Kubernetes `garbage collection` process.

What happens when you `reinstall` the `Ambassador Edge Stack`, or when you want to `migrate` to another `DOKS` cluster ? The answer is that, a `new LoadBalancer` will be created and a `new external IP` is assigned, thus rendering your `DNS records` unusable.

What options are available and more important: can I preserve my original load balancer and external IP as well?

Short answer is: **YES**.

You can use the `DigitalOcean Cloud Controller` available features for `migrating` LoadBalancers. Two special `service annotations` are available:

- `service.kubernetes.io/do-loadbalancer-disown`, for controlling ownership of load balancers.
- `kubernetes.digitalocean.com/load-balancer-id`, for specifying the `LoadBalancer ID` you want to take ownership.

In this guide, you will learn how to `migrate` an existing `DigitalOcean LoadBalancer` from a previous `Ambassador` stack installation to a new one.

## Prerequisites

To follow this guide, you need to have the same [prerequisites](../README.md#prerequisites) list prepared, as explained in the main `Ambassador` tutorial from the `Starter Kit`. This guide also assumes that you have `AES` already `installed` and properly `configured`, along with your custom `DNS` records pointing to the `echo` and `quote` hosts.

## Preparing the DigitalOcean LoadBalancer for Migration

First, check that the `echo` and `quote` service endpoints are working:

1. Echo service:

    ```shell
    curl -L http://echo.starter-kit.online/echo/
    ```

    The output looks similar to:

    ```text
    Request served by echo-5d8d65c665-569zf

    HTTP/1.1 GET /

    Host: echo.starter-kit.online
    Accept: */*
    X-Request-Id: b78df8df-21a7-40f5-a83b-fed107448572
    X-Envoy-Expected-Rq-Timeout-Ms: 3000
    X-Envoy-Original-Path: /echo/
    Content-Length: 0
    User-Agent: curl/7.77.0
    X-Forwarded-For: 10.114.0.4
    X-Forwarded-Proto: https
    X-Envoy-Internal: true
    ```

2. Quote service:

    ```shell
    curl -L http://quote.starter-kit.online/quote/
    ```

    The output looks similar to:

    ```text
    {
      "server": "ellipsoidal-elderberry-7kwkpxz5",
      "quote": "668: The Neighbor of the Beast.",
      "time": "2021-10-26T12:47:12.437987753Z"
    }
    ```

Next, fetch the DO LoadBalancer `external IP` created by the `Ambassador Edge Stack` deployment (example below is assuming that the stack was deployed using the `ambassador` namespace):

```shell
kubectl get svc -n ambassador
```

The output looks similar to (notice the `EXTERNAL-IP` column value for the `ambassador` service):

```text
NAME               TYPE           CLUSTER-IP      EXTERNAL-IP       PORT(S)                      AGE
ambassador         LoadBalancer   10.245.116.70   143.244.204.197   80:31237/TCP,443:32540/TCP   3d21h
ambassador-admin   ClusterIP      10.245.76.186   <none>            8877/TCP,8005/TCP            3d21h
ambassador-redis   ClusterIP      10.245.85.152   <none>            6379/TCP                     3d21h
```

Then, list all `LoadBalancers` resources from your `DigitalOcean` account, and print the `IP` and `ID` columns only:

```shell
doctl compute load-balancer list --format IP,ID
```

The output looks similar to (search the LoadBalancer `ID` that matches your Ambassador external `IP`):

```text
IP                 ID
143.244.204.197    e95433c3-ad00-4222-b0c3-5208e554e45a
```

After successfully identifying the `LoadBalancer ID` used by your `Ambassador` deployment, please write it down because you will need it later. Before continuing with the next steps, please make sure that you `change directory` where the `Starter Kit` repository was `cloned` on your machine.

Now, open and inspect the `03-setup-ingress-ambassador/assets/manifests/ambassador-values-v6.7.13.yaml` file provided in the `Starter Kit` repository, using an editor of your choice (preferably with `YAML` lint support). For example, you can use [VS Code](https://code.visualstudio.com):

```shell
HELM_CHART_VERSION="6.7.13"

code "03-setup-ingress-ambassador/assets/manifests/ambassador-values-v${HELM_CHART_VERSION}.yaml"
```

Next, please uncomment the `service.annotations` section. It should look like below:

```yaml
service:
  annotations:
    # You can keep your existing LB when migrating to a new DOKS cluster, or when reinstalling AES
    kubernetes.digitalocean.com/load-balancer-id: "<YOUR_DO_LB_ID_HERE>"
    service.kubernetes.io/do-loadbalancer-disown: false
```

Explanations for the above configuration:

- `kubernetes.digitalocean.com/load-balancer-id`: Tells DigitalOcean `Cloud Controller` what `LoadBalancer ID` to use for the `Ambassador` service.
- `service.kubernetes.io/do-loadbalancer-disown`: Tells DigitalOcean `Cloud Controller` to disown the LoadBalancer ID pointed by `kubernetes.digitalocean.com/load-balancer-id`. If set to `true`, then whenever the `ambassador` service is deleted, the associated `LB` will **NOT** be deleted by `Kubernetes`.

Now, please replace the `<>` placeholders accordingly, using your `LoadBalancer ID` that you wrote down earlier. Also, set the `service.kubernetes.io/do-loadbalancer-disown` annotation value to `true`. The final configuration should look like this:

```yaml
service:
  annotations:
    # You can keep your existing LB when migrating to a new DOKS cluster, or when reinstalling AES
    kubernetes.digitalocean.com/load-balancer-id: "e95433c3-ad00-4222-b0c3-5208e554e45a"
    service.kubernetes.io/do-loadbalancer-disown: true
```

Finally, save the values file, and apply changes for `Ambassador` using `Helm`:

```shell
HELM_CHART_VERSION="6.7.13"

helm upgrade ambassador datawire/ambassador --version "$HELM_CHART_VERSION" \
  --namespace ambassador \
  -f "03-setup-ingress-ambassador/assets/manifests/ambassador-values-v${HELM_CHART_VERSION}.yaml"
```

At this point, the `LoadBalancer` is disowned from the `ambassador` service by the DigitalOcean `Cloud Controller`. It means, that you can migrate it to another `Ambassador` service, and change ownership. Notice that the `DNS records` for the `starter-kit.online` domain remain `intact`, and still point to the `original IP` of the `LoadBalancer` in question.

**Important note:**

**The new service’s cluster must reside in the `same VPC` as the `original service` for the load balancer `ownership` to be transferred successfully.**

## Simulate a Disaster by Uninstalling the Ambassador Edge Stack

Whenever you delete the `Ambassador` stack, or the default service (e.g. `ambassador`), the associated `DigitalOcean` load balancer is deleted as well as part of the `Kubernetes garbage collection` process. Because you `disowned` the `LoadBalancer` service from `Ambassador`, it will **NOT** be removed automatically anymore. In the next steps, you will uninstall `AES` and verify this feature offered by the DigitalOcean `Cloud Controller`.

**Notes:**

- **`Helm will not delete CRD's` from your cluster, unless you tell it to do so. It means that your `Hosts`, `Mappings` and other custom resources you created for `Ambassador` will be `preserved` if redeploying AES in the `same DOKS` cluster !**
- Before taking the next steps, it's best practice to have a backup somewhere for all your Ambassador `Host` and `Mapping` resources. To re-create the `AES` custom resources for the `Starter Kit` tutorial, you can always find the manifests at this [location](../assets/manifests) in the `Git` repository. You can also learn how to do it manually, via:

  ```shell
  # Create directory to store backups for custom resources
  mkdir ambassador-backups

  # Backup Host resources for the `echo` and `quote` services
  kubectl get host echo-host -n ambassador -o yaml > ambassador-backups/echo-host.yaml

  kubectl get host quote-host -n ambassador -o yaml > ambassador-backups/quote-host.yaml

  # Backup Mapping resources for the `echo` and `quote` services
  kubectl get mapping echo-backend -n ambassador -o yaml > ambassador-backups/echo-backend-mapping.yaml

  kubectl get mapping quote-backend -n ambassador -o yaml > ambassador-backups/quote-backend-mapping.yaml
  ```

- From a `production environment` standpoint, please bear in mind that the disaster scenario presented in this guide will imply `downtime` for your `backend services`.

First, uninstall the `Ambassador` stack using `Helm`:

```shell
helm delete ambassador -n ambassador
```

Then, check if `Helm` deleted the `release` (there should be no `ambassador` listing):

```shell
helm ls -A
```

Next, verify that all `Ambassador` resources were deleted (after the command gets executed, you should see this message: `No resources found in ambassador namespace`):

```shell
kubectl get all -n ambassador
```

Now, list all `load balancers` from your `DigitalOcean` account, and print the `IP` and `ID` columns only:

```shell
doctl compute load-balancer list --format IP,ID
```

The output looks similar to (notice that your original `load balancer` is still there, with same `ID` and `IP`):

```text
IP                 ID
143.244.204.197    e95433c3-ad00-4222-b0c3-5208e554e45a
```

Finally, backend services should be unavailable at this point:

```shell
curl -L http://echo.starter-kit.online/echo/

curl -L http://quote.starter-kit.online/quote/
```

The output from both looks similar to:

```text
curl: (52) Empty reply from server
```

## Re-installing the Ambassador Edge Stack and Restoring CRDs

Having the `load balancer` and the original `external IP` preserved is great, but you need to set back `ownership` to `Ambassador` again by deploying a new release.

In the previous section of this guide, you intentionally deleted the `Ambassador` stack release which is maybe a little bit more of a killer situation. In practice, a more `realistic` scenario is when you want to `migrate` from one `DOKS` cluster to another (assuming that both reside in the same `VPC`), and you want to preserve your `DNS` settings as well.

First, open again the `03-setup-ingress-ambassador/assets/manifests/ambassador-values-v6.7.13.yaml` file you modified earlier in [Preparing the DigitalOcean LoadBalancer for Migration](#preparing-the-digitalocean-loadbalancer-for-migration) section. You can use [VS Code](https://code.visualstudio.com) for example:

```shell
HELM_CHART_VERSION="6.7.13"

code "03-setup-ingress-ambassador/assets/manifests/ambassador-values-v${HELM_CHART_VERSION}.yaml"
```

Then, go to the `service.annotations` section, making sure that `kubernetes.digitalocean.com/load-balancer-id` points to your original load balancer, and `service.kubernetes.io/do-loadbalancer-disown` value is set to **`false`** now:

```yaml
service:
  annotations:
    # You can keep your existing LB when migrating to a new DOKS cluster, or when reinstalling AES
    kubernetes.digitalocean.com/load-balancer-id: "e95433c3-ad00-4222-b0c3-5208e554e45a"
    service.kubernetes.io/do-loadbalancer-disown: false
```

What the above configuration does is, to set back `ownership` for the `Ambassador` service, by re-using your original load balancer `ID`.

Next, save the values file, and `re-install` Ambassador using `Helm`:

```shell
HELM_CHART_VERSION="6.7.13"

helm install ambassador datawire/ambassador --version "$HELM_CHART_VERSION" \
  --create-namespace \
  --namespace ambassador \
  -f "03-setup-ingress-ambassador/assets/manifests/ambassador-values-v${HELM_CHART_VERSION}.yaml"
```

After a while check the `Ambassador` services using `kubectl`:

```shell
kubectl get svc -n ambassador
```

The output looks similar to (notice that the `ambassador` service took `ownership`, and the same `EXTERNAL-IP` is used):

```text
NAME               TYPE           CLUSTER-IP       EXTERNAL-IP       PORT(S)                      AGE
ambassador         LoadBalancer   10.245.32.232    143.244.204.197   80:30134/TCP,443:30180/TCP   4m27s
ambassador-admin   ClusterIP      10.245.113.172   <none>            8877/TCP,8005/TCP            4m27s
ambassador-redis   ClusterIP      10.245.54.242    <none>            6379/TCP                     4m27s
```

Then, after a few minutes, verify if the `load balancer` is `healthy` again:

```shell
doctl compute load-balancer list --format ID,IP,Status
```

The output looks similar to (notice that the `Status` column reports `active`, meaning it's `healthy` again):

```text
ID                                      IP                 Status
e95433c3-ad00-4222-b0c3-5208e554e45a    143.244.204.197    active
```

Finally, you can test the `echo` and `quote` backend services, which should be `alive` and `respond` as usual:

1. **Echo** service:

    ```shell
    curl -L http://echo.starter-kit.online/echo/
    ```

    The output looks similar to:

    ```text
    Request served by echo-5d8d65c665-569zf

    HTTP/1.1 GET /

    Host: echo.starter-kit.online
    X-Forwarded-For: 10.114.0.4
    X-Envoy-Internal: true
    X-Envoy-Expected-Rq-Timeout-Ms: 3000
    X-Envoy-Original-Path: /echo/
    Content-Length: 0
    User-Agent: curl/7.77.0
    Accept: */*
    X-Forwarded-Proto: https
    X-Request-Id: ce29164d-f6f2-460b-b6d8-755d6d3283e2
    ```

2. **Quote** service:

    ```shell
    curl -L http://quote.starter-kit.online/quote/
    ```

    The output looks similar to:

    ```text
    {
    "server": "ellipsoidal-elderberry-7kwkpxz5",
    "quote": "Non-locality is the driver of truth. By summoning, we vibrate.",
    "time": "2021-10-26T16:30:32.677575Z"
    }
    ```

If everything looks as above, then you `migrated` the load `balancer resource` successfully. 

For more information and updates on the topic, you can also visit the official [Load Balancers Migration](https://docs.digitalocean.com/products/kubernetes/how-to/migrate-load-balancers) guide from `DigitalOcean`.
