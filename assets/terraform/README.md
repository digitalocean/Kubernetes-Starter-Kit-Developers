# DigitalOcean Kubernetes Service (DOKS)

This example shows how to use the Terraform Kubernetes Provider and Terraform
Helm Provider to configure a DOKS cluster. The example config builds the DOKS
cluster and applies the Kubernetes configurations in a single operation. This
guide will also show you how to make changes to the underlying DOKS cluster in
such a way that Kubernetes/Helm resources are recreated after the underlying
cluster is replaced.

You will need to set the following environment variables:

 - `DIGITALOCEAN_ACCESS_TOKEN`

To install the DOKS cluster using default values, run terraform init and apply
from the directory containing this README.

```
terraform init
terraform apply
```

Optionally, the Kubernetes version, the number of worker nodes, and the instance
type of the worker nodes can also be specified:

```
terraform apply -var=cluster_version=1.18 -var=worker_size=s-4vcpu-8gb -var=worker_count=5
```


## Versions

Valid versions for the DOKS cluster can be found by using the doctl, the DigitalOcean CLI.

```
 doctl kubernetes options versions
```

## Kubeconfig for manual CLI access

Optionally, this example can generate a kubeconfig file in the current working
directory. However, the token in this config will expire. The token can be
refreshed by running `terraform apply` again and setting `write_kubeconfig` to
`true`.

```
terraform apply -var="write_kubeconfig=true"
export KUBECONFIG=$(terraform output -raw kubeconfig_path)
kubectl get pods -n test
```

Alternatively, a longer-lived configuration can be generated using doctl. This
command will merge the configuration into your kubeconfig at the default location
(`$HOME/.kube/config`) or create it if the file does not exist.

```
doctl kubernetes cluster kubeconfig save $(terraform output -raw cluster_name)
kubectl get pods -n test
```

## Replacing the DOKS cluster and re-creating the Kubernetes / Helm resources

When the cluster is initially created, the Kubernetes and Helm providers will not
be initialized until authentication details are created for the cluster. However,
for future operations that may involve replacing the underlying cluster, the DOKS
cluster will have to be targeted without the Kubernetes/Helm providers, as shown
below. This is done by removing the `module.kubernetes-config` from Terraform
State prior to replacing cluster credentials, to avoid passing outdated
credentials into the providers.

This will create the new cluster and the Kubernetes resources in a single apply.

```
terraform state rm module.kubernetes-config
terraform apply
```
