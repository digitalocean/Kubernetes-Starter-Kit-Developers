# How to Encrypt Kubernetes Secrets Using Sealed Secrets

## Introduction

In this tutorial, you will learn how to deploy and `encrypt` generic `Kubernetes Secrets` using the [Sealed Secrets Controller](https://github.com/bitnami-labs/sealed-secrets). What `Sealed Secrets` allows you to do, is to store any `Kubernetes` secret in `Git`, without fearing that `sensitive` data is going to be exposed. Having the `Sealed Secrets Controller` deployed in your `DOKS` cluster, allows you to apply and use `GitOps` principles as well (explained in [Section 15 - Automate Everything using Terraform and Flux CD](../15-automate-with-terraform-flux/README.md)).

### Understanding How Sealed Secrets Work

The `Sealed Secrets Controller` creates generic (classic) `Kubernetes` secrets in your `DOKS` cluster, from sealed secrets manifests. Sealed secrets `decryption` happens `server side` only, so as long as the `DOKS` cluster is secured (`etcd` database), everything should be safe.

There are two components involved:

1. A client side utility called `kubeseal`, used for `encrypting` generic `Kubernetes` secrets. The `kubeseal` CLI uses `asymmetric crypto` to encrypt secrets that `only` the `Sealed Secrets Controller` can `decrypt`.
2. A server side component called `Sealed Secrets Controller` which runs on your `DOKS` cluster, and takes care of `decrypting` sealed secrets objects for applications to use.

The real benefit comes when you use `Sealed Secrets` in a `GitOps` flow. After you `commit` the sealed secret `manifest` to your applications `Git` repository, the `Continuous Delivery` system (e.g. `Flux CD`) is notified about the change, and creates a `Sealed Secret` resource in your `DOKS` cluster. Then the `Sealed Secrets Controller` kicks in, and `decrypts` your sealed secret object back to the original `Kubernetes` secret. Next, applications can consume the secret as usual.

In terms of security, meaning restricting other users to decrypt your sealed secrets inside the cluster, there are three scopes that you can use (`kubeseal` CLI `--scope` flag):

1. `strict` (default): the secret must be sealed with `exactly` the same `name` and `namespace`. These attributes become part of the encrypted data and thus changing name and/or namespace would lead to **"decryption error"**.
2. `namespace-wide`: you can freely `rename` the sealed secret within a given `namespace`.
3. `cluster-wide`: the `secret` can be `unsealed` in any `namespace` and can be given any `name`.

Compared to other solutions, like `Vault` or `KMS` providers, `Sealed Secrets` is neither of those. It's just a way to safely `encrypt` your `Kubernetes Secrets`, so that the same `GitOps` principles can be applied as well when you need to `manage` sensitive data.

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
- [Conclusion](#conclusion)
  - [Pros](#pros)
  - [Cons](#cons)
  - [Learn More](#learn-more)

## Prerequisites

To complete this tutorial, you will need:

1. A [Git](https://git-scm.com/downloads) client, to clone the `Starter Kit` repository.
2. [Kubeseal](https://github.com/bitnami-labs/sealed-secrets/releases/tag/v0.16.0), for encrypting secrets and `Sealed Secrets Controller` interaction.
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

Next, search the `sealed-secrets` repository for available charts to install:

```shell
helm search repo sealed-secrets
```

The output looks similar to:

```text
NAME                            CHART VERSION   APP VERSION     DESCRIPTION                                  
sealed-secrets/sealed-secrets   1.16.1          v0.16.0         Helm chart for the sealed-secrets controller.
```

Now, open and inspect the `08-kubernetes-sealed-secrets/assets/manifests/sealed-secrets-values-v1.16.1.yaml` file provided in the `Starter kit` repository, using an editor of your choice (preferably with `YAML` lint support). You can use [VS Code](https://code.visualstudio.com), for example:

```shell
code 08-kubernetes-sealed-secrets/assets/manifests/sealed-secrets-values-v1.16.1.yaml
```

Next, install the `sealed-secrets/sealed-secrets` chart, using `Helm` (notice that a dedicated `sealed-secrets` namespace is created as well):

```shell
helm install sealed-secrets-controller sealed-secrets/sealed-secrets --version 1.16.1 \
  --namespace sealed-secrets \
  --create-namespace \
  -f 08-kubernetes-sealed-secrets/assets/manifests/sealed-secrets-values-v1.16.1.yaml
```

**Notes:**

- A `specific` version for the `Helm` chart is used. In this case `1.16.1` is picked, which maps to the `0.16.0` version of the application. It’s good practice in general, to lock on a specific version. This helps to have predictable results, and allows versioning control via `Git`.
- You will want to `restrict` access to the sealed-secrets `namespace` for other users that have access to your `DOKS` cluster, to prevent `unauthorized` access to the `private key`.

Next, list the deployment status for `Sealed Secrets` controller (the `STATUS` column value should be `deployed`):

```shell
helm ls -n sealed-secrets
```

The output looks similar to:

```text
NAME                            NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
sealed-secrets-controller       sealed-secrets  1               2021-10-04 18:25:03.594564 +0300 EEST   deployed        sealed-secrets-1.16.1   v0.16.0
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

If you don't specify a `namespace`, the `default` one is assumed (use kubeseal `--namespace` flag, to change targeted namespace). Default `scope` used by `kubeseal` is `strict` - please refer to scopes in [Understanding How Sealed Secrets Work](#understanding-how-sealed-secrets-work).

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

You must take care of sealing the updated items with a compatible name and namespace (see note about scopes above).

You can use the `--merge-into` command to update an existing sealed secrets if you don't want to copy&paste:

```shell
echo -n bar | kubectl create secret generic mysecret --dry-run=client --from-file=foo=/dev/stdin -o json \
  | kubeseal > mysealedsecret.json

echo -n baz | kubectl create secret generic mysecret --dry-run=client --from-file=bar=/dev/stdin -o json \
  | kubeseal --merge-into mysealedsecret.json
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

Best approach is to perform regular backups via `Velero` for example, as you already learned in [Section 6 - Backup Using Velero](../06-setup-velero/README.md). `Velero` helps you to restore the `Sealed Secrets` controller state in case of a disaster as well (without the need to fetch the `master` key, and then `inserting` it back in the `cluster`).

## Conclusion

In this tutorial, you learned how to use generic `Kubernetes secrets` in a `secure` way. You also learned that the `encryption key` is stored and secrets are `decrypted` in the `cluster` (the client doesn’t have access to the encryption key).

Then, you discovered how to use `kubeseal` CLI, to generate `SealedSecret` manifests that hold sensitive content `encrypted`. After `applying` the sealed secrets manifest file to your `DOKS` cluster, the `Sealed Secrets Controller` will recognize it as a new sealed secret resource, and `decrypt` it to generic `Kubernetes Secret` resource.

### Pros

- `Easy` and `transparent` integration with `Kubernetes Secrets`.
- `Decryption` happens `server side` (DOKS cluster).
- Works very well in a `GitOps` setup (`encrypted` files can be stored using `public Git` repositories).

### Cons

- For `each DOKS cluster` a separate `private` and `public key` pair needs to be `created` and `maintained`.
- `Private keys` must be `backed` up (e.g. using `Velero`) for `disaster` recovery.
- `Updating` and `re-sealing` secrets (`adding` or `merging` new key/values) is not quite straightforward.

Even though there are some cons to using `Sealed Secrets`, the `transparent` integration with `Kubernetes` and `GitOps` flows makes it a good candidate in practice.

### Learn More

- [Secret rotation](https://github.com/bitnami-labs/sealed-secrets#secret-rotation) best practices.
- [Upgrade](https://github.com/bitnami-labs/sealed-secrets#upgrade) steps and notes.
- [Sealed Secrets FAQ](https://github.com/bitnami-labs/sealed-secrets#faq), for frequently asked questions about `Sealed Secrets`.

Go to [Section 14 - Starter Kit Resource Usage](../14-starter-kit-resource-usage/README.md).
