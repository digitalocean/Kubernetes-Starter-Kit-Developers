# Day-2 Operations-ready DigitalOcean Kubernetes (DOKS) for Developers

[Webinar video from 9/28/2021](https://www.youtube.com/watch?v=C48gUklH1DU&t=5s)

In this tutorial, we provide developers a hands-on introduction on how to get started with an operations-ready Kubernetes cluster on DigitalOcean Kubernetes (DOKS). Kubernetes is easy to set up and developers can use identical tooling and configurations across any cloud. Making Kubernetes operationally ready requires a few more tools to be set up, which are described in this tutorial.

Resources used by the starter kit include the following:

- DigitalOcean `Droplets` (for `DOKS` cluster).
- DigitalOcean `Load Balancer`.
- DigitalOcean `Block Storage` for persistent storage.
- DigitalOcean `Spaces` for object storage.

Remember to verify and delete the resources at the end of the tutorial, if you no longer need those.

## Operations-ready Setup Overview

Below is a diagram that gives a high-level overview of the `Starter Kit` setup, as well as the main steps:

![Setup Overview](assets/images/starter_kit_arch_overview.png)

## Table of contents

1. [Scope](#scope)
2. [Set up DO Kubernetes](01-setup-DOKS/README.md)
3. [Set up DO Container Registry](02-setup-DOCR/README.md)
4. [Ingress Using Ambassador](03-setup-ingress-ambassador/README.md)
5. [Prometheus Monitoring Stack](04-setup-prometheus-stack/README.md)
6. [Logs Aggregation via Loki Stack](05-setup-loki-stack/README.md)
7. [Backup Using Velero](06-setup-velero/README.md)
8. [Estimate resource usage of starter kit](14-starter-kit-resource-usage/README.md)
9. [Automate Everything Using Terraform and Flux](15-automate-with-terraform-flux/README.md)

## Scope

This tutorial demonstrates the basic setup you need to be operations-ready.

All the steps are done manually using the `command line interface` (CLI). If you need end-to-end automation, refer to the last section.

None of the installed tools are exposed using `Ingress` or `Load Balancer`. To access the console for individual tools, we use `kubectl port-forward`.

We will use `brew` (on MacOS) to install the required command-line utilities on our local machine and use the command to work on a `DOKS` cluster.

For every `service` that gets `deployed`, we will enable `metrics` and `logs`. At the end, we will review the `overhead` from all these additional tools and services. That gives an idea of what it takes to be `operations-ready` after your first cluster install.

This tutorial will use manifest files from this repo. It is recommended to clone this repository to your local environment. The below command can be used to clone this repository.

```shell
git clone https://github.com/digitalocean/Kubernetes-Starter-Kit-Developers.git

git checkout <BRANCH>   # Use the branch version similar to DOKS, eg. 1.21
```

**Notes:**

- Use specific branch corresponding to DOKS version (eg. 1.21), when available.
- For this `Starter Kit`, we recommend to start with a node pool of higher capacity nodes (say, `4cpu/8gb RAM`) and have at least `2` nodes. Otherwise, review and allocate node capacity if you run into pods in `PENDING` state.
- We customize the value files for `Helm` installs of individual components. To get the original value file, use `helm show values`. For example: `helm show values prometheus-community/kube-prometheus-stack  --version 17.1.3`.
- There are multiple places where you will change a manifest file to include a secret token for your cluster. Please be mindful of `handling` the `secrets`, and do not `commit` to `public Git` repositories. We've done the due diligence of adding those to `.gitignore` files.
- **For the final automation, the GitHub `repository` (and `branch`) must be created beforehand - the DigitalOcean Terraform module used in this tutorial doesn't provision one for you automatically. Please make sure that the Git `repository` is `private` as well.**

If you want to automate installation for all the components, refer to [Section 15 - Automate with Terraform & Flux CD](15-automate-with-terraform-flux/README.md).

Go to [Section 1 - Set up DigitalOcean Kubernetes](01-setup-DOKS/README.md).
