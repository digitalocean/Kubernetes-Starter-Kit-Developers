# Automate everything using Terraform and Flux

## Introduction

[Terraform](https://www.terraform.io) helps you to create and automate the running infrastructure, like a `Kubernetes` cluster. Then, [Flux CD](https://fluxcd.io) is provisioned as well, so that all the `Starter Kit` components get installed and configured automatically. There's no need to create `manifests` by hand or touch `kubectl` in this process (except for resources inspection and/or debugging).

In this tutorial, you will learn to:

- Use `Terraform` modules to automate all the hard work required to provision infrastructure resources.
- Create `Flux CD` resources to keep your `Kubernetes` cluster applications state synchronized with a `Git` repository (make use of `GitOps` principles).

After finishing all the steps from this tutorial, you should have a fully functional `DOKS` cluster with `Flux CD` deployed, that will:

- Handle cluster reconciliation via the [Source Controller](https://fluxcd.io/docs/components/source/)
- Handle `Helm` releases via the [Helm Controller](https://fluxcd.io/docs/components/helm)

Tutorial setup overview:

![DOKS-FluxCD-Automation-Overview](assets/images/tf_fluxcd_automation.png)

## Table of Contents

- [Introduction](#introduction)
- [Table of Contents](#table-of-contents)
- [Prerequisites](#prerequisites)
- [Step 1 [OPTIONAL] - Initialize the Terraform Backend](#step-1-optional---initialize-the-terraform-backend)
- [Step 2 - Bootstrapping DOKS and Flux CD](#step-2---bootstrapping-doks-and-flux-cd)
- [Step 3 - Inspecting Cluster and Flux CD State](#step-3---inspecting-cluster-and-flux-cd-state)
- [Step 4 - Creating Flux CD Helm Releases](#step-4---creating-flux-cd-helm-releases)
  - [Creating the Ambassador Helm Release](#creating-the-ambassador-helm-release)
  - [Creating the Prometheus Stack Helm Release](#creating-the-prometheus-stack-helm-release)
  - [Creating the Loki Stack Helm Release](#creating-the-loki-stack-helm-release)
  - [Creating the Velero Helm Release](#creating-the-velero-helm-release)
- [Conclusion](#conclusion)
- [Learn More](#learn-more)

## Prerequisites

To complete this tutorial, you will need:

1. A [GitHub](https://github.com) repository and `branch`, needed for `Flux CD` to store cluster and sample application `manifests`.
2. A GitHub [personal access token](https://github.com/settings/tokens) that has the `repo` permissions set. The custom `Terraform` module used in this tutorial needs it in order to create the `SSH` deploy key, as well as to commit the `Flux CD` manifests in your `Git` repository.
3. A `DigitalOcean` access token for creating/managing the `DOKS` cluster. Please follow the official `DigitalOcean` tutorial on how to [create a personal access token](https://docs.digitalocean.com/reference/api/create-personal-access-token). Copy the `token` value and save it somewhere safe.
4. Access keys for [DigitalOcean Spaces](https://cloud.digitalocean.com/spaces) (S3-compatible object storage). Please follow the official `DigitalOcean` tutorial on how to [manage access keys](https://docs.digitalocean.com/products/spaces/how-to/manage-access/). We use `Spaces` for storing the `Terraform` state file. Copy the `key` and `secret` value and save each in a local `environment` variable for later use (make sure to replace the `<>` placeholders accordingly):

    ```shell
    export DO_SPACES_ACCESS_KEY="<YOUR_DO_SPACES_ACCESS_KEY>"
    export DO_SPACES_SECRET_KEY="<YOUR_DO_SPACES_SECRET_KEY>"
    ```

5. A [DO Space](https://cloud.digitalocean.com/spaces) for storing the `Terraform` state file. Please follow the official `DigitalOcean` tutorial on how to [create one](https://docs.digitalocean.com/products/spaces/how-to/create/). Make sure that it is set to `restrict file listing` for security reasons.
6. A [git client](https://git-scm.com/downloads). For example, use the following commands on `MacOS`:

    ```shell
    brew info git
    brew install git
    ```

7. HashiCorp [Terraform](https://www.terraform.io/downloads.html). For example, use the following commands to install on `MacOS`:

    ```shell
    brew info terraform
    brew install terraform
    ```

8. [Doctl](https://github.com/digitalocean/doctl/releases) for `DigitalOcean` API interaction.
9. [Kubectl](https://kubernetes.io/docs/tasks/tools) for `Kubernetes` interaction.
10. [Flux](https://fluxcd.io/docs/installation) for `Flux CD` interaction.

## Step 1 [OPTIONAL] - Initialize the Terraform Backend

**Note:**

This step is optional and the tutorial works without it, but it's best practice in general, so please follow along.

In this step, you're going to initialize the `Terraform` backend. A `DO Spaces` bucket for storing the `Terraform` state file is highly recommended because you do not have to worry about exposing `sensitive` data as long as the space is `private` of course. Another advantage is that the `state` of your `infrastructure` is backed up, so you can re-use it when the `workspace` is lost. Having a `shared` space for team members is desired as well, in order to perform `collaborative` work via `Terraform`.

Steps to follow:

1. Clone this repository on your local machine and navigate to the appropriate directory:

    ```shell
    git clone https://github.com/digitalocean/Kubernetes-Starter-Kit-Developers.git

    cd Kubernetes-Starter-Kit-Developers/assets/terraform
    ```

2. Rename the provided [backend.tf.sample](assets/terraform/backend.tf.sample) file from this repository to `backend.tf`. Then, open it using a text editor of your choice, and replace the `<>` placeholders accordingly (explanations for each can be found inside).
3. Initialize the `Terraform` backend. You're going to use the previously created `DO Spaces` access and secret keys:

    ```shell
    terraform init  --backend-config="access_key=$DO_SPACES_ACCESS_KEY" --backend-config="secret_key=$DO_SPACES_SECRET_KEY"
    ```

    The output looks similar to the following:

    ```text
    Initializing the backend...

    Successfully configured the backend "s3"! Terraform will automatically
    use this backend unless the backend configuration changes.

    Initializing provider plugins...
    - Finding hashicorp/kubernetes versions matching "2.3.2"...
    - Finding gavinbunney/kubectl versions matching "1.11.2"...
    ...
    ```

## Step 2 - Bootstrapping DOKS and Flux CD

In this step, you're going to use a custom `Terraform` module provided by DigitalOcean - [DOKS-FluxCD](https://github.com/digitalocean/container-blueprints/tree/main/create-doks-with-terraform-flux), to provision a `Kubernetes` cluster and deploy `Flux CD`.

Steps to follow:

1. From where this repository was cloned, change directory to `assets/terraform`:

    ```shell
    cd assets/terraform
    ```

2. Edit the [main.tf](assets/terraform/main.tf) file using an editor of your choice (preferrably with `Terraform` linting support) and replace the `<>` placehholders accordingly (explanations for each can be found inside).
3. Next, inspect the infrastructure changes:

    ```shell
    terraform plan -out starter_kit_flux_cluster.out
    ```

4. Apply changes using:

    ```shell
    terraform apply "starter_kit_flux_cluster.out"
    ```

After running the above steps, you should have a fully functional `Kubernetes` cluster and `Flux CD` deployed. In the next step, you're going to inspect the cluster state.

## Step 3 - Inspecting Cluster and Flux CD State

Please follow the [Inspecting Cluster State](https://github.com/digitalocean/container-blueprints/tree/main/create-doks-with-terraform-flux#step-2---inspecting-cluster-state) section from the DigitalOcean `Create DOKS with Flux CD` blueprint, to see how to accomplish this part.

## Step 4 - Creating Flux CD Helm Releases

In this step, you're going to create a `HelmRelease` for each of the components used in the `Starter Kit`, like: `Ambasador Edge Stack`, `Prometheus`, `Loki`, etc.

In `Flux CD`, the desired state of a `Helm` release is described through a `Kubernetes` Custom Resource named `HelmRelease`. Based on the creation, mutation or removal of a `HelmRelease` resource in the cluster, `Helm` actions are performed by the controller. For more information and the available features, please visit the official [Helm Controller](https://fluxcd.io/docs/components/helm/) documentation page.

Each `HelmRelease` makes use of a `source` type, so that it knows where to pull the `Helm` chart from.

Supported source types:

- [HelmRepository](https://github.com/fluxcd/source-controller/blob/main/docs/spec/v1beta1/helmrepositories.md) for use with `Helm` chart repositories.
- [GitRepository](https://github.com/fluxcd/source-controller/blob/main/docs/spec/v1beta1/gitrepositories.md) for use with `Git` repositories.
- [Bucket](https://github.com/fluxcd/source-controller/blob/main/docs/spec/v1beta1/buckets.md) for use with `S3` compatible buckets.

Next, you're going to use the `flux` CLI to create a `HelmRelease` for each of the `Starter Kit` components. Each `Helm` release requires a set of manifests created.

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

In this section, you will learn how to create the `Flux` manifests which define the `Ambassador` Helm release. Then, `Flux` triggers `Helm` releases automatically, on each `Git` change for the affected resource (`Ambassador`, in this case).

First, a side by side comparison is presented on how `Helm` handles releases when using the `CLI`, versus how `Flux CD` accomplishes the same thing via `CRD`'s.

Steps involved when using `Helm` via `CLI` to release a `Chart`:

- User defines a `Helm` repository for the `Chart` source.
- `Helm` pulls the required `Chart` from the repository.
- `Helm` creates the `Release` in user's `Kubernetes` cluster, using the pulled `Chart` (and optionally, combine `values`).

Steps for doing a `Helm` release via `Flux CD`:

- User defines a `HelmRepository` manifest file - tells `Flux` what `Helm` repository to use for pulling the `chart`.
- User defines a `HelmRelease` manifest file - tells `Flux` how to create a `Helm` release, what `values` file to use, etc.

Please use the following steps, to create the `Ambassador` Helm release:

1. Clone your Flux CD `Git` repository (please replace the `<>` placeholders accordingly). This is the main repository used for your `DOKS` cluster reconciliation.

   ```shell
   git clone git@github.com:<github_user>/<git_repository_name>.git
   ```

    Explanations for the above command:

    - `<github_user>` - your GitHub username as defined in `main.tf` file
    - `<git_repository_name>` - your Flux CD Github repository as defined in `main.tf` file

2. Change directory where your `Git` repository was cloned (please replace the `<>` placeholders accordingly):

    ```shell
    cd <git_repository_name>
    ```

3. Checkout the `Flux CD` cluster branch, if not using `main` default branch (please replace the `<>` placeholders accordingly):

    ```shell
    git checkout <git_repository_branch>
    ```

    Explanations for the above command:

    - `<git_repository_branch>` - your `Git` branch for storing `Flux CD` cluster manifests as defined in `main.tf` file

4. Next, create the `helm` sources directory to store the `HelmRepository` and `HelmRelease` manifests (please replace the `<>` placeholders accordingly):

    ```shell
    HELM_MANIFESTS_PATH="<git_repository_sync_path>/helm"

    mkdir -p "$HELM_MANIFESTS_PATH"
    ```

    Explanations for the above command:

    - `<git_repository_sync_path>` - your `Flux CD` cluster directory path as defined in `main.tf` file

5. Create the `Ambassador` Helm chart `source` for `Flux` to use:

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

6. Fetch the `Starter Kit` values file for `Ambassador`, and create the Helm `release` for `Flux` to use:

    ```shell
    AMBASSADOR_CHART_VERSION="6.7.13"

    curl "https://raw.githubusercontent.com/digitalocean/Kubernetes-Starter-Kit-Developers/main/3-setup-ingress-ambassador/res/manifests/ambassador-values-v${AMBASSADOR_CHART_VERSION}.yaml" > "ambassador-values-v${AMBASSADOR_CHART_VERSION}.yaml"

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
7. Commit your changes and push to remote (please replace `<your_cluster_name>` placeholder first):

    ```shell
    git add -A

    git commit -am "Added the Ambassador Helm release for <your_cluster_name> cluster"

    git push origin
    ```

After completing the above steps, `Flux` will start your `DOKS` cluster `reconciliation` (after `one minute` or so, if using the `default` interval). If you don't want to wait, you can always `force` reconciliation via:

```shell
flux reconcile source git flux-system
```

Check the `Ambassador` Helm release status, after a few moments:

```shell
flux get helmrelease ambassador-stack
```
  
The output looks similar to:

```text
NAME                    READY   MESSAGE                                 REVISION        SUSPENDED 
ambassador-stack        True    Release reconciliation succeeded        6.7.13          False 
```

Look for the `READY` column value - it should say `True`. Then, the reconciliation status is displayed in the `MESSAGE` column, along with the `REVISION` number, which represents the `Helm` chart `version`.

**Notes:**

- In case something goes wrong, you can search the `Flux` logs and filter `HelmRelease` messages only:

    ```shell
    flux logs --kind=HelmRelease
    ```

- Please bear in mind that some releases take longer to complete (like `Prometheus` stack, for example), so please be patient.

Please refer to the [3-setup-ingress-ambassador](../3-setup-ingress-ambassador/README.md)  tutorial, for checking the `Ambassador Edge Stack` deployment status and functionality.

Next, you're going to perform similar steps to define `Helm` releases for the remaining components of the `Starter Kit`. Please make sure that you stay in the same directory where your personal `Git` repository was cloned, and that the `HELM_MANIFESTS_PATH` environment variable is set (defined at [Creating the Ambassador Helm Release - Step 4.](#creating-the-ambassador-helm-release) above).

### Creating the Prometheus Stack Helm Release

In this section, you will create the `Prometheus` stack `Helm` release manifests for `Flux` to use, and automatically deploy it to your `DOKS` cluster.

Steps to follow:

1. Create the `Prometheus` Helm chart `source` for `Flux` to use:

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

2. Fetch the `Starter Kit` values file for `Prometheus`, and create the Helm `release` for `Flux` to use:

    ```shell
    PROMETHEUS_CHART_VERSION="17.1.3"

    curl "https://raw.githubusercontent.com/digitalocean/Kubernetes-Starter-Kit-Developers/main/4-setup-prometheus-stack/res/manifests/prom-stack-values-v${PROMETHEUS_CHART_VERSION}.yaml" > "prom-stack-values-v${PROMETHEUS_CHART_VERSION}.yaml"

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
3. Commit your changes and push to remote (please replace `<your_cluster_name>` placeholder first):

    ```shell
    git add -A

    git commit -am "Added the Prometheus stack Helm release for <your_cluster_name> cluster"

    git push origin
    ```

After a few moments, please inspect the `Prometheus` Flux resources created. Check the `Prometheus` Helm release status, first:

```shell
flux get helmrelease kube-prometheus-stack
```
  
The output looks similar to:

```text
NAME                    READY   MESSAGE                                 REVISION        SUSPENDED 
kube-prometheus-stack   True    Release reconciliation succeeded        17.1.3          False
```

Look for the `READY` column value - it should say `True`. Then, the reconciliation status is displayed in the `MESSAGE` column, along with the `REVISION` number, which represents the `Helm` chart `version`.

**Notes:**

- In case something goes wrong, you can search the `Flux` logs and filter `HelmRelease` messages only:

    ```shell
    flux logs --kind=HelmRelease
    ```

- Please bear in mind that some releases take longer to complete (like `Prometheus` stack, for example), so please be patient.

Please refer to the [4-setup-prometheus-stack](../4-setup-prometheus-stack/README.md) tutorial, for checking the `Prometheus Stack` deployment status and functionality.

Next, you're going to create the manifests and let `Flux CD` handle the `Loki Stack` Helm release automatically.

### Creating the Loki Stack Helm Release

In this section, you will create the `Loki` stack `Helm` release manifests for `Flux` to use, and automatically deploy it to your `DOKS` cluster.

Steps to follow:

1. Create the `Loki` Helm chart `source` for `Flux` to use:

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

2. Fetch the `Starter Kit` values file for `Loki`, and create the Helm `release` for `Flux` to use:

    ```shell
    LOKI_CHART_VERSION="2.4.1"

    curl "https://raw.githubusercontent.com/digitalocean/Kubernetes-Starter-Kit-Developers/main/5-setup-loki-stack/res/manifests/loki-stack-values-v${LOKI_CHART_VERSION}.yaml" > "loki-stack-values-v${LOKI_CHART_VERSION}.yaml"

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
3. Commit your changes and push to remote (please replace `<your_cluster_name>` placeholder first):

    ```shell
    git add -A

    git commit -am "Added the Loki stack Helm release for <your_cluster_name> cluster"

    git push origin
    ```

After a few moments, please inspect the `Loki` Flux resources created. Check the `Loki` Helm release status, first:

```shell
flux get helmrelease loki-stack
```
  
The output looks similar to:

```text
NAME         READY   MESSAGE                                 REVISION       SUSPENDED 
loki-stack   True    Release reconciliation succeeded        2.4.1          False
```

Look for the `READY` column value - it should say `True`. Then, the reconciliation status is displayed in the `MESSAGE` column, along with the `REVISION` number, which represents the `Helm` chart `version`.

**Notes:**

- In case something goes wrong, you can search the `Flux` logs and filter `HelmRelease` messages only:

    ```shell
    flux logs --kind=HelmRelease
    ```

- Please bear in mind that some releases take longer to complete (like `Prometheus` stack, for example), so please be patient.

Please refer to the [5-setup-loki-stack](../5-setup-loki-stack/README.md) tutorial, for checking the `Loki Stack` deployment status and functionality.

Next, you're going to create the manifests and let `Flux CD` handle the `Velero` Helm release automatically.

### Creating the Velero Helm Release

In this section, you will create the `Velero` stack `Helm` release manifests for `Flux` to use, and automatically deploy it to your `DOKS` cluster.

Steps to follow:

1. Create the `Velero` Helm chart `source` for `Flux` to use:

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

2. Fetch the `Starter Kit` values file for `Velero`, and create the Helm `release` for `Flux` to use:

    ```shell
    VELERO_CHART_VERSION="2.23.6"

    curl "https://raw.githubusercontent.com/digitalocean/Kubernetes-Starter-Kit-Developers/main/6-setup-velero/res/manifests/velero-values-v${VELERO_CHART_VERSION}.yaml" > "velero-values-v${VELERO_CHART_VERSION}.yaml"

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
3. Commit your changes and push to remote (please replace `<your_cluster_name>` placeholder first):

    ```shell
    git add -A

    git commit -am "Added the Velero stack Helm release for <your_cluster_name> cluster"

    git push origin
    ```

After a few moments, please inspect the `Velero` Flux resources created. Check the `Velero` Helm release status, first:

```shell
flux get helmrelease velero-stack
```

The output looks similar to:

```text
NAME                 READY  MESSAGE                             REVISION    SUSPENDED 
velero-stack         True   Release reconciliation succeeded    2.23.6      False
```

Look for the `READY` column value - it should say `True`. Then, the reconciliation status is displayed in the `MESSAGE` column, along with the `REVISION` number, which represents the `Helm` chart `version`.

**Notes:**

- In case something goes wrong, you can search the `Flux` logs and filter `HelmRelease` messages only:

    ```shell
    flux logs --kind=HelmRelease
    ```

- Please bear in mind that some releases take longer to complete (like `Prometheus` stack, for example), so please be patient.

Please refer to the [6-setup-velero](../6-setup-velero/README.md) tutorial, for checking the `Velero` deployment status and functionality.

## Conclusion

In this tutorial you learned the automation basics for a `GitOps` based setup. You learned about `Terraform` modules, and how to re-use configuration to provision the required infrastructure - `DOKS` cluster and `Flux CD`.

Then, you configured `Flux CD` to perform `Helm` releases for you automatically via `Git` changes, and deploy all the `Starter Kit` components in a `GitOps` fashion. A simple strategy was used in this tutorial, based on a `single` branch and a `single` environment.

## Learn More

`Flux CD` supports other interesting `Controllers` as well, which can be configured and enabled, like:

- [Notification Controller](https://fluxcd.io/docs/components/notification) which is specialized in handling inbound and outbound events for `Slack`, etc.
- [Image Automation Controller](https://fluxcd.io/docs/components/image) which can update a `Git` repository when new container images are available

You can visit the official [Flux CD Guides](https://fluxcd.io/docs/guides) page for more interesting stuff and ideas, like how to structure your `Git` repositories, as well as application `manifests` for multi-cluster and multi-environment setups.
