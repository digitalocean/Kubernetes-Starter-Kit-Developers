# Automate Everything using Terraform and Flux CD

## Introduction

[Terraform](https://www.terraform.io) helps you create and automate the running infrastructure, like your `Kubernetes` cluster. Then, [Flux CD](https://fluxcd.io) helps you `synchronize` the `state` of your infrastructure using `Git` as the source of truth, and follow `GitOps` principles.

In this tutorial, you will learn to:

- Use `Terraform` modules, to automate all the steps required to provision your infrastructure.
- Create `Flux CD` resources, to keep your `Kubernetes` cluster applications state synchronized with a `Git` repository (use `GitOps` principles).

After finishing all the steps from this tutorial, you should have a fully functional `DOKS` cluster with `Flux CD` deployed, that will:

- Handle cluster reconciliation, via the [Source Controller](https://fluxcd.io/docs/components/source/).
- Handle `Helm` releases, via the [Helm Controller](https://fluxcd.io/docs/components/helm).

### DOKS and Flux CD Automation Overview

![DOKS-FluxCD-Automation-Overview](assets/images/tf_fluxcd_automation.png)

## Table of Contents

- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Step 1 - Initializing the Terraform Backend](#step-1---initializing-the-terraform-backend)
- [Step 2 - Bootstrapping DOKS and Flux CD](#step-2---bootstrapping-doks-and-flux-cd)
- [Step 3 - Inspecting DOKS Cluster and Flux CD State](#step-3---inspecting-doks-cluster-and-flux-cd-state)
  - [DOKS Cluster](#doks-cluster)
  - [Flux CD](#flux-cd)
- [Step 4 - Introducing Sealed Secrets Controller](#step-4---introducing-sealed-secrets-controller)
- [Step 5 - Creating Flux CD Helm Releases](#step-5---creating-flux-cd-helm-releases)
  - [Cloning the Flux CD Git Repository and Preparing the Layout](#cloning-the-flux-cd-git-repository-and-preparing-the-layout)
  - [Creating the Sealed Secrets Helm Release](#creating-the-sealed-secrets-helm-release)
  - [Creating the Ambassador Helm Release](#creating-the-ambassador-helm-release)
  - [Creating the Prometheus Stack Helm Release](#creating-the-prometheus-stack-helm-release)
  - [Creating the Loki Stack Helm Release](#creating-the-loki-stack-helm-release)
  - [Creating the Velero Helm Release](#creating-the-velero-helm-release)
- [Conclusion](#conclusion)

## Prerequisites

To complete this tutorial, you will need:

1. A [GitHub](https://github.com) repository and `branch`, for `Flux CD` to store your cluster and sample application `manifests`.

   **Important note:**

   **The GitHub `repository` (and `branch`) must be created beforehand - the DigitalOcean Terraform module used in this tutorial doesn't provision one for you automatically.**
2. A GitHub [personal access token](https://github.com/settings/tokens) that has the `repo` permissions set. The `Terraform` module used in this tutorial, needs it in order to create the `SSH` deploy key, as well as to commit the `Flux CD` manifests in your `Git` repository.
3. A `DigitalOcean` access token, for creating/managing the `DOKS` cluster. Please follow the official `DigitalOcean` tutorial on how to [create a personal access token](https://docs.digitalocean.com/reference/api/create-personal-access-token). Copy the `token` value and save it somewhere safe.
4. Access keys, for [DigitalOcean Spaces](https://cloud.digitalocean.com/spaces) (S3-compatible object storage). Please follow the official `DigitalOcean` tutorial on how to [manage access keys](https://docs.digitalocean.com/products/spaces/how-to/manage-access/). We use `Spaces` for storing the `Terraform` state file. Copy the `key` and `secret` value, and save each in a local `environment` variable for later use (make sure to replace the `<>` placeholders accordingly):

    ```shell
    export DO_SPACES_ACCESS_KEY="<YOUR_DO_SPACES_ACCESS_KEY>"
    export DO_SPACES_SECRET_KEY="<YOUR_DO_SPACES_SECRET_KEY>"
    ```

5. A `DO Spaces` bucket, for storing the `Terraform` state file. Please follow the official `DigitalOcean` tutorial on how to [create one](https://docs.digitalocean.com/products/spaces/how-to/create). Make sure that it is set to `restrict file listing` for security reasons.
6. A [git client](https://git-scm.com/downloads), for cloning the `Starter Kit` repository.
7. HashiCorp [Terraform](https://www.terraform.io/downloads.html) CLI, for provisioning the infrastructure.
8. [Doctl](https://github.com/digitalocean/doctl/releases) CLI, for `DigitalOcean` API interaction.
9. [Kubectl](https://kubernetes.io/docs/tasks/tools) CLI, for `Kubernetes` interaction.
10. [Flux](https://fluxcd.io/docs/installation) CLI, for `Flux CD` interaction.
11. [Kubeseal](https://github.com/bitnami-labs/sealed-secrets/releases/tag/v0.16.0), for encrypting secrets and `Sealed Secrets Controller` interaction.

## Step 1 - Initializing the Terraform Backend

In this step, you're going to initialize the `Terraform` backend. A `DO Spaces` bucket for storing the `Terraform` state file is highly recommended because you do not have to worry about exposing `sensitive` data, as long as the space is `private` of course. Another advantage is that the `state` of your `infrastructure` is backed up, so you can re-use it when the `workspace` is lost. Having a `shared` space for team members is desired as well, in order to perform `collaborative` work via `Terraform`.

First, clone the `Starter Kit` Git repository on your local machine, and navigate to the `terraform` directory:

```shell
git clone https://github.com/digitalocean/Kubernetes-Starter-Kit-Developers.git

cd Kubernetes-Starter-Kit-Developers/15-automate-with-terraform-flux/assets/terraform
```

Next, rename the provided `backend.tf.sample` file to `backend.tf`:

```shell
cp backend.tf.sample backend.tf
```

Then, open it using a text editor of your choice (preferably with `Terraform` lint support), and replace the `<>` placeholders accordingly (explanations for each can be found inside). For example, you can use [VS Code](https://code.visualstudio.com):

```shell
code backend.tf
```

Finally, initialize the `Terraform` backend. You're going to use the previously created `DO Spaces` access and secret keys:

```shell
terraform init  --backend-config="access_key=$DO_SPACES_ACCESS_KEY" --backend-config="secret_key=$DO_SPACES_SECRET_KEY"
```

The output looks similar to the following (check the following message: `Successfully configured the backend "s3"!`):

```text
Initializing the backend...

Successfully configured the backend "s3"! Terraform will automatically
use this backend unless the backend configuration changes.

Initializing provider plugins...
- Finding hashicorp/kubernetes versions matching "2.3.2"...
- Finding gavinbunney/kubectl versions matching "1.11.2"...
...
```

In the next step, you will create the `DOKS` cluster and provision `Flux CD`, using `Terraform`.

## Step 2 - Bootstrapping DOKS and Flux CD

In this step, you're going to use a custom `Terraform` module provided by DigitalOcean - [DOKS-FluxCD](https://github.com/digitalocean/container-blueprints/tree/main/create-doks-with-terraform-flux), to provision your `Kubernetes` cluster and deploy `Flux CD`.

First, change sub-directory (if not already) to `terraform`, from where the `Starter Kit` repository was cloned on your local machine:

```shell
cd Kubernetes-Starter-Kit-Developers/15-automate-with-terraform-flux/assets/terraform
```

Next, rename the provided `main.tf.sample` file to `main.tf`:

```shell
cp main.tf.sample main.tf
```

Then, open the `main.tf` file using an editor of your choice (preferably with `Terraform` lint support), and replace the `<>` placeholders accordingly (explanations for each can be found inside). For example, you can use [VS Code](https://code.visualstudio.com):

```shell
code main.tf
```

Next, run `Terraform` and inspect infrastructure changes:

```shell
terraform plan -out starter_kit_flux_cluster.out
```

Finally, if everything looks good, apply changes using `Terraform`:

```shell
terraform apply "starter_kit_flux_cluster.out"
```

After running above steps, you should have a fully functional `Kubernetes` cluster and `Flux CD` deployed. In the next step, you're going to inspect the state of your `DOKS` cluster, as well as `Flux CD`.

## Step 3 - Inspecting DOKS Cluster and Flux CD State

If everything went well, the `DOKS` cluster should be up and running, as well as `Flux CD`:

![DOKS state](assets/images/doks_created.png)

Check that the `Terraform` state file is saved in your [DO Spaces](https://cloud.digitalocean.com/spaces) bucket. Bucket listing looks similar to:

![DO Spaces Terraform state file](assets/images/tf_state_s3.png)

The Flux CD `manifests` for your `DOKS` cluster should be present in your `Git` repository as well:

![GIT repo state](assets/images/flux_git_res.png)

### DOKS Cluster

First, you have to set the `kubectl` context to point to your cluster. List the available `Kubernetes` clusters first:

```shell
doctl k8s cluster list
```

Point `kubectl` to your cluster (make sure to replace the `<>` placeholders accordingly):

```shell
doctl k8s cluster kubeconfig save <your_doks_cluster_name>
```

Please check that the context was set, and that it's pointing to your `Kubernetes` cluster:

```shell
kubectl config get-contexts
```

List cluster nodes, and make sure that they're in a healthy state (`STATUS` column says `Ready`):

```shell
kubectl get nodes
```

The output looks similar to:

```text
NAME                             STATUS   ROLES    AGE    VERSION
test-fluxcd-cluster-pool-8z9df   Ready    <none>   3d2h   v1.21.3
test-fluxcd-cluster-pool-8z9dq   Ready    <none>   3d2h   v1.21.3
test-fluxcd-cluster-pool-8z9dy   Ready    <none>   3d2h   v1.21.3
```

### Flux CD

`Flux` is the `CLI` tool used for `Flux CD` provisioning, as well as for main system interaction. You can perform some `sanity checks` via:

```shell
flux check
```

The output looks similar to the following:

```text
► checking prerequisites
✔ kubectl 1.21.3 >=1.18.0-0
✔ Kubernetes 1.21.2 >=1.16.0-0
► checking controllers
✗ helm-controller: deployment ready
► ghcr.io/fluxcd/helm-controller:v0.11.1
✔ kustomize-controller: deployment ready
► ghcr.io/fluxcd/kustomize-controller:v0.13.1
✔ notification-controller: deployment ready
► ghcr.io/fluxcd/notification-controller:v0.15.0
✔ source-controller: deployment ready
► ghcr.io/fluxcd/source-controller:v0.15.3
✔ all checks passed
```

Inspect all `Flux CD` resources with:

```shell
flux get all
```

The output looks similar to the following (long commit hashes were abbreviated in the output, for simplicity). Notice the `flux-system` git repository component fetching the latest revision from your main branch, as well as the `kustomization`:

```text
NAME                      READY MESSAGE                        REVISION      SUSPENDED 
gitrepository/flux-system True  Fetched revision: main/1d69... main/1d69...  False     

NAME                      READY MESSAGE                        REVISION      SUSPENDED 
kustomization/flux-system True  Applied revision: main/1d69... main/1d69c... False  
```

In case you need to perform some troubleshooting, and also see what `Flux CD` is doing, you can access the logs via:

```shell
flux logs
```

The output looks similar to the following:

```text
...
2021-07-20T12:31:36.696Z info GitRepository/flux-system.flux-system - Reconciliation finished in 1.193290329s, next run in 1m0s 
2021-07-20T12:32:37.873Z info GitRepository/flux-system.flux-system - Reconciliation finished in 1.176637507s, next run in 1m0s 
...
```

Check that `Flux CD` points to your `Git` repository:

```shell
kubectl get gitrepositories.source.toolkit.fluxcd.io -n flux-system
```

The output looks similar to (notice the `URL` column value - should point to your `Git` repository, and the `READY` state set to `True`):

```text
NAME         URL                                                       READY  STATUS                          AGE
flux-system  ssh://git@github.com/test-starterkit/starterkit_fra1.git  True   Fetched revision: main/1d69...  21h
```

In the next step, you will be shortly introduced to the `Sealed Secrets Controller`.

## Step 4 - Introducing Sealed Secrets Controller

`Sealed Secrets` allows you to `encrypt` generic `Kubernetes` secrets and `store` them `safely` in `Git` (even in `public` repositories). Then, `Flux CD` will create a corresponding Sealed Secret `object` in your cluster for each `Kubernetes secret` stored in `Git`. Sealed secrets controller notices the sealed objects, and decrypts each to a classic Kubernetes secret. Applications can consume the secrets as usual.

### Flux CD Sealed Secrets GitOps Flow

![Flux CD Sealed Secrets GitOps Flow](./assets/images/fluxcd_sealed_secrets.png)

For more details, please refer to [Section 08 - Encrypt Kubernetes Secrets Using Sealed Secrets](../08-kubernetes-sealed-secrets/README.md).

**Important note:**

**Each Flux CD `HelmRelease` can read `values` from a values file directly, or by using a `Kubernetes Secret/ConfigMap`. `Sealed Secrets` controller can create Kubernetes secrets, so it's a good candidate. By design, `HelmReleases` expect a Kubernetes secret that has a `single` key under the `data` field representing the `whole values.yaml` file - this is important to know !**

In the next step, you will create `Flux CD` manifests for each `component` of the `Starter Kit` tutorial, and `seal` each Helm `values` file containing `sensitive` data.

## Step 5 - Creating Flux CD Helm Releases

In this step, you will create manifests that tell `Flux` where to look and fetch the `Helm` chart for each `Starter Kit` component (like `Ambassador`, `Prometheus`, `Loki`, etc), as well as how to `install` the corresponding `Helm` chart.

Each manifest you will create, represents a Kubernetes `CRD`:

- [HelmRepository](https://fluxcd.io/docs/components/source/helmrepositories), for use with `Helm` chart repositories.
- [HelmRelease](https://fluxcd.io/docs/components/helm/helmreleases), for performing the actual `Helm` chart install (`release`).

In `Flux CD`, the desired state of a `Helm` release is described through a `Kubernetes` Custom Resource named `HelmRelease`. Based on the creation, mutation or removal of a `HelmRelease` resource in the cluster, `Helm` actions are performed by the [Helm Controller](https://fluxcd.io/docs/components/helm/).

Each `HelmRelease` makes use of a `source` type, so that it knows where to pull the `Helm` chart from.

Other supported source types:

- [GitRepository](https://fluxcd.io/docs/components/source/gitrepositories) for use with `Git` repositories.
- [S3 Bucket](https://fluxcd.io/docs/components/source/buckets) for use with `S3` compatible buckets.

### Cloning the Flux CD Git Repository and Preparing the Layout

Before continuing with the tutorial, please make sure that the following steps are performed before anything else:

1. First, clone your Flux CD `Git` repository (please replace the `<>` placeholders accordingly). This is the main repository used for your `DOKS` cluster reconciliation.

   ```shell
   git clone https://github.com/<github_user>/<git_repository_name>.git
   ```

    Explanations for the above command:

    - `<github_user>` - your GitHub username as defined in `main.tf` file
    - `<git_repository_name>` - your Flux CD Github repository as defined in `main.tf` file

2. Next, change directory where your `Git` repository was cloned (please replace the `<>` placeholders accordingly):

    ```shell
    cd <git_repository_name>
    ```

3. Then, checkout your `<git_repository_branch>` (please replace the `<>` placeholders accordingly):

    ```shell
    git checkout <git_repository_branch>
    ```

    Explanations for the above command:

    - `<git_repository_branch>` - your `Git` branch for storing `Flux CD` cluster manifests as defined in `main.tf` file

4. Now, create the `directory structure` to store `HelmRepository`, `HelmRelease` and `SealedSecret` manifests for each component of the `Starter Kit` (please replace the `<>` placeholders accordingly):

    ```shell
    HELM_MANIFESTS_PATH="<git_repository_sync_path>/helm"
    HELM_REPOSITORIES_PATH="${HELM_MANIFESTS_PATH}/repositories"
    HELM_RELEASES_PATH="${HELM_MANIFESTS_PATH}/releases"
    HELM_SECRETS_PATH="${HELM_MANIFESTS_PATH}/secrets"

    mkdir -p "$HELM_REPOSITORIES_PATH" "$HELM_RELEASES_PATH" "$HELM_SECRETS_PATH"
    ```

    Explanations for the above command:

    - `<git_repository_sync_path>` - your `Flux CD` cluster directory path as defined in `main.tf` file.
5. Finally, create the `.gitignore` file to `avoid` committing `unencrypted` Helm value files in the repository, which may contain sensitive data (please adjust the `exclusion/inclusion pattern` based on your `naming convention` - the below patterns use `Starter Kit` conventions):

   ```shell
   # Ignore all YAML files containing `-values-` string
   echo '*-values-*.yaml' >> .gitignore

   # Do not ignore sealed YAML files though 
   echo '!*-values-*sealed*.yaml' >> .gitignore

   git add .gitignore
   
   git commit -m "Avoid committing unencrypted Helm value files"
   ```

Next, you're going to use the `flux` CLI to create a `HelmRelease` for each component of the `Starter Kit`. Each `HelmRelease` requires a set of manifests created, and committed in your `Git` repository which targets your `DOKS` cluster. Then, for each `HelmRelease` a corresponding `Kubernetes Secret` will be created as well, to store Helm `values`. Each `Kubernetes Secret` will be `encrypted` beforehand using `Sealed Secrets` and stored in `Git`, to follow the same `GitOps` principles as for `HelmReleases`.

After finishing all the steps in this tutorial, you should have a `Git` repository structure similar to:

```text
├── README.md
├── clusters
│   └── dev
│       ├── flux-system
│       │   ├── gotk-components.yaml
│       │   ├── gotk-sync.yaml
│       │   └── kustomization.yaml
│       └── helm
│           ├── releases
│           │   ├── ambassador-v6.7.13.yaml
│           │   ├── kube-prometheus-stack-v17.1.3.yaml
│           │   ├── loki-stack-v2.4.1.yaml
│           │   ├── sealed-secrets-v1.16.1.yaml
│           │   └── velero-v2.23.6.yaml
│           ├── repositories
│           │   ├── ambassador.yaml
│           │   ├── grafana.yaml
│           │   ├── prometheus-community.yaml
│           │   ├── sealed-secrets.yaml
│           │   └── vmware-tanzu.yaml
│           └── secrets
│               ├── ambassador-values-v6.7.13-sealed.yaml
│               ├── loki-stack-values-v2.4.1-sealed.yaml
│               ├── prom-stack-values-v17.1.3-sealed.yaml
│               └── velero-values-v2.23.6-sealed.yaml
└── pub-sealed-secrets-flux-test-cluster.pem
```

You're going to start with the `Sealed Secrets` Helm release first, because it's a prerequisite for the rest of the `Starter Kit` components.

### Creating the Sealed Secrets Helm Release

In this section, you will learn how to create the `Flux CD` manifests which define the `Sealed Secrets` Helm release. Then, `Flux` performs a `Helm` release for you, on each `Git` change for the affected resource (`Sealed Secrets`, in this case).

Please use the following steps, to create the `Sealed Secrets` Helm release:

1. First, create the `Sealed Secrets` HelmRepository `source` for `Flux`:

    ```shell
    flux create source helm sealed-secrets \
      --url="https://bitnami-labs.github.io/sealed-secrets" \
      --interval="10m" \
      --export > "${HELM_REPOSITORIES_PATH}/sealed-secrets.yaml"
    ```

    Explanations for the above command:

    - `<url>` - Helm repository address.
    - `<interval>` - source sync interval (default `1m0s`).
    - `<export>` - export in `YAML` format to stdout.

2. Then, fetch the `Starter Kit` values file for `Sealed Secrets`. Please make sure to inspect the `Sealed Secrets` values file, and replace the `<>` placeholders where needed:

    ```shell
    SEALED_SECRETS_CHART_VERSION="1.16.1"

    curl "https://raw.githubusercontent.com/digitalocean/Kubernetes-Starter-Kit-Developers/1.21/08-kubernetes-sealed-secrets/assets/manifests/sealed-secrets-values-v${SEALED_SECRETS_CHART_VERSION}.yaml" > "sealed-secrets-values-v${SEALED_SECRETS_CHART_VERSION}.yaml"
    ```

3. Now, create the `Sealed Secrets` HelmRelease for `Flux`. `Kubeseal` CLI expects by default to find the controller in the `kube-system` namespace and to be called `sealed-secrets-controller`, hence we override the values via `--release-name` and `--target-namespace` flags (this is not mandatory, it just makes `kubeseal` CLI usage much more friendlier):

    ```shell
    SEALED_SECRETS_CHART_VERSION="1.16.1"

    flux create helmrelease "sealed-secrets-controller" \
      --release-name="sealed-secrets-controller" \
      --source="HelmRepository/sealed-secrets" \
      --chart="sealed-secrets" \
      --chart-version "$SEALED_SECRETS_CHART_VERSION" \
      --values="sealed-secrets-values-v${SEALED_SECRETS_CHART_VERSION}.yaml" \
      --target-namespace="flux-system" \
      --crds=CreateReplace \
      --export > "${HELM_RELEASES_PATH}/sealed-secrets-v${SEALED_SECRETS_CHART_VERSION}.yaml"
    ```

    Explanations for the above command:

    - `<release-name>` - what name to use for the Helm release (defaults to `<target-namespace>-<HelmRelease-name>` otherwise).
    - `<source>` - source that contains the chart in the format `<kind>/<name>.<namespace>`, where kind must be one of: (`HelmRepository`, `GitRepository`, `Bucket`).
    - `<chart>` - Helm chart name.
    - `<chart-version>` -  Helm chart version.
    - `<values>` - local path to values file.
    - `<target-namespace>` - namespace to install this release.
    - `--crds` - upgrade CRDs policy, available options are: (`Skip`, `Create`, `CreateReplace`).
    - `<export>` - export in `YAML` format to stdout.
4. Finally, commit your changes and push to remote (please replace `<your_cluster_name>` placeholder first):

    ```shell
    SEALED_SECRETS_CHART_VERSION="1.16.1"

    git add "${HELM_REPOSITORIES_PATH}/sealed-secrets.yaml"

    git add "${HELM_RELEASES_PATH}/sealed-secrets-v${SEALED_SECRETS_CHART_VERSION}.yaml"

    git commit -am "Added the Sealed Secrets Helm repository and release for <your_cluster_name> cluster"

    git push origin
    ```

After completing the above steps, `Flux` will start your `DOKS` cluster `reconciliation` (after `one minute` or so, if using the `default` interval). If you don't want to wait, you can always `force` reconciliation via:

```shell
flux reconcile source git flux-system
```

After a few moments, please inspect the `Sealed Secrets` stack resources created for `Flux CD`:

```shell
flux get helmrelease sealed-secrets-controller
```
  
The output looks similar to:

```text
NAME                        READY   MESSAGE                                 REVISION        SUSPENDED 
sealed-secrets-controller   True    Release reconciliation succeeded        1.16.1          False 
```

Look for the `READY` column value - it should say `True`. Reconciliation status is displayed in the `MESSAGE` column, along with the `REVISION` number, which represents the `Helm` chart `version`.

**Notes:**

- In case something goes wrong, you can search the `Flux` logs and filter `HelmRelease` messages only:

    ```shell
    flux logs --kind=HelmRelease
    ```

- Please bear in mind that some releases take longer to complete (like `Prometheus` stack, for example), so please be patient.

### Exporting Sealed Secrets Controller Public Key

To be able to `encrypt` secrets, you need the `public key` that was created when `Flux CD` deployed your `Sealed Secrets Controller` to `DOKS` (please replace the `<>` placeholders accordingly):

```shell
kubeseal --controller-namespace=flux-system --fetch-cert > pub-sealed-secrets-<your_doks_cluster_name_here>.pem

git add pub-sealed-secrets-<your_doks_cluster_name_here>.pem

git commit -m "Adding Sealed Secrets public key for cluster <your_doks_cluster_name_here>"

git push origin
```

**Notes:**

- If for some reason the `kubeseal` certificate fetch command hangs (something is blocking the sealed secrets service, like a firewall), then you can use the following (please replace the `<>` placeholders accordingly):

    ```shell
    # Expose the Sealed Secrets Controller service in background (you can use `fg` followed by `CTRL - C` to terminate)
    kubectl port-forward service/sealed-secrets-controller 8080:8080 -n flux-system &

    # Fetch the public certificate
    curl --retry 5 --retry-connrefused localhost:8080/v1/cert.pem > pub-sealed-secrets-<your_doks_cluster_name_here>.pem
    ```

- The exported public key is `cluster` specific, so please make sure to save it in the `Git` repository used for synchronizing the cluster. This way you can refer to it later on, when needed. It's `safe` to store the `Sealed Secrets` controller `public key` in your `Git` repository, because it's useless without the `private` key which stays in your `DOKS` cluster.

Next, you're going to perform similar steps to define `Helm` releases for the remaining components of the `Starter Kit`. Please make sure that you stay in the same directory where your personal `Git` repository was cloned, and that the `HELM_MANIFESTS_PATH` environment variable is set (defined at [Cloning the Flux CD Git Repository and Preparing the Layout](#cloning-the-flux-cd-git-repository-and-preparing-the-layout)).

### Creating the Ambassador Helm Release

In this section, you will learn how to create the `Flux CD` manifests which define the `Ambassador` Helm release. Then, `Flux` performs a `Helm` release for you, on each `Git` change for the affected resource (`Ambassador`, in this case).

Please use the following steps, to create the `Ambassador` Helm release:

1. First, create the `Ambassador` HelmRepository `source` for `Flux`:

    ```shell
    flux create source helm ambassador \
      --url="https://www.getambassador.io" \
      --interval="10m" \
      --export > "${HELM_REPOSITORIES_PATH}/ambassador.yaml"
    ```

    Explanations for the above command:

    - `<url>` - Helm repository address.
    - `<interval>` - source sync interval (default `1m0s`).
    - `<export>` - export in `YAML` format to stdout.

2. Then, fetch the `Starter Kit` values file for `Ambassador`. Please make sure to inspect the `Ambassador` values file, and replace the `<>` placeholders where needed:

    ```shell
    AMBASSADOR_CHART_VERSION="6.7.13"

    curl "https://raw.githubusercontent.com/digitalocean/Kubernetes-Starter-Kit-Developers/1.21/03-setup-ingress-ambassador/assets/manifests/ambassador-values-v${AMBASSADOR_CHART_VERSION}.yaml" > "ambassador-values-v${AMBASSADOR_CHART_VERSION}.yaml"
    ```

    **Note:**

    Please **do not commit Ambassador Edge Stack values file using Git**, because it may contain `sensitive` data. Instead, you will create a `Kubernetes Secret` containing the `values` file data, and `encrypt` using `Sealed Secrets`. Then, you will use it to `configure` the Ambassador Edge Stack `HelmRelease`.
3. Next, `create` and `encrypt` the Kubernetes secret for the Ambassador Edge Stack `HelmRelease` to consume (please replace the `<>` placeholders accordingly):

   ```shell
   AMBASSADOR_CHART_VERSION="6.7.13"
   SEALED_SECRETS_PUB_KEY="pub-sealed-secrets-<your_doks_cluster_name_here>.pem"

   kubectl create secret generic "ambassador-values-v${AMBASSADOR_CHART_VERSION}" \
      --namespace flux-system \
      --from-file=values.yaml="ambassador-values-v${AMBASSADOR_CHART_VERSION}.yaml" \
      --dry-run=client -o yaml | kubeseal --cert="${SEALED_SECRETS_PUB_KEY}" \
      --format=yaml > "${HELM_SECRETS_PATH}/ambassador-values-v${AMBASSADOR_CHART_VERSION}-sealed.yaml"
   ```

   Explanations for the above command:

   - First, you fetch the `Sealed Secrets Controller public key` - needed by `kubeseal` to `encrypt` your data.
   - Then, `kubectl create secret` is invoked to generate the secret file in YAML format (`-o yaml`), on your local machine (`--dry-run=client`).
   - Finally, the Kubernetes secret `YAML` output is piped to `kubeseal`, and tell it to use your cluster public key (`--cert=pub-sealed-secrets.pem`) to encrypt the result.
4. Now, create the `Ambassador` HelmRelease for `Flux`:

    ```shell
    AMBASSADOR_CHART_VERSION="6.7.13"

    flux create helmrelease "ambassador-stack" \
      --source="HelmRepository/ambassador" \
      --chart="ambassador" \
      --chart-version "$AMBASSADOR_CHART_VERSION" \
      --values-from="Secret/ambassador-values-v${AMBASSADOR_CHART_VERSION}" \
      --target-namespace="ambassador" \
      --create-target-namespace \
      --export > "${HELM_RELEASES_PATH}/ambassador-v${AMBASSADOR_CHART_VERSION}.yaml"
    ```

    Explanations for the above command:

    - `<source>` - source that contains the chart in the format `<kind>/<name>.<namespace>`, where kind must be one of: (`HelmRepository`, `GitRepository`, `Bucket`).
    - `<chart>` - Helm chart name.
    - `<chart-version>` -  Helm chart version.
    - `<values-from>` - Kubernetes `Secret/ConfigMap` reference that contains the `values.yaml` data key.
    - `<target-namespace>` - namespace to install this release.
    - `<create-target-namespace>` - create the target namespace if it does not exist.
    - `<export>` - export in `YAML` format to stdout.
5. Finally, commit your changes and push to remote (please replace `<your_cluster_name>` placeholder first):

    ```shell
    AMBASSADOR_CHART_VERSION="6.7.13"

    git add "${HELM_REPOSITORIES_PATH}/ambassador.yaml"

    git add "${HELM_RELEASES_PATH}/ambassador-v${AMBASSADOR_CHART_VERSION}.yaml"

    git add "${HELM_SECRETS_PATH}/ambassador-values-v${AMBASSADOR_CHART_VERSION}-sealed.yaml"

    git commit -am "Added Flux CD Ambassador manifests for <your_cluster_name> cluster"

    git push origin
    ```

After completing the above steps, `Flux` will start your `DOKS` cluster `reconciliation` (after `one minute` or so, if using the `default` interval). If you don't want to wait, you can always `force` reconciliation via:

```shell
flux reconcile source git flux-system
```

After a few moments, please inspect the `Ambassador` stack resources created for `Flux CD`:

```shell
flux get helmrelease ambassador-stack
```
  
The output looks similar to:

```text
NAME                    READY   MESSAGE                                 REVISION        SUSPENDED 
ambassador-stack        True    Release reconciliation succeeded        6.7.13          False 
```

Look for the `READY` column value - it should say `True`. Reconciliation status is displayed in the `MESSAGE` column, along with the `REVISION` number, which represents the `Helm` chart `version`.

**Notes:**

- In case something goes wrong, you can search the `Flux` logs and filter `HelmRelease` messages only:

    ```shell
    flux logs --kind=HelmRelease
    ```

- Please bear in mind that some releases take longer to complete (like `Prometheus` stack, for example), so please be patient.

Please refer to the [03-setup-ingress-ambassador](../03-setup-ingress-ambassador/README.md) tutorial, for checking the `Ambassador Edge Stack` deployment status and functionality.

Next, you're going to create the manifests for `Prometheus` stack, and let `Flux CD` handle the `Helm` release automatically.

### Creating the Prometheus Stack Helm Release

In this section, you will create the `Prometheus` stack `Helm` release manifests for `Flux` to use, and automatically deploy it to your `DOKS` cluster.

Steps to follow:

1. First, create the `Prometheus` HelmRepository `source` for `Flux`:

    ```shell
    flux create source helm prometheus-community \
      --url="https://prometheus-community.github.io/helm-charts" \
      --interval="10m" \
      --export > "${HELM_REPOSITORIES_PATH}/prometheus-community.yaml"
    ```

    Explanations for the above command:

    - `<url>` - Helm repository address.
    - `<interval>` - source sync interval (default `1m0s`).
    - `<export>` - export in `YAML` format to stdout.

2. Then, fetch the `Starter Kit` values file for `Prometheus`. Please make sure to inspect the `Prometheus` values file, and replace the `<>` placeholders where needed:

    ```shell
    PROMETHEUS_CHART_VERSION="17.1.3"

    curl "https://raw.githubusercontent.com/digitalocean/Kubernetes-Starter-Kit-Developers/1.21/04-setup-prometheus-stack/assets/manifests/prom-stack-values-v${PROMETHEUS_CHART_VERSION}.yaml" > "prom-stack-values-v${PROMETHEUS_CHART_VERSION}.yaml"
    ```

3. Next, `create` and `encrypt` the Kubernetes secret for the Prometheus Stack `HelmRelease` to consume (please replace the `<>` placeholders accordingly):

   ```shell
   PROMETHEUS_CHART_VERSION="17.1.3"
   SEALED_SECRETS_PUB_KEY="pub-sealed-secrets-<your_doks_cluster_name_here>.pem"

   kubectl create secret generic "prom-stack-values-v${PROMETHEUS_CHART_VERSION}" \
      --namespace flux-system \
      --from-file=values.yaml="prom-stack-values-v${PROMETHEUS_CHART_VERSION}.yaml" \
      --dry-run=client -o yaml | kubeseal --cert="${SEALED_SECRETS_PUB_KEY}" \
      --format=yaml > "${HELM_SECRETS_PATH}/prom-stack-values-v${PROMETHEUS_CHART_VERSION}-sealed.yaml"
   ```

   Explanations for the above command:

   - First, you fetch the `Sealed Secrets Controller public key` - needed by `kubeseal` to `encrypt` your data.
   - Then, `kubectl create secret` is invoked to generate the secret file in YAML format (`-o yaml`), on your local machine (`--dry-run=client`).
   - Finally, the Kubernetes secret `YAML` output is piped to `kubeseal`, and tell it to use your cluster public key (`--cert=pub-sealed-secrets.pem`) to encrypt the result.
4. Now, create the `Prometheus` HelmRelease for `Flux`:

    ```shell
    PROMETHEUS_CHART_VERSION="17.1.3"

    flux create helmrelease "kube-prometheus-stack" \
      --source="HelmRepository/prometheus-community" \
      --chart="kube-prometheus-stack"  \
      --chart-version "$PROMETHEUS_CHART_VERSION" \
      --values-from="Secret/prom-stack-values-v${PROMETHEUS_CHART_VERSION}" \
      --target-namespace="monitoring" \
      --create-target-namespace \
      --export > "${HELM_RELEASES_PATH}/kube-prometheus-stack-v${PROMETHEUS_CHART_VERSION}.yaml"
    ```

    Explanations for the above command:

    - `<source>` - source that contains the chart in the format `<kind>/<name>.<namespace>`, where kind must be one of: (`HelmRepository`, `GitRepository`, `Bucket`).
    - `<chart>` - Helm chart name.
    - `<chart-version>` -  Helm chart version.
    - `<values-from>` - Kubernetes `Secret/ConfigMap` reference that contains the `values.yaml` data key.
    - `<target-namespace>` - namespace to install this release.
    - `<create-target-namespace>` - create the target namespace if it does not exist.
    - `<export>` - export in `YAML` format to stdout.
5. Finally, commit your changes and push to remote (please replace the `<>` placeholders accordingly):

    ```shell
    PROMETHEUS_CHART_VERSION="17.1.3"

    git add "${HELM_REPOSITORIES_PATH}/prometheus-community.yaml"

    git add "${HELM_RELEASES_PATH}/kube-prometheus-stack-v${PROMETHEUS_CHART_VERSION}.yaml"

    git add "${HELM_SECRETS_PATH}/prom-stack-values-v${PROMETHEUS_CHART_VERSION}-sealed.yaml"

    git commit -am "Added Flux CD Prometheus stack manifests for <your_cluster_name> cluster"

    git push origin
    ```

After a few moments, please inspect the `Prometheus` stack resources created for `Flux CD`:

```shell
flux get helmrelease kube-prometheus-stack
```
  
The output looks similar to:

```text
NAME                    READY   MESSAGE                                 REVISION        SUSPENDED 
kube-prometheus-stack   True    Release reconciliation succeeded        17.1.3          False
```

Look for the `READY` column value - it should say `True`. Reconciliation status is displayed in the `MESSAGE` column, along with the `REVISION` number, which represents the `Helm` chart `version`.

**Notes:**

- In case something goes wrong, you can search the `Flux` logs and filter `HelmRelease` messages only:

    ```shell
    flux logs --kind=HelmRelease
    ```

- Please bear in mind that some releases take longer to complete (like `Prometheus` stack, for example), so please be patient.

Please refer to the [04-setup-prometheus-stack](../04-setup-prometheus-stack/README.md) tutorial for checking the `Prometheus Stack` deployment status and functionality.

Next, you're going to create the manifests for `Loki` stack, and let `Flux CD` handle the `Helm` release automatically.

### Creating the Loki Stack Helm Release

In this section, you will create the `Loki` stack `Helm` release manifests for `Flux` to use, and automatically deploy it to your `DOKS` cluster.

Steps to follow:

1. First, create the `Loki` HelmRepository `source` for `Flux`:

    ```shell
    flux create source helm grafana \
      --url="https://grafana.github.io/helm-charts" \
      --interval="10m" \
      --export > "${HELM_REPOSITORIES_PATH}/grafana.yaml"
    ```

    Explanations for the above command:

    - `<url>` - Helm repository address.
    - `<interval>` - source sync interval (default `1m0s`).
    - `<export>` - export in `YAML` format to stdout.

2. Then, fetch the `Starter Kit` values file for `Loki`. Please make sure to inspect the `Loki` values file, and replace the `<>` placeholders where needed:

    ```shell
    LOKI_CHART_VERSION="2.4.1"

    curl "https://raw.githubusercontent.com/digitalocean/Kubernetes-Starter-Kit-Developers/1.21/05-setup-loki-stack/assets/manifests/loki-stack-values-v${LOKI_CHART_VERSION}.yaml" > "loki-stack-values-v${LOKI_CHART_VERSION}.yaml"
    ```

3. Next, `create` and `encrypt` the Kubernetes secret for the Loki Stack `HelmRelease` to consume (please replace the `<>` placeholders accordingly):

   ```shell
   LOKI_CHART_VERSION="2.4.1"
   SEALED_SECRETS_PUB_KEY="pub-sealed-secrets-<your_doks_cluster_name_here>.pem"

   kubectl create secret generic "loki-stack-values-v${LOKI_CHART_VERSION}" \
      --namespace flux-system \
      --from-file=values.yaml="loki-stack-values-v${LOKI_CHART_VERSION}.yaml" \
      --dry-run=client -o yaml | kubeseal --cert="${SEALED_SECRETS_PUB_KEY}" \
      --format=yaml > "${HELM_SECRETS_PATH}/loki-stack-values-v${LOKI_CHART_VERSION}-sealed.yaml"
   ```

   Explanations for the above command:

   - First, you fetch the `Sealed Secrets Controller public key` - needed by `kubeseal` to `encrypt` your data.
   - Then, `kubectl create secret` is invoked to generate the secret file in YAML format (`-o yaml`), on your local machine (`--dry-run=client`).
   - Finally, the Kubernetes secret `YAML` output is piped to `kubeseal`, and tell it to use your cluster public key (`--cert=pub-sealed-secrets.pem`) to encrypt the result.
4. Now, create the `Loki` HelmRelease for `Flux`:

    ```shell
    LOKI_CHART_VERSION="2.4.1"

    flux create helmrelease "loki-stack" \
      --source="HelmRepository/grafana" \
      --chart="loki-stack"  \
      --chart-version "$LOKI_CHART_VERSION" \
      --values-from="Secret/loki-stack-values-v${LOKI_CHART_VERSION}" \
      --target-namespace="monitoring" \
      --create-target-namespace \
      --export > "${HELM_RELEASES_PATH}/loki-stack-v${LOKI_CHART_VERSION}.yaml"
    ```

    Explanations for the above command:

    - `<source>` - source that contains the chart in the format `<kind>/<name>.<namespace>`, where kind must be one of: (`HelmRepository`, `GitRepository`, `Bucket`).
    - `<chart>` - Helm chart name.
    - `<chart-version>` -  Helm chart version.
    - `<values-from>` - Kubernetes `Secret/ConfigMap` reference that contains the `values.yaml` data key.
    - `<target-namespace>` - namespace to install this release.
    - `<create-target-namespace>` - create the target namespace if it does not exist.
    - `<export>` - export in `YAML` format to stdout.
5. Finally, commit your changes and push to remote (please replace the `<>` placeholders accordingly):

    ```shell
    LOKI_CHART_VERSION="2.4.1"

    git add "${HELM_REPOSITORIES_PATH}/grafana.yaml"

    git add "${HELM_RELEASES_PATH}/loki-stack-v${LOKI_CHART_VERSION}.yaml"

    git add "${HELM_SECRETS_PATH}/loki-stack-values-v${LOKI_CHART_VERSION}-sealed.yaml"

    git commit -am "Added Flux CD Loki stack manifests for <your_cluster_name> cluster"

    git push origin
    ```

After a few moments, please inspect the `Loki` stack resources created for `Flux CD`:

```shell
flux get helmrelease loki-stack
```
  
The output looks similar to:

```text
NAME         READY   MESSAGE                                 REVISION       SUSPENDED 
loki-stack   True    Release reconciliation succeeded        2.4.1          False
```

Look for the `READY` column value - it should say `True`. Reconciliation status is displayed in the `MESSAGE` column, along with the `REVISION` number, which represents the `Helm` chart `version`.

**Notes:**

- In case something goes wrong, you can search the `Flux` logs and filter `HelmRelease` messages only:

    ```shell
    flux logs --kind=HelmRelease
    ```

- Please bear in mind that some releases take longer to complete (like `Prometheus` stack, for example), so please be patient.

Please refer to the [05-setup-loki-stack](../05-setup-loki-stack/README.md) tutorial, for checking the `Loki Stack` deployment status and functionality.

Next, you're going to create the manifests and let `Flux CD` handle the `Velero` Helm release automatically.

### Creating the Velero Helm Release

In this section, you will create the `Velero` stack `Helm` release manifests for `Flux` to use, and automatically deploy it to your `DOKS` cluster.

Steps to follow:

1. First, create the `Velero` HelmRepository `source` for `Flux`:

    ```shell
    flux create source helm vmware-tanzu \
      --url="https://vmware-tanzu.github.io/helm-charts" \
      --interval="10m" \
      --export > "${HELM_REPOSITORIES_PATH}/vmware-tanzu.yaml"
    ```

    Explanations for the above command:

    - `<url>` - Helm repository address.
    - `<interval>` - source sync interval (default `1m0s`).
    - `<export>` - export in `YAML` format to stdout.

2. Then, fetch the `Starter Kit` values file for `Velero`. Please make sure to inspect the `Velero` values file, and replace the `<>` placeholders where needed:

    ```shell
    VELERO_CHART_VERSION="2.23.6"

    curl "https://raw.githubusercontent.com/digitalocean/Kubernetes-Starter-Kit-Developers/1.21/06-setup-velero/assets/manifests/velero-values-v${VELERO_CHART_VERSION}.yaml" > "velero-values-v${VELERO_CHART_VERSION}.yaml"
    ```

3. Next, `create` and `encrypt` the Kubernetes secret for Velero `HelmRelease` to consume (please replace the `<>` placeholders accordingly):

   ```shell
   VELERO_CHART_VERSION="2.23.6"
   SEALED_SECRETS_PUB_KEY="pub-sealed-secrets-<your_doks_cluster_name_here>.pem"

   kubectl create secret generic "velero-values-v${VELERO_CHART_VERSION}" \
      --namespace flux-system \
      --from-file=values.yaml="velero-values-v${VELERO_CHART_VERSION}.yaml" \
      --dry-run=client -o yaml | kubeseal --cert="${SEALED_SECRETS_PUB_KEY}" \
      --format=yaml > "${HELM_SECRETS_PATH}/velero-values-v${VELERO_CHART_VERSION}-sealed.yaml"
   ```

   Explanations for the above command:

   - First, you fetch the `Sealed Secrets Controller public key` - needed by `kubeseal` to `encrypt` your data.
   - Then, `kubectl create secret` is invoked to generate the secret file in YAML format (`-o yaml`), on your local machine (`--dry-run=client`).
   - Finally, the Kubernetes secret `YAML` output is piped to `kubeseal`, and tell it to use your cluster public key (`--cert=pub-sealed-secrets.pem`) to encrypt the result.
4. Now, create the `Velero` HelmRelease for `Flux`:

    ```shell
    VELERO_CHART_VERSION="2.23.6"

    flux create helmrelease "velero-stack" \
      --source="HelmRepository/vmware-tanzu" \
      --chart="velero"  \
      --chart-version "$VELERO_CHART_VERSION" \
      --values-from="Secret/velero-values-v${VELERO_CHART_VERSION}" \
      --target-namespace="velero" \
      --create-target-namespace \
      --export > "${HELM_RELEASES_PATH}/velero-v${VELERO_CHART_VERSION}.yaml"
    ```

    Explanations for the above command:

    - `<source>` - source that contains the chart in the format `<kind>/<name>.<namespace>`, where kind must be one of: (`HelmRepository`, `GitRepository`, `Bucket`).
    - `<chart>` - Helm chart name.
    - `<chart-version>` -  Helm chart version.
    - `<values-from>` - Kubernetes `Secret/ConfigMap` reference that contains the `values.yaml` data key.
    - `<target-namespace>` - namespace to install this release.
    - `<create-target-namespace>` - create the target namespace if it does not exist.
    - `<export>` - export in `YAML` format to stdout.
5. Finally, commit your changes and push to remote (please replace `<your_cluster_name>` placeholder first):

    ```shell
    VELERO_CHART_VERSION="2.23.6"

    git add "${HELM_REPOSITORIES_PATH}/vmware-tanzu.yaml"

    git add "${HELM_RELEASES_PATH}/velero-v${VELERO_CHART_VERSION}.yaml"

    git add "${HELM_SECRETS_PATH}/velero-values-v${VELERO_CHART_VERSION}-sealed.yaml"

    git commit -am "Added Flux CD Velero manifests for <your_cluster_name> cluster"

    git push origin
    ```

After a few moments, please inspect the `Velero` stack resources created for `Flux CD`:

```shell
flux get helmrelease velero-stack
```

The output looks similar to:

```text
NAME                 READY  MESSAGE                             REVISION    SUSPENDED 
velero-stack         True   Release reconciliation succeeded    2.23.6      False
```

Look for the `READY` column value - it should say `True`. Reconciliation status is displayed in the `MESSAGE` column, along with the `REVISION` number, which represents the `Helm` chart `version`.

**Notes:**

- In case something goes wrong, you can search the `Flux` logs and filter `HelmRelease` messages only:

    ```shell
    flux logs --kind=HelmRelease
    ```

- Please bear in mind that some releases take longer to complete (like `Prometheus` stack, for example), so please be patient.

Please refer to the [06-setup-velero](../06-setup-velero/README.md) tutorial, for checking the `Velero` deployment status and functionality.

## Conclusion

In this tutorial, you learned the automation basics for a `GitOps` based setup. You learned about `Terraform` modules, and how to re-use configuration to provision the required infrastructure - `DOKS` cluster and `Flux CD`.

Then, you configured `Flux CD` to perform `Helm` releases for you automatically via `Git` changes, and deploy all the `Starter Kit` components in a `GitOps` fashion.

`Flux CD` supports other interesting `Controllers` as well, which can be configured and enabled, like:

- [Notification Controller](https://fluxcd.io/docs/components/notification) - specialized in handling inbound and outbound events for `Slack`, etc.
- [Image Automation Controller](https://fluxcd.io/docs/components/image) - updates a `Git` repository when new container images are available.

You can visit the official [Flux CD Guides](https://fluxcd.io/docs/guides) page for more interesting stuff and ideas, like how to structure your `Git` repositories, as well as application `manifests` for `multi-cluster` and `multi-environment` setups.
