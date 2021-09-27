# How to Set up DigitalOcean Container Registry

## Introduction

In this tutorial, you will learn to set up [DigitalOcean Container Registry](https://docs.digitalocean.com/products/container-registry), to securely store and distribute your `Docker` application images.

You need a container registry configured, such as `Docker Hub` or `DigitalOcean Container Registry` (DOCR), when you need to build container `images`. Then, you configure `DOKS` how to pull and use container images from your private `Docker` registry.

After finishing this tutorial, you will be able to:

- Create and manage `DOCR` repositories.
- Set up `DOKS` how to use your private `DOCR` repositories.

## Table of Contents

- [Introduction](#introduction)
- [Step 1 - Creating a DOCR Repository](#step-1---creating-a-docr-repository)
- [Step 2 - Configuring DOKS for Private Registries](#step-2---configuring-doks-for-private-registries)
- [Conclusion](#conclusion)

## Step 1 - Creating a DOCR Repository

In this step, you will learn how to create a basic `DOCR` repository for your `DOKS` cluster, using the `doctl` utility. You need to have `doctl` and `kubectl` context configured - please refer to [Step 2 - Authenticating to DigitalOcean API](../01-setup-DOKS/README.md#step-2---authenticating-to-digitalocean-api) and [Step 3 - Creating the DOKS Cluster](../01-setup-DOKS/README.md#step-3---creating-the-doks-cluster) from the `DOKS` setup tutorial.

First, explore the available `options` for working with `DOCR` repositories, via `doctl`:

```shell
doctl registry -h
```

The output looks similar to:

```text
The subcommands of `doctl registry` create, manage, and allow access to your private container registry.

Usage:
  doctl registry [command]

Aliases:
  registry, reg, r

Available Commands:
  create              Create a private container registry
  delete              Delete a container registry
  docker-config       Generate a docker auth configuration for a registry
  garbage-collection  Display commands for garbage collection for a container registry
  get                 Retrieve details about a container registry
  kubernetes-manifest Generate a Kubernetes secret manifest for a registry.
  login               Log in Docker to a container registry
  logout              Log out Docker from a container registry
  options             List available container registry options
  repository          Display commands for working with repositories in a container registry
  ...
```

To complete this step of the tutorial, you will focus on the `create` sub-command, to create a basic `private` container `registry`:

```shell
doctl registry create starterkit-reg-1 --subscription-tier basic
```

The output looks similar to:

```text
Name                Endpoint
starterkit-reg-1    registry.digitalocean.com/starterkit-reg-1
```

**Note:**

You can have only `1` registry endpoint per `account` in `DOCR`. A `repository` in a `registry` refers to a collection of `container images` using different versions (`tags`).

## Step 2 - Configuring DOKS for Private Registries

Given that the `DOCR` registry is a `private` endpoint, you need to configure the `DOKS` cluster to fetch images from the registry:

```shell
doctl registry kubernetes-manifest | kubectl apply -f -
```

The above command creates a `Kubernetes` secret for you, in the `default` namespace.

Next, verify that the `secret` was `created`:

```shell
kubectl get secrets registry-starterkit-reg-1
```

The output looks similar to:

```text
NAME                        TYPE                             DATA   AGE
registry-starterkit-reg-1   kubernetes.io/dockerconfigjson   1      13s
```

Then, your application `Pods` can reference it using `imagePullSecrets`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: starterkit-app
  spec:
  replicas: 3
  template:
    metadata:
      labels:
        app: starterkit-app
        spec:
        containers:
        - name: starterkit-app
        image: registry.digitalocean.com/myregistry/myimage
        imagePullSecrets:
        - name: registry-starterkit-reg-1
...
```

You can modify the `default` service account to always use the secret as an `imagePullSecret` when creating `Pods` or `Deployments`:

```shell
kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "registry-starterkit-reg-1"}]}'
```

Finally, verify the `default` service account configuration:

```shell
kubectl get serviceaccount default -o yaml
```

The output looks similar to (verify that the `imagePullSecrets` points to `registry-starterkit-reg-1`):

```yaml
apiVersion: v1
imagePullSecrets:
- name: registry-starterkit-reg-1
kind: ServiceAccount
metadata:
  creationTimestamp: "2021-09-17T12:05:46Z"
  name: default
  namespace: default
  resourceVersion: "2017370"
  uid: 677b1ef4-3cb5-418f-b798-9029a5641561
secrets:
- name: default-token-zbvww
```

From then on, any new `Pods` will have this `automatically` added to their `spec`:

```yaml
...
spec:
    imagePullSecrets:
    - name: registry-starterkit-reg-1
...
```

For more information on `patching` the `default` service account to use `imagePullSecrets`, consult the [Kubernetes documentation](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#add-imagepullsecrets-to-a-service-account).

## Conclusion

In this tutorial, you learned how to create a private `DOCR` registry for your `DOKS` cluster. Then, you learned how to `patch` secrets for `DOKS` to `securely` authenticate, and pull `Docker` images for your `applications` running in the cluster.

Next, you will learn how to set up the `Ambassador Edge Stack` to act as an `Ingress` controller, as well as some example `backend` applications to test the setup.

Go to [Section 3 - Ingress using Ambassador](../03-setup-ingress-ambassador/README.md).
