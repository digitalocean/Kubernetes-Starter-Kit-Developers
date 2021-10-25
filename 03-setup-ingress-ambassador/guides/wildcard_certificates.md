# Enabling Wildcard Certificates Support for the Ambassador Edge Stack

## Table of contents

- [Introduction](#introduction)
- [Installing Cert-Manager](#installing-cert-manager)
- [Configuring the Ambassador Edge Stack with Cert-Manager](#configuring-the-ambassador-edge-stack-with-cert-manager)

## Introduction

A `wildcard certificate` is a kind of certificate that is able to handle `sub-domains` as well. The wildcard notion means that it has a global scope for the whole `DNS` domain you own.

The `Ambassador Edge Stack` built-in `ACME` client has support for the `HTTP-01` challenge only, which `doesn't support wildcard certificates`. To be able to issue and use `wildcard certificates`, you need to have an `ACME` client or certificate management tool that it is able to handle the `DNS-01` challenge type. A good choice that works with `Kubernetes` (and `Ambassador Edge Stack` implicitly) is [Cert-Manager](https://cert-manager.io).

For the `DNS-01` challenge type to work, the certificate management tool needs to be able to handle DNS `TXT records` for your cloud provider - `DigitalOcean` in this case. `Cert-Manager` is able to perform this kind of operation via the built-in [DigitalOcean Provider](https://cert-manager.io/docs/configuration/acme/dns01/digitalocean).

For more information on how the `DNS-01` challenge works, please read the [DNS-01](https://letsencrypt.org/docs/challenge-types/#dns-01-challenge) article from `Let's Encrypt`.

## Installing Cert-Manager

Installing `Cert-Manager` is possible in many [ways](https://docs.cert-manager.io/en/latest/getting-started/install.html). In this tutorial, you will use `Helm` to accomplish the task.

First, change directory (if not already) where you cloned the `Starter Kit` repository:

```shell
cd Kubernetes-Starter-Kit-Developers
```

Next, please add the `Jetstack` Helm repository:

```shell
helm repo add jetstack https://charts.jetstack.io
```

Then, open and inspect the `03-setup-ingress-ambassador/assets/manifests/cert-manager-values-v1.5.4.yaml` file provided in the `Starter Kit` repository, using an editor of your choice (preferably with `YAML` lint support). For example, you can use [VS Code](https://code.visualstudio.com):

```shell
code 03-setup-ingress-ambassador/assets/manifests/cert-manager-values-v1.5.4.yaml
```

Finally, you can install the `jetstack/cert-manager` chart using Helm:

```shell
CERT_MANAGER_HELM_CHART_VERSION="1.5.4"

helm install cert-manager jetstack/cert-manager --version "$CERT_MANAGER_HELM_CHART_VERSION" \
  --namespace cert-manager \
  --create-namespace \
  -f 03-setup-ingress-ambassador/assets/manifests/cert-manager-values-v1.5.4.yaml
```

Check Helm release status:

```shell
helm ls -n cert-manager
```

The output looks similar to (notice the `STATUS` column which has the `deployed` value):

```text
NAME            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
cert-manager    cert-manager    1               2021-10-20 12:13:05.124264 +0300 EEST   deployed        cert-manager-v1.5.4     v1.5.4
```

Inspect `Kubernetes` resources created by the `cert-manager` Helm release:

```shell
kubectl get all -n cert-manager
```

The output looks similar to (notice the `cert-manager` pod and `webhook` service, which should be `UP` and `RUNNING`):

```text
NAME                                           READY   STATUS    RESTARTS   AGE
pod/cert-manager-5ffd4f6c89-ckc9n              1/1     Running   0          10m
pod/cert-manager-cainjector-748dc889c5-l4dbv   1/1     Running   0          10m
pod/cert-manager-webhook-5b679f47d6-4xptd      1/1     Running   0          10m

NAME                           TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
service/cert-manager-webhook   ClusterIP   10.245.227.199   <none>        443/TCP   10m

NAME                                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/cert-manager              1/1     1            1           10m
deployment.apps/cert-manager-cainjector   1/1     1            1           10m
deployment.apps/cert-manager-webhook      1/1     1            1           10m

NAME                                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/cert-manager-5ffd4f6c89              1         1         1       10m
replicaset.apps/cert-manager-cainjector-748dc889c5   1         1         1       10m
replicaset.apps/cert-manager-webhook-5b679f47d6      1         1         1       10m
```

Inspect the available `CRDs`:

```shell
kubectl get crd -l app.kubernetes.io/name=cert-manager
```

The output looks similar to:

```text
NAME                                  CREATED AT
certificaterequests.cert-manager.io   2021-10-20T09:13:15Z
certificates.cert-manager.io          2021-10-20T09:13:15Z
challenges.acme.cert-manager.io       2021-10-20T09:13:16Z
clusterissuers.cert-manager.io        2021-10-20T09:13:17Z
issuers.cert-manager.io               2021-10-20T09:13:18Z
orders.acme.cert-manager.io           2021-10-20T09:13:18Z
```

## Configuring the Ambassador Edge Stack with Cert-Manager

`Cert-Manager` relies on `three` important `CRDs` to issue certificates from a `Certificate Authority` (such as `Let's Encrypt`):

- [Issuer](https://cert-manager.io/docs/concepts/issuer): Defines a `namespaced` certificate issuer, allowing you to use `different CAs` in each `namespace`.
- [ClusterIssuer](https://cert-manager.io/docs/concepts/issuer): Similar to `Issuer`, but it doesn't belong to a namespace, hence can be used to `issue` certificates in `any namespace`.
- [Certificate](https://cert-manager.io/docs/concepts/certificate): Defines a `namespaced` resource that references an `Issuer` or `ClusterIssuer` for issuing certificates.

In this tutorial you will create a `namespaced Issuer` for the `Ambassador` stack.

The way `cert-manager` works is by defining custom resources to handle certificates in your cluster. You start by creating an `Issuer` resource type, which is responsible with the `ACME` challenge process. The `Issuer` CRD also defines the required `provider` (such as `DigitalOcean`), to create `DNS` records during the `DNS-01` challenge.

Then, you create a `Certificate` resource type which makes use of the `Issuer` CRD to obtain a valid certificate from the `CA` (Certificate Authority). The `Certificate` CRD also defines what `Kubernetes Secret` to create and store the final certificate after the `DNS-01` challenge completes successfully. Then, `Ambassador` can consume the `secret`, and use the `wildcard certificate` to enable `TLS` encryption for your `entire` domain.

In the following steps, you will learn how to configure `Ambassador` to use `cert-manager` for `wildcard` certificates support.

**Important note:**

Before continuing with the steps, please make sure that your `DO` domain is set up correctly as explained in [Step 4 - Configuring the DO Domain for Ambassador Edge Stack](../README.md#step-4---configuring-the-do-domain-for-ambassador-edge-stack).

First, you need to create a `Kubernetes Secret` for the [DigitalOcean Provider](https://cert-manager.io/docs/configuration/acme/dns01/digitalocean) that `cert-manager` is going to use to perform the `DNS-01` challenge. The secret must contain your `DigitalOcean API token`, which is needed by the provider to create `DNS` records on your behalf during the `DNS-01` challenge. This step is required, so that the `CA` knows that the `domain` in question is really owned by you.

Create the `Kubernetes` secret containing the `DigitalOcean API` token, using the `ambassador` namespace (must be in the same `namespace` where the `Ambassador Edge Stack` was deployed):

```shell
DO_API_TOKEN="<YOUR_DO_API_TOKEN_HERE>"

kubectl create secret generic "digitalocean-dns" \
  --namespace ambassador \
  --from-literal=access-token="$DO_API_TOKEN"
```

**Important note:**

Because the above `secret` is created in the `ambassador` namespace, please make sure that `RBAC` is set correctly to `restrict` access for `unauthorized` users and applications.

Next, change directory where the `Starter Kit` repository was cloned on your local machine:

```shell
cd Kubernetes-Starter-Kit-Developers
```

Then, open and inspect the `03-setup-ingress-ambassador/assets/manifests/cert-manager-ambassador-issuer.yaml` file provided in the `Starter Kit` repository, using an editor of your choice (preferably with `YAML` lint support). For example, you can use [VS Code](https://code.visualstudio.com) (please replace the `<>` placeholders using a **valid e-mail address**):

```shell
code 03-setup-ingress-ambassador/assets/manifests/cert-manager-ambassador-issuer.yaml
```

**Note:**

Explanations for each of the important `Issuer` CRD fields, can be found inside the [cert-manager-ambassador-issuer.yaml](../assets/manifests/cert-manager-ambassador-issuer.yaml) file.

Save the file and apply changes to your `Kubernetes` cluster using `kubectl`:

```shell
kubectl apply -f 03-setup-ingress-ambassador/assets/manifests/cert-manager-ambassador-issuer.yaml
```

Verify `Issuer` status using `kubectl`:

```shell
kubectl get issuer letsencrypt-ambassador -n ambassador
```

The output looks similar to (notice the `READY` column value - should be `True`):

```text
NAME                     READY   AGE
letsencrypt-ambassador   True    3m32s
```

**Note:**

If the `Issuer` object reports a not ready state for some reason, then you can use `kubectl describe` and inspect the `Status` section from the output. It should tell you the main reason why the `Issuer` failed.

```shell
kubectl describe issuer letsencrypt-ambassador -n ambassador
```

Now, you must create a `Certificate` resource which is referencing the `Issuer` created previously. Open and inspect the `03-setup-ingress-ambassador/assets/manifests/cert-manager-ambassador-certificate.yaml` file provided in the `Starter Kit` repository, using an editor of your choice (preferably with `YAML` lint support). For example, you can use [VS Code](https://code.visualstudio.com):

```shell
code 03-setup-ingress-ambassador/assets/manifests/cert-manager-ambassador-certificate.yaml
```

**Notes:**

- Explanation for each important field of the `Certificate` CRD, can be found inside the [cert-manager-ambassador-certificate.yaml](../assets/manifests/cert-manager-ambassador-certificate.yaml) file.
- The example provided in this tutorial is using `starter-kit.online` domain name (and naming convention). Please make sure to use your own domain name and naming convention.

Next, create the `Certificate` resource in your `DOKS` cluster:

```shell
kubectl apply -f 03-setup-ingress-ambassador/assets/manifests/cert-manager-ambassador-certificate.yaml
```

Verify certificate status:

```shell
kubectl get certificate starter-kit.online -n ambassador
```

The output looks similar to (notice the `READY` column value - should be `True`, and the `SECRET` name):

```text
NAME                 READY   SECRET               AGE
starter-kit.online   True    starter-kit.online   3m8s
```

**Notes:**

- Please bear in mind that it can take a `few minutes` for the process to complete.
- If the `Certificate` object reports a `not ready state` for some reason, then you can fetch the logs from the `Cert-Manager Controller` Pod and see why the `Certificate` failed:

    ```shell
    kubectl logs -l app=cert-manager,app.kubernetes.io/component=controller -n cert-manager
    ```

Inspect the `Kubernetes` secret which contains your `TLS` certificate:

```shell
kubectl describe secret  starter-kit.online -n ambassador
```

The output looks similar to (notice that it contains the `wildcard` certificate `private` and `public` keys):

```text
Name:         starter-kit.online
Namespace:    ambassador
Labels:       <none>
Annotations:  cert-manager.io/alt-names: *.starter-kit.online,starter-kit.online
              cert-manager.io/certificate-name: starter-kit.online
              cert-manager.io/common-name: *.starter-kit.online
              cert-manager.io/ip-sans: 
              cert-manager.io/issuer-group: cert-manager.io
              cert-manager.io/issuer-kind: Issuer
              cert-manager.io/issuer-name: letsencrypt-ambassador
              cert-manager.io/uri-sans: 

Type:  kubernetes.io/tls

Data
====
tls.crt:  5632 bytes
tls.key:  1679 bytes
```

Now, you can use the new secret with Ambassador `Hosts` to enable `TLS` termination on `all domains`. The following snippet shows the `wildcard` configuration for the `Host` CRD:

```yaml
apiVersion: getambassador.io/v2
kind: Host
metadata:
  name: wildcard-host
  namespace: ambassador
spec:
  hostname: "*.starter-kit.online"
  acmeProvider:
    authority: none
  tlsSecret:
    name: starter-kit.online
  selector:
    matchLabels:
      hostname: wildcard-host
```

Explanations for the above configuration:

- `spec.hostname`: Because a wildcard certificate is available, you can use wildcards to match all hosts for a specific domain (e.g.: `*.starter-kit.online`).
- `spec.acmeProvider`: Authority is set to `none`, because you configured an `external` certificate management tool (`cert-manager`).
- `spec.tlsSecret`: Reference to `Kubernetes Secret` containing your `TLS` certificate.

Open and inspect the `03-setup-ingress-ambassador/assets/manifests/wildcard-host.yaml` file provided in the `Starter Kit` repository, using an editor of your choice (preferably with `YAML` lint support). For example, you can use [VS Code](https://code.visualstudio.com):

```shell
code 03-setup-ingress-ambassador/assets/manifests/wildcard-host.yaml
```

Then, after adjusting accordingly, save the file and create the wildcard `Host` resource using `kubectl`:

```shell
kubectl apply -f 03-setup-ingress-ambassador/assets/manifests/wildcard-host.yaml
```

Check that the resource was created:

```shell
kubectl get hosts -n ambassador
```

The output looks similar to (notice the `HOSTNAME` using wildcards now, and the `Ready` state):

```text
NAME            HOSTNAME               STATE   PHASE COMPLETED   PHASE PENDING   AGE
wildcard-host   *.starter-kit.online   Ready                                     84m
```

After applying the `wildcard-host.yaml` manifest, you can go ahead and create the Ambassador `Mappings` for each `backend service` that you're using, as learned in [Step 6 - Configuring the Ambassador Edge Stack Mappings for Hosts](../README.md#step-6---configuring-the-ambassador-edge-stack-mappings-for-hosts).

Testing the new setup goes the same way as you already learned in [Step 8 - Verifying the Ambassador Edge Stack Setup](../README.md#step-8---verifying-the-ambassador-edge-stack-setup).

Please go ahead and navigate using your web browser to one of the example backend services used in this tutorial, and inspect the certificate. The output should look similar to (notice the wildcard certificate `*.starter-kit.online`):

![Starter Kit Online Wildcard Certificate](../assets/images/starter_kit_wildcard_cert.png)

One of the `advantages` of using a `wildcard` certificate is that you need to create **only one** `Host` definition, and then focus on the `Mappings` needed for each `backend application`. The `wildcard` setup takes care `automatically` of all the `hosts` that need to be `managed` under a single `domain`, and have `TLS` termination `enabled`. Also, `certificate renewal` happens automatically for the entire domain, via `cert-manager` and `Let's Encrypt` CA.
