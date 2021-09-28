# Automate Everything using Terraform and Flux

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
- [Step 4 - Creating Flux CD Helm Releases](#step-4---creating-flux-cd-helm-releases)
  - [Creating the Ambassador Helm Release](#creating-the-ambassador-helm-release)
  - [Creating the Prometheus Stack Helm Release](#creating-the-prometheus-stack-helm-release)
  - [Creating the Loki Stack Helm Release](#creating-the-loki-stack-helm-release)
  - [Creating the Velero Helm Release](#creating-the-velero-helm-release)
- [Conclusion](#conclusion)

## Prerequisites

To complete this tutorial, you will need:

1. A [GitHub](https://github.com) repository and `branch`, for `Flux CD` to store your cluster and sample application `manifests`.

   **Important note:**

   **The GitHub `repository` (and `branch`) must be created beforehand - the DigitalOcean Terraform module used in this tutorial doesn't provision one for you automatically. Please make sure that the Git `repository` is `private` as well.**
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

Please follow the [Inspecting Cluster State](https://github.com/digitalocean/container-blueprints/tree/main/create-doks-with-terraform-flux#step-2---inspecting-cluster-state) section from the DigitalOcean `Create DOKS with Flux CD` blueprint, to complete this step.

In the next step, you will create `Flux CD` manifests for each `component` of the `Starter Kit` tutorial.

## Step 4 - Creating Flux CD Helm Releases

In this step, you will create manifests that tell `Flux` where to look and fetch the `Helm` chart for each `Starter Kit` component (like `Ambassador`, `Prometheus`, `Loki`, etc), as well as how to `install` the corresponding `Helm` chart.

Each manifest you will create, represents a Kubernetes `CRD`:

- [HelmRepository](https://fluxcd.io/docs/components/source/helmrepositories), for use with `Helm` chart repositories.
- [HelmRelease](https://fluxcd.io/docs/components/helm/helmreleases), for performing the actual `Helm` chart install (`release`).

In `Flux CD`, the desired state of a `Helm` release is described through a `Kubernetes` Custom Resource named `HelmRelease`. Based on the creation, mutation or removal of a `HelmRelease` resource in the cluster, `Helm` actions are performed by the [Helm Controller](https://fluxcd.io/docs/components/helm/).

Each `HelmRelease` makes use of a `source` type, so that it knows where to pull the `Helm` chart from.

Other supported source types:

- [GitRepository](https://fluxcd.io/docs/components/source/gitrepositories) for use with `Git` repositories.
- [S3 Bucket](https://fluxcd.io/docs/components/source/buckets) for use with `S3` compatible buckets.

Next, you're going to use the `flux` CLI to create a `HelmRelease` for each component of the `Starter Kit`. Each `Helm` release requires a set of manifests created, and committed in your `Git` repository which targets your `DOKS` cluster.

After finishing all the steps, you should have a `Git` repository structure similar to:

```text
├── README.md
└── clusters
    └── dev
        ├── flux-system
        │   ├── gotk-components.yaml
        │   ├── gotk-sync.yaml
        │   └── kustomization.yaml
        └── helm
            ├── ambassador-release-v6.7.13.yaml
            ├── ambassador-repository.yaml
            ├── grafana-repository.yaml
            ├── kube-prometheus-stack-release-v17.1.3.yaml
            ├── loki-stack-release-v2.4.1.yaml
            ├── prometheus-community-repository.yaml
            ├── velero-stack-release-v2.23.6.yaml
            └── vmware-tanzu-repository.yaml
```

### Creating the Ambassador Helm Release

In this section, you will learn how to create the `Flux CD` manifests which define the `Ambassador` Helm release. Then, `Flux` performs a `Helm` release for you, on each `Git` change for the affected resource (`Ambassador`, in this case).

Please use the following steps, to create the `Ambassador` Helm release:

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

4. Next, create the `Helm` sources directory to store the `HelmRepository` and `HelmRelease` manifests (please replace the `<>` placeholders accordingly):

    ```shell
    HELM_MANIFESTS_PATH="<git_repository_sync_path>/helm"

    mkdir -p "$HELM_MANIFESTS_PATH"
    ```

    Explanations for the above command:

    - `<git_repository_sync_path>` - your `Flux CD` cluster directory path as defined in `main.tf` file

5. Now, create the `Ambassador` HelmRepository `source` for `Flux`:

    ```shell
    flux create source helm ambassador \
      --url="https://www.getambassador.io" \
      --interval="10m" \
      --export > "${HELM_MANIFESTS_PATH}/ambassador-repository.yaml"
    ```

    Explanations for the above command:

    - `<url>` - Helm repository address.
    - `<interval>` - source sync interval (default `1m0s`).
    - `<export>` - export in `YAML` format to stdout.

6. Then, fetch the `Starter Kit` values file for `Ambassador`. Please make sure to inspect the `Ambassador` values file, and replace the `<>` placeholders where needed:

    ```shell
    AMBASSADOR_CHART_VERSION="6.7.13"

    curl "https://raw.githubusercontent.com/digitalocean/Kubernetes-Starter-Kit-Developers/1.21/03-setup-ingress-ambassador/assets/manifests/ambassador-values-v${AMBASSADOR_CHART_VERSION}.yaml" > "ambassador-values-v${AMBASSADOR_CHART_VERSION}.yaml"
    ```

7. Now, create the `Ambassador` HelmRelease for `Flux`:

    ```shell
    AMBASSADOR_CHART_VERSION="6.7.13"

    flux create helmrelease "ambassador-stack" \
      --source="HelmRepository/ambassador" \
      --chart="ambassador" \
      --chart-version "$AMBASSADOR_CHART_VERSION" \
      --values="ambassador-values-v${AMBASSADOR_CHART_VERSION}.yaml" \
      --target-namespace="ambassador" \
      --create-target-namespace \
      --export > "${HELM_MANIFESTS_PATH}/ambassador-release-v${AMBASSADOR_CHART_VERSION}.yaml"
    ```

    Explanations for the above command:

    - `<source>` - source that contains the chart in the format `<kind>/<name>.<namespace>`, where kind must be one of: (`HelmRepository`, `GitRepository`, `Bucket`).
    - `<chart>` - Helm chart name.
    - `<chart-version>` -  Helm chart version.
    - `<values>` - local path to values file.
    - `<target-namespace>` - namespace to install this release.
    - `<create-target-namespace>` - create the target namespace if it does not exist.
    - `<export>` - export in `YAML` format to stdout.
8. Finally, commit your changes and push to remote (please replace `<your_cluster_name>` placeholder first):

    ```shell
    AMBASSADOR_CHART_VERSION="6.7.13"

    git add "${HELM_MANIFESTS_PATH}/ambassador-repository.yaml"

    git add "${HELM_MANIFESTS_PATH}/ambassador-release-v${AMBASSADOR_CHART_VERSION}.yaml"

    git commit -am "Added the Ambassador Helm release for <your_cluster_name> cluster"

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

Next, you're going to perform similar steps to define `Helm` releases for the remaining components of the `Starter Kit`. Please make sure that you stay in the same directory where your personal `Git` repository was cloned, and that the `HELM_MANIFESTS_PATH` environment variable is set (defined at [Creating the Ambassador Helm Release - Step 4.](#creating-the-ambassador-helm-release) above).

### Creating the Prometheus Stack Helm Release

In this section, you will create the `Prometheus` stack `Helm` release manifests for `Flux` to use, and automatically deploy it to your `DOKS` cluster.

Steps to follow:

1. First, create the `Prometheus` HelmRepository `source` for `Flux`:

    ```shell
    flux create source helm prometheus-community \
      --url="https://prometheus-community.github.io/helm-charts" \
      --interval="10m" \
      --export > "${HELM_MANIFESTS_PATH}/prometheus-community-repository.yaml"
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

3. Now, create the `Prometheus` HelmRelease for `Flux`:

    ```shell
    PROMETHEUS_CHART_VERSION="17.1.3"

    flux create helmrelease "kube-prometheus-stack" \
      --source="HelmRepository/prometheus-community" \
      --chart="kube-prometheus-stack"  \
      --chart-version "$PROMETHEUS_CHART_VERSION" \
      --values="prom-stack-values-v${PROMETHEUS_CHART_VERSION}.yaml" \
      --target-namespace="monitoring" \
      --create-target-namespace \
      --export > "${HELM_MANIFESTS_PATH}/kube-prometheus-stack-release-v${PROMETHEUS_CHART_VERSION}.yaml"
    ```

    Explanations for the above command:

    - `<source>` - source that contains the chart in the format `<kind>/<name>.<namespace>`, where kind must be one of: (`HelmRepository`, `GitRepository`, `Bucket`).
    - `<chart>` - Helm chart name.
    - `<chart-version>` -  Helm chart version.
    - `<values>` - local path to values file.
    - `<target-namespace>` - namespace to install this release.
    - `<create-target-namespace>` - create the target namespace if it does not exist.
    - `<export>` - export in `YAML` format to stdout.
4. Finally, commit your changes and push to remote (please replace the `<>` placeholders accordingly):

    ```shell
    PROMETHEUS_CHART_VERSION="17.1.3"

    git add "${HELM_MANIFESTS_PATH}/prometheus-community-repository.yaml"

    git add "${HELM_MANIFESTS_PATH}/kube-prometheus-stack-release-v${PROMETHEUS_CHART_VERSION}.yaml"

    git commit -am "Added the Prometheus stack Helm release for <your_cluster_name> cluster"

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
      --export > "${HELM_MANIFESTS_PATH}/grafana-repository.yaml"
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

3. Now, create the `Loki` HelmRelease for `Flux`:

    ```shell
    LOKI_CHART_VERSION="2.4.1"

    flux create helmrelease "loki-stack" \
      --source="HelmRepository/grafana" \
      --chart="loki-stack"  \
      --chart-version "$LOKI_CHART_VERSION" \
      --values="loki-stack-values-v${LOKI_CHART_VERSION}.yaml" \
      --target-namespace="monitoring" \
      --create-target-namespace \
      --export > "${HELM_MANIFESTS_PATH}/loki-stack-release-v${LOKI_CHART_VERSION}.yaml"
    ```

    Explanations for the above command:

    - `<source>` - source that contains the chart in the format `<kind>/<name>.<namespace>`, where kind must be one of: (`HelmRepository`, `GitRepository`, `Bucket`).
    - `<chart>` - Helm chart name.
    - `<chart-version>` -  Helm chart version.
    - `<values>` - local path to values file.
    - `<target-namespace>` - namespace to install this release.
    - `<create-target-namespace>` - create the target namespace if it does not exist.
    - `<export>` - export in `YAML` format to stdout.
4. Finally, commit your changes and push to remote (please replace the `<>` placeholders accordingly):

    ```shell
    LOKI_CHART_VERSION="2.4.1"

    git add "${HELM_MANIFESTS_PATH}/grafana-repository.yaml"

    git add "${HELM_MANIFESTS_PATH}/loki-stack-release-v${LOKI_CHART_VERSION}.yaml"

    git commit -am "Added the Loki stack Helm release for <your_cluster_name> cluster"

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
      --export > "${HELM_MANIFESTS_PATH}/vmware-tanzu-repository.yaml"
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

3. Now, create the `Velero` HelmRelease for `Flux`:

    ```shell
    VELERO_CHART_VERSION="2.23.6"

    flux create helmrelease "velero-stack" \
      --source="HelmRepository/vmware-tanzu" \
      --chart="velero"  \
      --chart-version "$VELERO_CHART_VERSION" \
      --values="velero-values-v${VELERO_CHART_VERSION}.yaml" \
      --target-namespace="velero" \
      --create-target-namespace \
      --export > "${HELM_MANIFESTS_PATH}/velero-stack-release-v${VELERO_CHART_VERSION}.yaml"
    ```

    Explanations for the above command:

    - `<source>` - source that contains the chart in the format `<kind>/<name>.<namespace>`, where kind must be one of: (`HelmRepository`, `GitRepository`, `Bucket`).
    - `<chart>` - Helm chart name.
    - `<chart-version>` -  Helm chart version.
    - `<values>` - local path to values file.
    - `<target-namespace>` - namespace to install this release.
    - `<create-target-namespace>` - create the target namespace if it does not exist.
    - `<export>` - export in `YAML` format to stdout.
4. Finally, commit your changes and push to remote (please replace `<your_cluster_name>` placeholder first):

    ```shell
    VELERO_CHART_VERSION="2.23.6"

    git add "${HELM_MANIFESTS_PATH}/vmware-tanzu-repository.yaml"

    git add "${HELM_MANIFESTS_PATH}/velero-stack-release-v${VELERO_CHART_VERSION}.yaml"

    git commit -am "Added the Velero stack Helm release for <your_cluster_name> cluster"

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
