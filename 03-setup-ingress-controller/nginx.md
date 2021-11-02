# How to Configure Ingress using Nginx

## Introduction

In this tutorial, you will learn how to use the Kubernetes-maintained [Nginx](https://kubernetes.github.io/ingress-nginx) Ingress Controller. Then, you're going to discover how to have `TLS` certificates automatically deployed and configured for your hosts (thus enabling `TLS` termination), and `route` traffic to your `backend` applications.

Why use Kubernetes-maintained `Nginx` ?

- Open source (driven by the Kubernetes community).
- Lot of support from the Kubernetes community.
- Flexible way of routing traffic to your services inside the cluster.
- `TLS` certificates support and auto renewal via [Cert-Manager](https://cert-manager.io).

As with every Ingress Controller, `Nginx` allows you to define ingress objects. Each ingress object contains a set of rules that define how to route external traffic (HTTP requests) to your backend services. For example, you can have multiple hosts defined under a single domain, and then let `Nginx` take care of routing traffic to the correct host.

`Ingress Controller` sits at the `edge` of your `VPC`, and acts as the `entry point` for your `network`. It knows how to handle `HTTP` requests only, thus it operates at `layer 7` of the `OSI` model. When `Nginx` is deployed to your `DOKS` cluster, a `load balancer` is created as well, through which it receives the outside traffic. Then, you will have a `domain` set up with `A` type records (hosts), which in turn point to your load balancer `external IP`. So, data flow goes like this: `User Request -> Host.DOMAIN -> Load Balancer -> Ingress Controller (NGINX) -> Backend Applications (Services)`.

After finishing this tutorial, you will be able to:

- Create and manage `Nginx` Helm deployments.
- Create and configure basic HTTP rules for `Nginx`, to route requests to your backend applications.
- Automatically configure `TLS` certificates for your `hosts`, thus having `TLS` termination.

### Starter Kit Nginx Setup Overview

![Starter Kit Nginx Setup Overview](assets/images/starter_kit_nginx_setup_overview.png)

## Table of contents

- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Step 1 - Installing the Nginx Ingress Controller](#step-1---installing-the-nginx-ingress-controller)
- [Step 2 - Configuring the DigitalOcean Domain for Nginx Ingress Controller](#step-2---configuring-the-digitalocean-domain-for-nginx-ingress-controller)
- [Step 3 - Creating the Nginx Backend Services](#step-3---creating-the-nginx-backend-services)
- [Step 4 - Configuring Nginx Ingress Rules for Backend Services](#step-4---configuring-nginx-ingress-rules-for-backend-services)
- [Step 5 - Enabling Proxy Protocol](#step-5---enabling-proxy-protocol)
- [Step 6 - Verifying the Nginx Ingress Setup](#step-6---verifying-the-nginx-ingress-setup)
- [How To Guides](#how-to-guides)
- [Conclusion](#conclusion)

## Prerequisites

To complete this tutorial, you will need:

1. A [Git](https://git-scm.com/downloads) client, to clone the `Starter Kit` repository.
2. [Helm](https://www.helms.sh), for managing `Nginx` releases and upgrades.
3. [Doctl](https://github.com/digitalocean/doctl/releases), for `DigitalOcean` API interaction.
4. [Kubectl](https://kubernetes.io/docs/tasks/tools), for `Kubernetes` interaction.
5. [Curl](https://curl.se/download.html), for testing the examples (backend applications).

Please make sure that `doctl` and `kubectl` context is configured to point to your `Kubernetes` cluster - refer to [Step 2 - Authenticating to DigitalOcean API](../01-setup-DOKS/README.md#step-2---authenticating-to-digitalocean-api) and [Step 3 - Creating the DOKS Cluster](../01-setup-DOKS/README.md#step-3---creating-the-doks-cluster) from the `DOKS` setup tutorial.

In the next step, you will learn how to deploy the `Nginx Ingress Controller`, using the `Helm` package manager for `Kubernetes`.

## Step 1 - Installing the Nginx Ingress Controller

In this step, you will deploy the `Nginx Ingress Controller` to your `DOKS` cluster, via `Helm`.

Steps to follow:

1. First, clone the `Starter Kit` repository and change directory to your local copy.

    ```shell
    git clone https://github.com/digitalocean/Kubernetes-Starter-Kit-Developers.git

    cd Kubernetes-Starter-Kit-Developers
    ```

2. Next, add the `Helm` repo, and list the available `charts`:

    ```shell
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

    helm search repo ingress-nginx
    ```

    The output looks similar to the following:

    ```text
    NAME                            CHART VERSION   APP VERSION     DESCRIPTION                                       
    ingress-nginx/ingress-nginx     4.0.6           1.0.4           Ingress controller for Kubernetes using NGINX 
    ```

    **Note:**

    The chart of interest is `ingress-nginx/ingress-nginx`, which will install Kubernetes-maintained `Nginx` on the cluster. Please visit the [kubernetes-nginx](https://github.com/kubernetes/ingress-nginx/tree/main/charts/ingress-nginx) page, for more details about this chart.
3. Then, open and inspect the `03-setup-ingress-controller/assets/manifests/nginx-values-v4.0.6.yaml` file provided in the `Starter Kit` repository, using an editor of your choice (preferably with `YAML` lint support). For example, you can use [VS Code](https://code.visualstudio.com):

    ```shell
    code 03-setup-ingress-controller/assets/manifests/nginx-values-v4.0.6.yaml
    ```

    **Note:**

    There are times when you want to re-use the existing `load balancer`. This is for preserving your `DNS` settings and other `load balancer` configurations. If so, make sure to modify the `nginx-values-v4.0.6.yaml` file, and add the annotation for your existing load balancer. Please refer to the `DigitalOcean` Kubernetes guide - [How To Migrate Load Balancers](https://docs.digitalocean.com/products/kubernetes/how-to/migrate-load-balancers) for more details.
4. Finally, install the `Nginx Ingress Controller` using `Helm` (a dedicated `ingress-nginx` namespace will be created as well):

    ```shell
    NGINX_CHART_VERSION="4.0.6"

    helm install ingress-nginx ingress-nginx/ingress-nginx --version "$NGINX_CHART_VERSION" \
        --namespace ingress-nginx \
        --create-namespace \
        -f "03-setup-ingress-controller/assets/manifests/nginx-values-v${NGINX_CHART_VERSION}.yaml"
    ```

    **Note:**

    A `specific` version for the ingress-nginx `Helm` chart is used. In this case `4.0.6` was picked, which maps to the `1.0.4` release of `Nginx` (see the output from `Step 2.`). It’s good practice in general, to lock on a specific version. This helps to have predictable results, and allows versioning control via `Git`.

**Observations and results:**

You can verify `Nginx` deployment status via:

```shell
helm ls -n ingress-nginx
```

The output looks similar to (notice that the `STATUS` column value is `deployed`):

```text
NAME            NAMESPACE       REVISION   UPDATED                                 STATUS     CHART                   APP VERSION
ingress-nginx   ingress-nginx   1          2021-11-02 10:12:44.799499 +0200 EET    deployed   ingress-nginx-4.0.6     1.0.4 
```

Next check Kubernetes resources created for the `ingress-nginx` namespace (notice the `deployment` and `replicaset` resources which should be healthy, as well as the `LoadBalancer` resource having an `external IP` assigned):

```shell
kubectl get all -n ingress-nginx
```

The output looks similar to:

```text
NAME                                            READY   STATUS    RESTARTS   AGE
pod/ingress-nginx-controller-5c8d66c76d-m4gh2   1/1     Running   0          56m

NAME                                         TYPE           CLUSTER-IP     EXTERNAL-IP       PORT(S)                      AGE
service/ingress-nginx-controller             LoadBalancer   10.245.27.99   143.244.204.126   80:32462/TCP,443:31385/TCP   56m
service/ingress-nginx-controller-admission   ClusterIP      10.245.44.60   <none>            443/TCP                      56m

NAME                                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/ingress-nginx-controller   1/1     1            1           56m

NAME                                                  DESIRED   CURRENT   READY   AGE
replicaset.apps/ingress-nginx-controller-5c8d66c76d   1         1         1       56m
```

Finally, list all load balancer resources from your `DigitalOcean` account, and print the `IP`, `ID`, `Name` and `Status`:

```shell
doctl compute load-balancer list --format IP,ID,Name,Status
```

The output looks similar to (should contain the new `load balancer` resource created for `Nginx Ingress Controller` in a healthy state):

```text
IP                 ID                                      Name                                Status
143.244.204.126    0471a318-a98d-49e3-aaa1-ccd855831447    acdc25c5cfd404fd68cd103be95af8ae    active
```

In the next step, you will learn how to create and configure the DigitalOcean `domain` for your `Nginx Ingress Controller`.

## Step 2 - Configuring the DigitalOcean Domain for Nginx Ingress Controller

In this step, you will configure the `DigitalOcean` domain for `Nginx` Ingress Controller, using `doctl`. Then, you will create the domain `A` records for each host: `echo` and `quote`. Please bear in mind that `DigitalOcean` is not a domain name registrar. You need to buy a domain name first from [Google](https://domains.google), [GoDaddy](https://uk.godaddy.com), etc.

First, please issue the below command to create a new `domain` (`starter-kit.online`, in this example):

```shell
doctl compute domain create starter-kit.online
```

The output looks similar to the following:

```text
Domain                TTL
starter-kit.online    0
```

**Note:**

**YOU NEED TO ENSURE THAT YOUR DOMAIN REGISTRAR IS CONFIGURED TO POINT TO DIGITALOCEAN NAME SERVERS**. More information on how to do that is available [here](https://www.digitalocean.com/community/tutorials/how-to-point-to-digitalocean-nameservers-from-common-domain-registrars).

Next, you will add required `A` records for the `hosts` you created earlier. First, you need to identify the load balancer `external IP` created by the `nginx` deployment:

```shell
kubectl get svc -n ingress-nginx
```

The output looks similar to (notice the `EXTERNAL-IP` column value for the `ingress-nginx-controller` service):

```text
NAME                                 TYPE           CLUSTER-IP     EXTERNAL-IP       PORT(S)                      AGE
ingress-nginx-controller             LoadBalancer   10.245.27.99   143.244.204.126   80:32462/TCP,443:31385/TCP   96m
ingress-nginx-controller-admission   ClusterIP      10.245.44.60   <none>            443/TCP                      96m
```

Then, add the records (please replace the `<>` placeholders accordingly). You can change the `TTL` value as per your requirement:

```shell
doctl compute domain records create starter-kit.online --record-type "A" --record-name "echo" --record-data "<YOUR_LB_IP_ADDRESS>" --record-ttl "30"

doctl compute domain records create starter-kit.online --record-type "A" --record-name "quote" --record-data "<YOUR_LB_IP_ADDRESS>" --record-ttl "30"
```

**Hint:**

If you have only `one load balancer` in your account, then please use the following snippet:

```shell
LOAD_BALANCER_IP=$(doctl compute load-balancer list --format IP --no-header)

doctl compute domain records create starter-kit.online --record-type "A" --record-name "echo" --record-data "$LOAD_BALANCER_IP" --record-ttl "30"

doctl compute domain records create starter-kit.online --record-type "A" --record-name "quote" --record-data "$LOAD_BALANCER_IP" --record-ttl "30"
```

**Observation and results:**

List the available records for the `starter-kit.online` domain:

```shell
doctl compute domain records list starter-kit.online
```

The output looks similar to the following:

```text
ID           Type    Name     Data                    Priority    Port    TTL     Weight
164171755    SOA     @        1800                    0           0       1800    0
164171756    NS      @        ns1.digitalocean.com    0           0       1800    0
164171757    NS      @        ns2.digitalocean.com    0           0       1800    0
164171758    NS      @        ns3.digitalocean.com    0           0       1800    0
164171801    A       echo     143.244.204.126         0           0       3600    0
164171809    A       quote    143.244.204.126         0           0       3600    0
```

At this point the network traffic will reach the `Nginx` enabled cluster, but you need to configure the `backend services paths` for each of the hosts. All `DNS` records have one thing in common: `TTL` or time to live. It determines how long a `record` can remain cached before it expires. Loading data from a local cache is faster, but visitors won’t see `DNS` changes until their local cache expires and gets updated after a new `DNS` lookup. As a result, higher `TTL` values give visitors faster performance, and lower `TTL` values ensure that `DNS` changes are picked up quickly. All `DNS` records require a minimum `TTL` value of `30 seconds`.

Please visit the [How to Create, Edit and Delete DNS Records](https://docs.digitalocean.com/products/networking/dns/how-to/manage-records) page for more information.

In the next step, you will create two simple `backend` services, to help you test the `Nginx` ingress setup.

## Step 3 - Creating the Nginx Backend Services

In this step, you will deploy two example `backend` services (applications), named `echo` and `quote` to test the `Nginx` ingress setup.

You can have multiple `TLS` enabled `hosts` on the same cluster. On the other hand, you can have multiple `deployments` and `services` as well. So for each `backend` application, a corresponding Kubernetes `Deployment` and `Service` has to be created.

First, you define a new `namespace` for the `quote` and `echo` backend applications. This is good practice in general, because you don't want to pollute the `Nginx` namespace (or any other), with application specific stuff.

Steps to follow:

1. First, change directory (if not already) where the `Starter Kit` repository was cloned:

    ```shell
    cd Kubernetes-Starter-Kit-Developers
    ```

2. Next, create the `backend` namespace:

    ```shell
    kubectl create ns backend
    ```

3. Then, create the [echo](assets/manifests/echo_deployment.yaml) and [quote](assets/manifests/quote_deployment.yaml) deployments:

    ```shell
    kubectl apply -f 03-setup-ingress-controller/assets/manifests/echo_deployment.yaml

    kubectl apply -f 03-setup-ingress-controller/assets/manifests/quote_deployment.yaml
    ```

4. Finally, create the corresponding `services`:

    ```shell
    kubectl apply -f 03-setup-ingress-controller/assets/manifests/echo_service.yaml

    kubectl apply -f 03-setup-ingress-controller/assets/manifests/quote_service.yaml
    ```

**Observation and results:**

Inspect the `deployments` and `services` you just created:

```shell
kubectl get deployments -n backend
```

The output looks similar to the following (notice the `echo` and `quote` deployments):

```text
NAME    READY   UP-TO-DATE   AVAILABLE   AGE
echo    1/1     1            1           2m22s
quote   1/1     1            1           2m23s
```

```shell
kubectl get svc -n backend
```

The output looks similar to the following (notice the `echo` and `quote` services):

```text
NAME    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
echo    ClusterIP   10.245.115.112   <none>        80/TCP    3m3s
quote   ClusterIP   10.245.226.141   <none>        80/TCP    3m3s
```

In the next step, you will create the `nginx ingress rules` to route external traffic to the `quote` and `echo` backend services.

## Step 4 - Configuring Nginx Ingress Rules for Backend Services

## Step 5 - Enabling Proxy Protocol

A `L4` load balancer replaces the original `client IP` with its `own IP` address. This is a problem, as you will lose the `client IP` visibility in the application, so you need to enable `proxy protocol`. Proxy protocol enables a `L4 Load Balancer` to communicate the `original` client `IP`. For this to work, you need to configure both `DigitalOcean Load Balancer` and `Nginx`.

After deploying the [Backend Services](#step-3---creating-the-nginx-backend-services), you need to configure the nginx Kubernetes `Service` to use the `proxy protocol`. A special service annotation is made available by the `DigitalOcean Cloud Controller` - `service.beta.kubernetes.io/do-loadbalancer-enable-proxy-protocol`.

First, you need to edit the `Helm` values file provided in the `Starter Kit` repository using an editor of your choice (preferably with `YAML` lint support). For example, you can use [VS Code](https://visualstudio.microsoft.com):

```shell
code 03-setup-ingress-controller/assets/manifests/nginx-values-v4.0.6.yaml
```

Then, uncomment the `service` section as seen below:

```yaml
service:
 type: LoadBalancer
 annotations:
   # Enable proxy protocol
   service.beta.kubernetes.io/do-loadbalancer-enable-proxy-protocol: true
```

**Note:**

You must **NOT** create a load balancer with `Proxy` support by using the `DigitalOcean` web console, as any setting done outside `DOKS` is automatically `overridden` by DOKS `reconciliation`.

Finally, after saving the values file, you can apply changes using `Helm`:

```shell
NGINX_CHART_VERSION="4.0.6"

helm upgrade ingress-nginx ingress-nginx/ingress-nginx --version "$NGINX_CHART_VERSION" \
  --namespace ingress-nginx \
  -f "03-setup-ingress-controller/assets/manifests/nginx-values-v${NGINX_CHART_VERSION}.yaml"
```

For different `DigitalOcean` load balancer configurations, please refer to the examples from the official [DigitalOcean Cloud Controller Manager](https://github.com/digitalocean/digitalocean-cloud-controller-manager/tree/master/docs/controllers/services/examples) documentation.

In the next step, you will test the `nginx` ingress configuration, and perform `HTTP` requests on the backend services using `curl`.

## Step 6 - Verifying the Nginx Ingress Setup

## How To Guides

## Conclusion

In this tutorial, you learned how to set up an `Ingress` controller for your `DOKS` cluster, using the `Nginx Ingress Controller`. Then, you discovered how `AES` simplifies some of the common tasks, like: handling `SSL` certificates for your applications (thus enabling `TLS` termination), `routing` traffic to `backend` services, and `adjusting` resource `requests` and `limits` for the stack.

Next, `monitoring` plays a key role in every `production ready` system. In [Section 4 - Set up Prometheus Stack](../04-setup-prometheus-stack), you will learn how to enable monitoring for your `DOKS` cluster using `Prometheus`.

Go to [Section 4 - Set up Prometheus Stack](../04-setup-prometheus-stack/README.md).
