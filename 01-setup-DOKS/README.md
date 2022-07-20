# How to Set Up a DigitalOcean Managed Kubernetes Cluster (DOKS)

## Introduction

In this tutorial, you will learn how set up a `DigitalOcean` managed [Kubernetes](https://docs.digitalocean.com/products/kubernetes) cluster (`DOKS`), using the `command-line` interface. Then, you're going to `inspect` the cluster `state`, as well as the available `features`.

After completing this tutorial, you will be able to:

- Use the [doctl](https://docs.digitalocean.com/reference/doctl) command, to create and manage `DOKS` clusters.
- Inspect `DOKS` clusters state.

**Note:**
As an alternative to this chapter, you can use the DOKS UI to create a cluster. UI is easy to understand and very convenient as well.

## Table of contents

- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Step 1 - Doctl CLI Introduction](#step-1---doctl-cli-introduction)
- [Step 2 - Authenticating to DigitalOcean API](#step-2---authenticating-to-digitalocean-api)
- [Step 3 - Creating the DOKS Cluster](#step-3---creating-the-doks-cluster)
- [Step 4 [OPTIONAL] - Adding a dedicated node for observability](#step-4-optional---adding-a-dedicated-node-for-observability)
- [Conclusion](#conclusion)

## Prerequisites

To complete this tutorial, you will need:

1. A DigitalOcean [account](https://docs.digitalocean.com/products/getting-started/#sign-up), for accessing the `DigitalOcean` platform.
2. A DigitalOcean [personal access token](https://docs.digitalocean.com/reference/api/create-personal-access-token), for using the `DigitalOcean` API.
3. [Doctl](https://docs.digitalocean.com/reference/doctl/how-to/install) utility, for managing `DigitalOcean` resources using the `command-line` interface.
4. [Kubectl](https://kubernetes.io/docs/tasks/tools), for `Kubernetes` cluster interaction.

## Step 1 - Doctl CLI Introduction

In this step, you will learn how to use the `doctl` utility, and explore the available options for the `DigitalOcean` platform. The way `Doctl` works, is by using `commands` and `sub-commands`, to create and manage `DigitalOcean` resources. You can get `help` for each via the `--help` flag.

Next, you're going to explore the doctl `auth` command and `sub-commands`.

Please open a terminal, and type the following command to list all the available options for `doctl`:

```shell
doctl --help
```

The output looks similar to:

```text
doctl is a command line interface (CLI) for the DigitalOcean API.

Usage:
  doctl [command]

Available Commands:
  1-click         Display commands that pertain to 1-click applications
  account         Display commands that retrieve account details
  apps            Display commands for working with apps
  auth            Display commands for authenticating doctl with an account
  balance         Display commands for retrieving your account balance
  billing-history Display commands for retrieving your billing history
  completion      Modify your shell so doctl commands autocomplete with TAB
  compute         Display commands that manage infrastructure
  databases       Display commands that manage databases
  help            Help about any command
  invoice         Display commands for retrieving invoices for your account
  kubernetes      Displays commands to manage Kubernetes clusters and configurations
  monitoring      [Beta] Display commands to manage monitoring
  projects        Manage projects and assign resources to them
  registry        Display commands for working with container registries
  version         Show the current version
  vpcs            Display commands that manage VPCs
  ...
```

Next, inspect the `auth` command help page:

```shell
doctl auth --help
```

The output looks similar to (some parts are hidden for simplicity):

```text
The `doctl auth` commands allow you to authenticate doctl for use with your DigitalOcean account using tokens that you generate in the control panel at https://cloud.digitalocean.com/account/api/tokens.
...

Usage:
  doctl auth [command]

Available Commands:
  init        Initialize doctl to use a specific account
  list        List available authentication contexts
  remove      Remove authentication contexts 
  switch      Switches between authentication contexts
  ...
```

Then, see what options are available for the `list` sub-command (part of the `doctl auth` command):

```shell
doctl auth list --help
```

The output looks similar to:

```text
List named authentication contexts that you created with `doctl auth init`.

To switch between the contexts use `doctl switch <name>`, where `<name>` is one of the contexts listed.

To create new contexts, see the help for `doctl auth init`.

Usage:
  doctl auth list [flags]
...
```

In the next step, you're going to learn how to `authenticate` to DigitalOcean `API` with `doctl`, to `create` and `manage` resources on the `DigitalOcean` platform.

## Step 2 - Authenticating to DigitalOcean API

`Doctl` needs to authenticate with DigitalOcean `API` to perform `queries`, and `create` resources on your behalf, hence an `access token` is needed (`Step #2` from [Prerequisites](#prerequisites)). For each `command` or `sub-command` that you run, `doctl` performs an `API` call to `DigitalOcean`.

To authenticate `doctl` with DigitalOcean `API`, you can use the `auth` command of `doctl`.

First, list the available options for the `auth` command:

```shell
doctl auth -h
```

The output looks similar to:

```text
...
Usage:
  doctl auth [command]

Available Commands:
  init        Initialize doctl to use a specific account
  list        List available authentication contexts
  remove      Remove authentication contexts 
  switch      Switches between authentication contexts
```

Next, you're going to use the `init` sub-command for `doctl auth`, to perform the initialization (when asked, please enter the personal access token created in the [Prerequisites](#prerequisites) step):

```shell
doctl auth init
```

The output looks similar to:

```text
Please authenticate doctl for use with your DigitalOcean account. You can generate a token in the control panel at https://cloud.digitalocean.com/account/api/tokens

Enter your access token: <paste_your_personal_token_here>

Validating token... OK
```

Finally, check that your account is configured for `doctl` to use:

```shell
doctl auth list
```

The output looks similar to (notice the line containing `(current)`):

```text
default
doks-starterkit (current)
```

Next, you're going to learn how to spin up a `DOKS` cluster, and explore the available options.

## Step 3 - Creating the DOKS Cluster

In this step, you will learn how to use the `doctl k8s` command to create a `DOKS` cluster.

First, explore the available `doctl` commands for managing `DOKS` clusters:

- `Manage` a `DOKS` cluster:

    ```shell
    doctl k8s -h
    ```

- List available `options` for a `DOKS` cluster, like: `region`, `size` and `version`:
  
  ```shell
  doctl k8s options -h
  ```

- List what `regions` are available to use, when creating a `DOKS` cluster:

  ```shell
  doctl k8s options regions
  ```

- List machine `sizes` that can be used in a `DOKS` cluster:

  ```shell
  doctl k8s options sizes
  ```

- List `Kubernetes` versions that can be used with `DigitalOcean` clusters:

  ```shell
  doctl k8s options versions
  ```

- Display commands for managing `Kubernetes` clusters:

  ```shell
  doctl k8s cluster -h
  ```

Next, you're going to focus on the `create` sub-command of `doctl k8s cluster`. Inspect the available options via:

```shell
doctl k8s cluster create -h
```

For the `Starter Kit` tutorial, you will need a `DOKS` cluster with `3 worker nodes` . Use `--wait false`, if you do not want the command to wait until cluster is ready.

The below example is using `4cpu/8gb` AMD nodes (`$48/month`), `3` default, and auto-scale to `2-4`. So, your cluster cost is between `$96-$192/month`, with `hourly` billing. To choose a different `node type`, pick from the following command `doctl compute size list`.

```shell
doctl k8s cluster create starterkit-cluster-2 \
  --auto-upgrade=false \
  --maintenance-window "saturday=21:00" \
  --node-pool "name=basicnp;size=s-4vcpu-8gb-amd;count=3;tag=cluster2;label=type=basic;auto-scale=true;min-nodes=2;max-nodes=4" \
  --region nyc1
```

The output looks similar to:

```text
Notice: Cluster is provisioning, waiting for cluster to be running
..................................................................
Notice: Cluster created, fetching credentials
Notice: Adding cluster credentials to kubeconfig file found in "/Users/starterkit/.kube/config"
Notice: Setting current-context to starterkit-cluster-2
ID                                      Name                  Region    Version        Auto Upgrade    Status     Node Pools
0922a629-7f2e-4bda-940c-4d42a3f987ad    starterkit-cluster-2  nyc1      1.21.5-do.0    false           running    basicnp
```

Next, you can verify the cluster details. First, fetch your `DOKS` cluster `ID`:

```shell
doctl k8s cluster list
```

The output looks similar to (notice the `ID` column value):

```text
ID                                      Name                  Region    Version        Auto Upgrade    Status     Node Pools
b4ddaa2e-8c0c-4fd8-b249-cbf99eda0808    starterkit-cluster-2  nyc1      1.21.5-do.0    false           running    basicnp
```

Now, query the DigitalOcean `API`, using [curl](https://curl.se/download.html) (please make sure to replace the `<>` placeholders accordingly)

```shell
curl -X GET \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <your_do_api_token>" \
  https://api.digitalocean.com/v2/kubernetes/clusters/<cluster_id>
```

Finally, check if the `kubectl` context was set to point to your `DOKS` cluster. The `doctl` utility does it automatically for you in general, but it's good to know if something goes bad.

```shell
kubectl config current-context
```

The output looks similar to:

```text
starterkit-cluster-2
```

If the above command output is empty or different, you can use the `kubeconfig` sub-command of `doctl k8s cluster` to set `kubectl` context.

First, list the available `DOKS` clusters:

```shell
doctl k8s cluster list
```

The output looks similar to:

```text
ID                                      Name                  Region    Version        Auto Upgrade    Status     Node Pools
b4ddaa2e-8c0c-4fd8-b249-cbf99eda0808    starterkit-cluster-2  nyc1      1.21.5-do.0    false           running    basicnp
```

Next, set `kubectl` context to point to your cluster:

```shell
doctl kubernetes cluster kubeconfig save <your_cluster_name>
```

The output looks similar to:

```text
Notice: Adding cluster credentials to kubeconfig file found in "/Users/starterkit/.kube/config"
Notice: Setting current-context to starterkit-cluster-2
```

Finally, list `DOKS` cluster nodes:

```shell
kubectl get nodes
```

The output looks similar to:

```text
NAME            STATUS   ROLES    AGE     VERSION
basicnp-865x3   Ready    <none>   2m55s   v1.21.5
basicnp-865x8   Ready    <none>   2m21s   v1.21.5
basicnp-865xu   Ready    <none>   2m56s   v1.21.5
```

If everything was set correctly, you should get a list of all the `DOKS` cluster worker `nodes`. The `STATUS` column should print `Ready`, if all the nodes are `healthy`.

**Hint:**
If the worker node(s) `STATUS` is different from `Ready`, you can inspect the affected node(s), via (please replace the `<>` placeholders accordingly):

```shell
kubectl describe node <worker_node_name>
```

After running the above command, please look at the `Events` section (last line from command output), to check if something went wrong. There are many other useful sections to look at, like `Conditions`, `System Info`, `Allocated resources`, to help you troubleshoot worker nodes issues in the future.

## Step 4 [OPTIONAL] - Adding a dedicated node for observability

If you plan to use this cluster to serve in a production environment it is recommended that you also setup, apart from the basic nodes, another fixed size node pool with the purpose of serving the observability stack from [Chapter 4 - 04-setup-prometheus-stack](../04-setup-prometheus-stack/README.md).
In general, it is good practice to separate the observability stack from user applications. This way, one cannot interfere with another or get affected by downtime when performing cluster or node pool maintenance, etc.
On the other hand, monitoring is a crucial aspect of any modern infrastructure hence high-availability is a must.
Later on, you will use [Node affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity) to schedule `observability` related pods on the dedicated node pool.

To add another node pool to the cluster created earlier run the following command:

```shell
doctl kubernetes cluster node-pool create starterkit-cluster-2 \
    --name "observability" \
    --size "s-4vcpu-8gb-amd" \
    --min-nodes 1 \
    --max-nodes 1 \
    --count 1
```

The ouput looks similar to:

```text
ID                                      Name             Size                    Count    Tags                                                   
7b5037c8-637c-4a8b-abbe-3296b5aa92fa    observability    s-4vcpu-8gb-amd         1        k8s,k8s:1dcda264-15d6-4bcb-92b1-e64d236f59c1,k8s:worker      
```

Next check the cluster's nodes created:

```shell
kubectl get nodes
```

The output looks similar to (notice the `observability` prefix in the node name):

```text
NAME                    STATUS   ROLES    AGE     VERSION
basicnp-c4k0f           Ready    <none>   2m34s   v1.22.11
basicnp-c4k0q           Ready    <none>   2m38s   v1.22.11
basicnp-c4k0y           Ready    <none>   2m38s   v1.22.11
observability-cd111     Ready    <none>   2m44s   v1.22.11
```

Next you will add a label to the new node. This will make it easier to schedule pods onto this node using a distinct label and node affinity.

```shell
kubectl label nodes <YOUR_NODE_NAME> preferred=observability
```

Verify that your node has a `preferred=observability` label:

```shell
kubectl get nodes <YOUR_NODE_NAME> --show-labels
```

The output looks similar to (notice the `preferred=observability` label):

```text
NAME                  STATUS   ROLES    AGE     VERSION   LABELS
observability-cd111   Ready    <none>   9m27s   v1.22.8   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/instance-type=s-4vcpu-8gb-amd,beta.kubernetes.io/os=linux,doks.digitalocean.com/node-id=eb199834-a852-40fe-9785-42c361536ec0,doks.digitalocean.com/node-pool-id=92e14637-73d1-4703-a902-11fef09ca4f2,doks.digitalocean.com/node-pool=observability,doks.digitalocean.com/version=1.22.8-do.1,failure-domain.beta.kubernetes.io/region=nyc3,kubernetes.io/arch=amd64,kubernetes.io/hostname=observability-cd111,kubernetes.io/os=linux,node.kubernetes.io/instance-type=s-4vcpu-8gb-amd,preferred=observability,region=nyc3,topology.kubernetes.io/region=nyc3
```

## Conclusion

In this tutorial you learned how to use the `doctl` utility, inspect the available `options`, as well as how to get `help` for a specific `command` or `sub-command`. Then, you learned how to create a `DOKS` cluster, and `inspect` worker nodes `state`.

In the next section, you will learn how to use the `DigitalOcean Container Registry` (DOCR), to easily `store` and manage `private` container `images` for your `Kubernetes` cluster.

Go to [Section 2 - Setting up DOCR](../02-setup-DOCR/README.md).
