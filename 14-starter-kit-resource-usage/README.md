# Estimate Resource Usage for Startup Kit

In this part, you’ll focus on some introductory `CPU` monitoring by using `Grafana` which has some custom dashboards for this purposes. When you click `Manage`, you will see the `Kubernetes/Compute Resources/Cluster` section available with `kubernetes-mixin` tag.

The value for each metric, like: `CPU Utilisation`, `CPU Requests Commitment`, `CPU Limits Commitment`, `Memory Utilisation`, `Memory Requests Commitment` and `Memory Limits Commitment` is included in the header. Besides this, if you scroll down, you can see more tables, such as: `Cpu Usage`, `Memory Usage`,`Network Usage`, `Request by Namespace` and `Bandwidth`.

![Dashboard-Cost-CPU-Monitoring-Cluster](assets/images/monitoring_cpu_ram_cluster.png)

There are even more dashboards available to study, so please navigate to `Dashboards -> Manage` and pick `Kubernetes/Compute Resources/Namespace (Workloads)` for example. It shows `CPU/Memory` usage for each `namespace` (`velero`, `ambassador`, `prometheus/loki/grafana`).

Our observation on the resource utilization of the starter kit components are as follows. Note that this is the default state - meaning Ambassador is processing almost no traffic, there's no active backups going on, and there're only infrastructure logs and metrics to process:

- `CPU` usage across the components is `minimal`.
- `Ambassador` uses `300MB/replica`, total `~600MB`.
- `Velero` usage is minimal.
- Monitoring (`Prometheus`, `Alert Manager`, `Grafana`) uses up to `1GB`.

So the starting resource requirements for these components is `~1CPU` and `~2GB` of RAM.

To automate everything in the `Starter Kit`, please refer to [Section 15 - Continuous Delivery using GitOps](../15-continuous-delivery-using-gitops/README.md).
