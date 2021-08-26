# Day-2 Operations-ready DigitalOcean Kubernetes (DOKS) for Developers

In this tutorial, we provide developers a hands-on introduction on how to get started with an operations-ready Kubernetes cluster on DigitalOcean Kubernetes (DOKS). Kubernetes is easy to set up and developers can use identical tooling and configurations across any cloud. Making Kubernetes operationally ready requires a few more tools to be set up, which are described in this tutorial.



**TBD 
- Need to fix the emptydir storage for prometheus, and use block storage instead. Likewise, use Spaces for Loki. 
- Need to move velero installation using helm. 
- Move the manifests under separate YAML files, so one can customize after cloning. Have images & manifests for each section.
- Adjust the replicas and requests/limits for different namespaces.
- Re-do section 7 with focus on cost analysis. Change input parameters for DO cloud.
- Automation using terraform/flux. 


## Operations-ready Setup Overview

Below is a diagram that gives a high-level overview of the setup presented in this tutorial as well as the main steps:

![Setup Overview](images/starter_kit_arch_overview.jpg)



# Table of contents
0. [Scope](#SCOP)
1. [Set up DO Kubernetes](1-setup-DOKS)
2. [Set up DO Container Registry](2-setup-DOCR)
3. [Ingress Using Ambassador](3-setup-ingress-ambassador)
4. [Prometheus Monitoring Stack](4-setup-prometheus-stack)
5. [Logs Aggregation via Loki Stack](5-setup-loki-stack)
6. [Backup Using Velero](6-setup-velero)
7. [Estimate resource usage of starter kit](14-starter-kit-resource-usage)
15.[Automate Everything Using Terraform and Flux](15-automate-with-terraform-flux)


## Scope <a name="SCOP"></a>
This tutorial demonstrates the basic setup you need to be operations-ready.

All the steps are done manually using the command line interface (CLI). If you need end-to-end automation, refer to the last section.

None of the installed tools are exposed using Ingress or load balancer. To access the console for individual tools, we use `kubectl port-forward`.

We will use `brew` (on MacOS) to install the required command-line utilities on our local machine and use the command to work on a DOKS cluster. 

For every service that gets deployed, we will enable metrics and logs. At the end, we will review the `overhead` from all these additional tools and services. That gives an idea of what it takes to be `operations-ready` after your first cluster install. 

Note: For this starter kit, we recommend to start with a nodepool of higher capacity nodes (say, 4cpu/8gb RAM) and have 2 nodes. Otherwise, review and allocate node capacity if you run into pods in PENDING state.
<br/><br/>

If you want to automate installation for all the components, refer to [section 15 - Automate with terraform & flux](15-automate-with-terraform-flux).

Go to [section 1 - setup DOKS](1-setup-DOKS).

