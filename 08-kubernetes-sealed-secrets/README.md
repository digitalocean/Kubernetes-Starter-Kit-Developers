# How to Encrypt Kubernetes Secrets Using Sealed Secrets

## Introduction

In this tutorial, you will learn how to deploy and `encrypt` generic `Kubernetes Secrets` using the [Sealed Secrets Controller](https://github.com/bitnami-labs/sealed-secrets).

What `Sealed Secrets` allows you to do is:

- Store `encrypted` secrets in a `Git` repository (even in `public` ones).
- Apply `GitOps` principles for `Kubernetes Secrets` as well ([Section 15 - Continuous Delivery using GitOps](../15-continuous-delivery-using-gitops/README.md) gives you more practical examples on this topic).

### Understanding How Sealed Secrets Work

The `Sealed Secrets Controller` creates generic (classic) `Kubernetes` secrets in your `DOKS` cluster, from sealed secrets manifests. Sealed secrets `decryption` happens `server side` only, so as long as the `DOKS` cluster is secured (`etcd` database, `RBAC` properly set), everything should be safe.

There are two components involved:

1. A client side utility called `kubeseal`, used for `encrypting` generic `Kubernetes` secrets. The `kubeseal` CLI uses `asymmetric crypto` to encrypt secrets that `only` the `Sealed Secrets Controller` can `decrypt`.
2. A server side component called `Sealed Secrets Controller` which runs on your `DOKS` cluster, and takes care of `decrypting` sealed secrets objects for applications to use.

The real benefit comes when you use `Sealed Secrets` in a `GitOps` flow. After you `commit` the sealed secret `manifest` to your applications `Git` repository, the `Continuous Delivery` system (e.g. `Flux CD`) is notified about the change, and creates a `Sealed Secret` resource in your `DOKS` cluster. Then the `Sealed Secrets Controller` kicks in, and `decrypts` your sealed secret object back to the original `Kubernetes` secret. Next, applications can consume the secret as usual.

Compared to other solutions like `Vault`, Sealed Secrets lacks the following features:

- `Multiple` storage backend support (like `Consul`, `S3`, `Filesystem`, `SQL databases`, etc).
- `Dynamic Secrets`: Sealed Secrets cannot create application credentials on `demand` for accessing other systems, like `S3` compatible storage (e.g. `DO Spaces`), and `automatically revoke credentials` later on, when the `lease` expires.
- `Leasing` and `renewal` of secrets: Sealed Secrets doesn't provide a `client API` for `renewing leases`, nor does it provide a `lease` associated to each `secret`.
- `Revoking` old keys/secrets: Sealed Secrets can `rotate` the encryption key `automatically`, but it's quite limited in this regard. **Old keys and secrets are not revoked automatically - you have to manually revoke the old key(s) and re-seal everything again.**
- `Pluggable` architecture which extends existing functionality like, setting `ACLs` via `identity based access control` plugins (`Okta`, `AWS`, etc).

Although `Vault` is more feature capable, it comes with a tradeoff: `increased complexity` and `costs` in terms of maintenance. Where `Sealed Secrets` really shines is: `simplicity` and `low` maintenance `overhead` and `costs`.

For `enterprise` grade `production` or `HIPAA` compliant systems, `Vault` is definitely one of the best candidates. For `small` projects and `development` environments, `Sealed Secrets` will suffice in most of the cases.

After finishing this tutorial, you will be able to:

- `Create` and deploy sealed `Kubernetes` secrets to your `DOKS` cluster.
- `Manage` and `update` sealed secrets.
- `Configure` sealed secrets `scope`.

### Sealed Secrets Controller Setup Overview

![Sealed Secrets Controller Setup Overview](assets/images/sealed_secrets_flow.png)

## Table of Contents

- [Introduction](#introduction)
  - [Understanding How Sealed Secrets Work](#understanding-how-sealed-secrets-work)
  - [Sealed Secrets Controller Setup Overview](#sealed-secrets-controller-setup-overview)
- [Prerequisites](#prerequisites)
- [Step 1 - Installing the Sealed Secrets Controller](#step-1---installing-the-sealed-secrets-controller)
- [Step 2 - Encrypting a Kubernetes Secret](#step-2---encrypting-a-kubernetes-secret)
- [Step 3 - Managing Sealed Secrets](#step-3---managing-sealed-secrets)
  - [Managing Existing Secrets](#managing-existing-secrets)
  - [Updating Existing Secrets](#updating-existing-secrets)
- [Step 4 - Sealed Secrets Controller Private Key Backup](#step-4---sealed-secrets-controller-private-key-backup)
- [Security Best Practices](#security-best-practices)
- [Conclusion](#conclusion)
  - [Pros](#pros)
  - [Cons](#cons)
  - [Learn More](#learn-more)

## Prerequisites

To complete this tutorial, you will need:

1. A [Git](https://git-scm.com/downloads) client, to clone the `Starter Kit` repository.
2. [Kubeseal](https://github.com/bitnami-labs/sealed-secrets/releases/tag/v0.18.1), for encrypting secrets and `Sealed Secrets Controller` interaction.
3. [Helm](https://www.helms.sh), for managing `Sealed Secrets Controller` releases and upgrades.
4. [Kubectl](https://kubernetes.io/docs/tasks/tools), for `Kubernetes` interaction.

## Step 1 - Installing the Sealed Secrets Controller

In this step, you will learn how to deploy the `Sealed Secrets Controller` using `Helm`. The chart of interest is called `sealed-secrets` and it's provided by the `bitnami-labs` repository.

First, clone the `Starter Kit` Git repository, and change directory to your local copy:

```shell
git clone https://github.com/digitalocean/Kubernetes-Starter-Kit-Developers.git

cd Kubernetes-Starter-Kit-Developers
```

Then, add the sealed secrets `bitnami-labs` repository for `Helm`:

```shell
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
```

Next, update the `sealed-secrets` chart repository:

```shell
helm repo update sealed-secrets
```

Next, search the `sealed-secrets` repository for available charts to install:

```shell
helm search repo sealed-secrets
```

The output looks similar to:

```text
NAME                            CHART VERSION   APP VERSION     DESCRIPTION
sealed-secrets/sealed-secrets   2.4.0           v0.18.1         Helm chart for the sealed-secrets controller.
```

Now, open and inspect the `08-kubernetes-sealed-secrets/assets/manifests/sealed-secrets-values-v2.4.0.yaml` file provided in the `Starter kit` repository, using an editor of your choice (preferably with `YAML` lint support). You can use [VS Code](https://code.visualstudio.com), for example:

```shell
code 08-kubernetes-sealed-secrets/assets/manifests/sealed-secrets-values-v2.4.0.yaml
```

Next, install the `sealed-secrets/sealed-secrets` chart, using `Helm` (notice that a dedicated `sealed-secrets` namespace is created as well):

```shell
HELM_CHART_VERSION="2.4.0"

helm install sealed-secrets-controller sealed-secrets/sealed-secrets --version "${HELM_CHART_VERSION}" \
  --namespace sealed-secrets \
  --create-namespace \
  -f "08-kubernetes-sealed-secrets/assets/manifests/sealed-secrets-values-v${HELM_CHART_VERSION}.yaml"
```

**Notes:**

- A `specific` version for the `Helm` chart is used. In this case `2.4.0` is picked, which maps to the `0.18.1` version of the application. It’s good practice in general, to lock on a specific version. This helps to have predictable results, and allows versioning control via `Git`.
- You will want to `restrict` access to the sealed-secrets `namespace` for other users that have access to your `DOKS` cluster, to prevent `unauthorized` access to the `private key` (e.g. use `RBAC` policies).

Next, list the deployment status for `Sealed Secrets` controller (the `STATUS` column value should be `deployed`):

```shell
helm ls -n sealed-secrets
```

The output looks similar to:

```text
NAME                            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                  APP VERSION
sealed-secrets-controller       sealed-secrets  1               2021-10-04 18:25:03.594564 +0300 EEST   deployed        sealed-secrets-2.4.0   v0.18.1
```

Finally, inspect the `Kubernetes` resources created by the `Sealed Secrets` Helm deployment:

```shell
kubectl get all -n sealed-secrets
```

The output looks similar to (notice the status of the `sealed-secrets-controller` pod and service - must be `UP` and `Running`):

```text
NAME                                             READY   STATUS    RESTARTS   AGE
pod/sealed-secrets-controller-7b649d967c-mrpqq   1/1     Running   0          2m19s

NAME                                TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
service/sealed-secrets-controller   ClusterIP   10.245.105.164   <none>        8080/TCP   2m20s

NAME                                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/sealed-secrets-controller   1/1     1            1           2m20s

NAME                                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/sealed-secrets-controller-7b649d967c   1         1         1       2m20s
```

In the next step you will learn how to `seal` your `secrets`. Only `your DOKS` cluster can `decrypt` the sealed secrets, because it's the only one having the `private` key.

## Step 2 - Encrypting a Kubernetes Secret

In this step, you will learn how to encrypt your generic `Kubernetes` secret, using `kubeseal` CLI. Then, you will deploy it to your `DOKS` cluster and see how the `Sealed Secrets` controller `decrypts` it for your applications to use.

Suppose that you need to seal a generic secret for your application, saved in the following file: `your-app-secret.yaml`. Notice the `your-data` field which is `base64` encoded (it's `vulnerable` to attacks, because it can be very easily `decoded` using free tools):

```yaml
apiVersion: v1
data:
  your-data: ZXh0cmFFbnZWYXJzOgogICAgRElHSVRBTE9DRUFOX1RPS0VOOg== # base64 encoded application data
kind: Secret
metadata:
  name: your-app
```

First, you need to fetch the `public key` from the `Sealed Secrets Controller` (performed `only once` per cluster, and on each `fresh` install):

```shell
kubeseal --fetch-cert --controller-namespace=sealed-secrets > pub-sealed-secrets.pem
```

**Notes:**

- If you deploy the `Sealed Secrets` controller to another namespace (defaults to `kube-system`), you need to specify to the `kubeseal` CLI the namespace, via the `--controller-namespace` flag.
- The `public key` can be `safely` stored in a `Git` repository for example, or even given to the world. The encryption mechanism used by the `Sealed Secrets` controller cannot be reversed without the `private key` (stored in your `DOKS` cluster only).

Next, create a `sealed` file from the `Kubernetes` secret, using the `pub-sealed-secrets.pem` key:

```shell
kubeseal --format=yaml \
  --cert=pub-sealed-secrets.pem \
  --secret-file your-app-secret.yaml \
  --sealed-secret-file your-app-sealed.yaml
```

The file content looks similar to (notice the `your-data` field which is `encrypted` now, using a Bitnami `SealedSecret` object):

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  creationTimestamp: null
  name: your-app
  namespace: default
spec:
  encryptedData:
    your-data: AgCFNTLd+KD2IGZo3YWbRgPsK1dEhxT3NwSCU2Inl8A6phhTwMxKSu82fu0LGf/AoYCB35xrdPl0sCwwB4HSXRZMl2WbL6HrA0DQNB1ov8DnnAVM+6TZFCKePkf9yqVIekr4VojhPYAvkXq8TEAxYslQ0ppNg6AlduUZbcfZgSDkMUBfaczjwb69BV8kBf5YXMRmfGtL3mh5CZA6AAK0Q9cFwT/gWEZQU7M1BOoMXUJrHG9p6hboqzyEIWg535j+14tNy1srAx6oaQeEKOW9fr7C6IZr8VOe2wRtHFWZGjCL3ulzFeNu5GG0FmFm/bdB7rFYUnUIrb2RShi1xvyNpaNDF+1BDuZgpyDPVO8crCc+r2ozDnkTo/sJhNdLDuYgIzoQU7g1yP4U6gYDTE+1zUK/b1Q+X2eTFwHQoli/IRSv5eP/EAVTU60QJklwza8qfHE9UjpsxgcrZnaxdXZz90NahoGPtdJkweoPd0/CIoaugx4QxbxaZ67nBgsVYAnikqc9pVs9VmX/Si24aA6oZbtmGzkc4b80yi+9ln7x/7/B0XmyLNLS2Sz0lnqVUN8sfvjmehpEBDjdErekSlQJ4xWEQQ9agdxz7WCSCgPJVnwA6B3GsnL5dleMObk7eGUj9DNMv4ETrvx/ZaS4bpjwS2TL9S5n9a6vx6my3VC3tLA5QAW+GBIfRD7/CwyGZnTJHtW5f6jlDWYS62LbFJKfI9hb8foR/XLvBhgxuiwfj7SjjAzpyAgq
  template:
    data: null
    metadata:
      creationTimestamp: null
      name: your-app
      namespace: default
```

**Note:**

If you don't specify a `namespace`, the `default` one is assumed (use kubeseal `--namespace` flag, to change targeted namespace). Default `scope` used by `kubeseal` is `strict` - please refer to scopes in [Security Best Practices](#security-best-practices).

Next, you can delete the `Kubernetes` secret file, because it's not needed anymore:

```shell
rm -f your-app-secret.yaml
```

Finally, `deploy` the `sealed secret` to your cluster:

```shell
kubectl apply -f your-app-sealed.yaml
```

Check that the `Sealed Secrets Controller` decrypted your `Kubernetes` secret in the `default` namespace:

```shell
kubectl get secrets
```

The output looks similar to:

```text
NAME                  TYPE                                  DATA   AGE
your-app              Opaque                                1      31s
```

Inspect the secret:

```shell
kubectl get secret your-app -o yaml
```

The output looks similar to (`your-data` key `value` should be `decrypted` to the original `base64` encoded `value`):

```yaml
apiVersion: v1
data:
  your-data: ZXh0cmFFbnZWYXJzOgogICAgRElHSVRBTE9DRUFOX1RPS0VOOg==
kind: Secret
metadata:
  creationTimestamp: "2021-10-05T08:34:07Z"
  name: your-app
  namespace: default
  ownerReferences:
  - apiVersion: bitnami.com/v1alpha1
    controller: true
    kind: SealedSecret
    name: your-app
    uid: f6475e74-78eb-4c6a-9f19-9d9ceee231d0
  resourceVersion: "235947"
  uid: 7b7d2fee-c48a-4b4c-8f16-2e58d25da804
type: Opaque
```

## Step 3 - Managing Sealed Secrets

### Managing Existing Secrets

If you want `SealedSecret` controller to take management of an `existing` Secret (i.e. overwrite it when unsealing a SealedSecret with the same name and namespace), then you have to `annotate` that `Secret` with the annotation `sealedsecrets.bitnami.com/managed: "true"` ahead applying [Step 2 - Encrypting a Kubernetes Secret](#step-2---encrypting-a-kubernetes-secret).

### Updating Existing Secrets

If you want to `add` or `update` existing sealed secrets without having the cleartext for the other items, you can just `copy&paste` the new encrypted data items and `merge` it into an `existing` sealed secret.

You must take care of sealing the updated items with a compatible `name` and `namespace` (see note about scopes above).

You can use the `--merge-into` command to update an existing sealed secrets if you don't want to copy&paste:

```shell
echo -n bar | kubectl create secret generic mysecret --dry-run=client --from-file=foo=/dev/stdin -o json \
  | kubeseal --controller-namespace=sealed-secrets > mysealedsecret.json

echo -n baz | kubectl create secret generic mysecret --dry-run=client --from-file=bar=/dev/stdin -o json \
  | kubeseal --controller-namespace=sealed-secrets --merge-into mysealedsecret.json
```

If using `VS Code` there's an extension that allows you to use the `GUI` mode to perform the above operations - [Kubeseal for vscode](https://marketplace.visualstudio.com/items?itemName=codecontemplator.kubeseal).

## Step 4 - Sealed Secrets Controller Private Key Backup

If you want to perform a `manual backup` of the private and public keys, you can do so via:

```shell
kubectl get secret -n sealed-secrets -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > master.key
```

Then, store the `master.key` file somewhere safe. To restore from a backup after some disaster, just put that secrets back before starting the controller - or if the controller was already started, replace the newly-created secrets and restart the controller:

```shell
kubectl apply -f master.key

kubectl delete pod -n sealed-secrets -l name=sealed-secrets-controller
```

Best approach is to perform regular backups for example, as you already learned in [Section 6 - Set up Backup and Restore](../06-setup-backup-restore/README.md). `Velero` or `Trilio` helps you to restore the `Sealed Secrets` controller state in case of a disaster as well (without the need to fetch the `master` key, and then `inserting` it back in the `cluster`).

## Security Best Practices

In terms of security, `Sealed Secrets` allows you to `restrict` other users to decrypt your sealed secrets inside the cluster. There are three `scopes` that you can use (`kubeseal` CLI `--scope` flag):

1. `strict` (default): the secret must be sealed with `exactly` the same `name` and `namespace`. These `attributes` become `part` of the `encrypted data` and thus `changing name` and/or `namespace` would lead to **"decryption error"**.
2. `namespace-wide`: you can freely `rename` the sealed secret within a given `namespace`.
3. `cluster-wide`: the `secret` can be `unsealed` in any `namespace` and can be given any `name`.

Next, you can apply some of the best practices highlighted below:

- Make sure to change **both** `secrets` periodically (like passwords, tokens, etc), and the `private key` used for `encryption`. This way, if the `encryption key` is ever `leaked`, sensitive data doesn't get exposed. And even if it is, the secrets are not valid anymore. You can read more on the topic by referring to the [Secret Rotation](https://github.com/bitnami-labs/sealed-secrets#secret-rotation) chapter, from the official documentation.
- You can leverage the power of `RBAC` for your `Kubernetes` cluster to `restrict` access to `namespaces`. So, if you store all your Kubernetes secrets in a `specific namespace`, then you can `restrict` access to `unwanted users` and `applications` for that `specific namespace`. This is important, because plain `Kubernetes Secrets` are `base64` encoded and can be `decoded` very easy by anyone. `Sealed Secrets` provides an `encryption` layer on top of `encoding`, but in your `DOKS` cluster sealed secrets are transformed back to `generic` Kubernetes secrets.
- To avoid `private key leaks`, please make sure that the `namespace` where you deployed the `Sealed Secrets` controller is protected as well, via corresponding `RBAC` rules.

## Conclusion

In this tutorial, you learned how to use generic `Kubernetes secrets` in a `secure` way. You also learned that the `encryption key` is stored and secrets are `decrypted` in the `cluster` (the client doesn’t have access to the encryption key).

Then, you discovered how to use `kubeseal` CLI, to generate `SealedSecret` manifests that hold sensitive content `encrypted`. After `applying` the sealed secrets manifest file to your `DOKS` cluster, the `Sealed Secrets Controller` will recognize it as a new sealed secret resource, and `decrypt` it to generic `Kubernetes Secret` resource.

### Pros

- `Lightweight`, meaning implementation and management costs are low.
- `Transparent` integration with `Kubernetes Secrets`.
- `Decryption` happens `server side` (DOKS cluster).
- Works very well in a `GitOps` setup (`encrypted` files can be stored using `public Git` repositories).

### Cons

- For `each DOKS cluster` a separate `private` and `public key` pair needs to be `created` and `maintained`.
- `Private keys` must be `backed` up (e.g. using `Velero`) for `disaster` recovery.
- `Updating` and `re-sealing` secrets, as well as `adding` or `merging` new key/values is not quite straightforward.

Even though there are some cons to using `Sealed Secrets`, the `ease` of `management` and `transparent` integration with `Kubernetes` and `GitOps` flows makes it a good candidate in practice.

### Learn More

- [Upgrade](https://github.com/bitnami-labs/sealed-secrets#upgrade) steps and notes.
- [Sealed Secrets FAQ](https://github.com/bitnami-labs/sealed-secrets#faq), for frequently asked questions about `Sealed Secrets`.

Next, you will learn how to automatically scale your application workloads based on external load (or traffic). You will learn how to leverage `metrics-server` as well as `Prometheus` via `prometheus-adapter` to do the job, and let the Kubernetes horizontal (or vertical) Pod autoscaling system take smart decisions.

Go to [Section 9 - Scaling Application Workloads](../09-scaling-application-workloads/README.md).
