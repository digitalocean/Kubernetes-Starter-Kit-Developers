## Set up DigitalOcean Kubernetes 

Explore `doctl` options.

```
~ doctl version
doctl version 1.61.0-release
~ doctl auth list
bgdo (current)
default
~ 
```

Explore options for creating the cluster.

```
~ doctl k8s -h
~ doctl k8s options -h
~ doctl k8s options regions
~ doctl k8s options sizes  
~ doctl k8s options versions
~ doctl k8s cluster create -h
```

Let us create a `DOKS` cluster with `3 worker nodes`. Use `--wait false`, if you do not want the command to wait until cluster is ready.

In the example below, we create 4cpu/8gb basic nodes ($40/month), 2 default, and auto-scale to 4. So your cluster cost would between $80-$160/month, with hourly billing. To choose a different node type, pick from the following command `doctl compute size list`.

```
~ doctl kubernetes cluster create bg-cluster-2 \
--auto-upgrade=false \
--maintenance-window "saturday=21:00" \
--node-pool "name=basicnp;size=s-4vcpu-8gb;count=3;tag=cluster2;label=type=basic;auto-scale=true;min-nodes=2;max-nodes=4" \
--region nyc1 \
--tag k8s:ha 

Notice: Cluster is provisioning, waiting for cluster to be running
..................................................................
Notice: Cluster created, fetching credentials
Notice: Adding cluster credentials to kubeconfig file found in "/Users/bgupta/.kube/config"
Notice: Setting current-context to do-sfo3-bg-cluster-1
ID                                      Name            Region    Version        Auto Upgrade    Status     Node Pools
0922a629-7f2e-4bda-940c-4d42a3f987ad    bg-cluster-1    sfo3      1.20.7-do.0    false           running    basicnp
~ 

~ curl -X GET \-H "Content-Type: application/json" \-H "Authorization: Bearer <DigitalOcean accesstoken>" \https://api.digitalocean.com/v2/kubernetes/clusters/<cluster_id>

<Get cluster info. You can verify if HA control plane is enabled. That will be the LAST entry in JSON output.>

```

Now, let us set up `kubectl`, if the context is not set.

```
~ kubectl config current-context 
do-sfo3-bg-cluster-1
~ 
~ doctl k8s cluster list
ID                                      Name            Region    Version        Auto Upgrade    Status          Node Pools
0922a629-7f2e-4bda-940c-4d42a3f987ad    bg-cluster-1    sfo3      1.20.7-do.0    false           provisioning    basicnp
# YOU MAY NOT NEED THIS COMMAND, IF CONTEXT IS ALREADY SET.
~ doctl kubernetes cluster kubeconfig save 0922a629-7f2e-4bda-940c-4d42a3f987ad
Notice: Adding cluster credentials to kubeconfig file found in "/Users/bgupta/.kube/config"
Notice: Setting current-context to do-sfo3-bg-cluster-1
~ 
~ kubectl get nodes
NAME            STATUS   ROLES    AGE     VERSION
basicnp-865x3   Ready    <none>   2m55s   v1.20.7
basicnp-865x8   Ready    <none>   2m21s   v1.20.7
basicnp-865xu   Ready    <none>   2m56s   v1.20.7
~ 
```

**Next steps**

This concludes the `DOKS` cluster setup. In the next section, you will learn how to set up a private `Docker` registry by using the `DigitalOcean Container Registry` (DOCR).

Go to [Section 2 - Setting up DOCR](../2-setup-DOCR)
